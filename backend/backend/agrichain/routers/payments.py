"""
Payment router — PesaPal API v3 integration for AgriChain contracts.
Supports Mobile Money, Card, and Bank Transfer via PesaPal's hosted checkout.
"""
from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from agrichain.db.sqlite import connect, init_db, insert_ledger_event
from agrichain.services import pesapal_service as pesapal

router = APIRouter(prefix="/payments", tags=["payments"])

# ── Exchange rate (demo) ──────────────────────────────────────
UGX_PER_USD = 3750.0

# ── IPN ID cache (registered once at startup) ────────────────
_ipn_id: Optional[str] = None


class PaymentRequest(BaseModel):
    contract_id: str
    amount: float = Field(gt=0)
    currency: str = Field(default="UGX", pattern="^(UGX|USD)$")
    method: str = Field(description="momo_mtn | momo_airtel | card | bank")
    payer_name: str
    payer_phone: Optional[str] = None
    payer_email: Optional[str] = None
    card_last4: Optional[str] = None
    momo_number: Optional[str] = None


class PaymentResponse(BaseModel):
    payment_id: str
    contract_id: str
    amount: float
    currency: str
    amount_ugx: float
    amount_usd: float
    method: str
    method_label: str
    status: str
    payer_name: str
    reference: str
    message: str
    created_at: str
    redirect_url: Optional[str] = None
    pesapal_tracking_id: Optional[str] = None


def _method_label(method: str) -> str:
    return {
        "momo_mtn": "MTN Mobile Money",
        "momo_airtel": "Airtel Money",
        "card": "Visa/Mastercard",
        "bank": "Bank Transfer",
    }.get(method, method)


def _init_payments_table():
    with connect() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS payments (
                payment_id TEXT PRIMARY KEY,
                contract_id TEXT NOT NULL,
                amount REAL NOT NULL,
                currency TEXT NOT NULL,
                amount_ugx REAL NOT NULL,
                amount_usd REAL NOT NULL,
                method TEXT NOT NULL,
                method_label TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'PENDING',
                payer_name TEXT NOT NULL,
                payer_phone TEXT,
                payer_email TEXT,
                reference TEXT NOT NULL,
                gateway_ref TEXT,
                pesapal_tracking_id TEXT,
                created_at TEXT NOT NULL,
                completed_at TEXT
            )
        """)
        # Add pesapal_tracking_id column if it doesn't exist (migration)
        try:
            conn.execute("ALTER TABLE payments ADD COLUMN pesapal_tracking_id TEXT")
        except Exception:
            pass  # Column already exists


_init_payments_table()


async def _ensure_ipn() -> str:
    """Register IPN URL once, cache the ipn_id."""
    global _ipn_id
    if _ipn_id:
        return _ipn_id
    _ipn_id = await pesapal.register_ipn()
    return _ipn_id


@router.post("", response_model=PaymentResponse)
async def create_payment(req: PaymentRequest):
    """
    Initiate a payment via PesaPal.
    Returns a redirect_url — the client should open this URL for the user
    to complete payment on PesaPal's hosted checkout.
    """
    init_db()

    # Validate contract exists
    with connect() as conn:
        contract = conn.execute(
            "SELECT * FROM contracts WHERE id=?", (req.contract_id,)
        ).fetchone()

    if contract is None:
        raise HTTPException(status_code=404, detail="Contract not found")

    # Calculate amounts in both currencies
    if req.currency == "USD":
        amount_usd = req.amount
        amount_ugx = req.amount * UGX_PER_USD
    else:
        amount_ugx = req.amount
        amount_usd = req.amount / UGX_PER_USD

    payment_id = f"PAY-{uuid.uuid4().hex[:10].upper()}"
    reference = f"AGR-{uuid.uuid4().hex[:8].upper()}"
    now = datetime.now(timezone.utc).isoformat()
    method_lbl = _method_label(req.method)

    # ── PesaPal: Submit order ─────────────────────────────────
    redirect_url = None
    pesapal_tracking_id = None
    status = "PENDING"

    try:
        ipn_id = await _ensure_ipn()

        # Build billing address for PesaPal
        billing = {}
        if req.payer_email:
            billing["email_address"] = req.payer_email
        if req.payer_phone or req.momo_number:
            billing["phone_number"] = req.payer_phone or req.momo_number
        name_parts = req.payer_name.strip().split(" ", 1)
        billing["first_name"] = name_parts[0]
        if len(name_parts) > 1:
            billing["last_name"] = name_parts[1]

        pp_result = await pesapal.submit_order(
            merchant_reference=reference,
            amount=req.amount,
            currency=req.currency,
            description=f"AgriChain contract {req.contract_id} payment",
            ipn_id=ipn_id,
            billing=billing,
        )

        redirect_url = pp_result.get("redirect_url")
        pesapal_tracking_id = pp_result.get("order_tracking_id")

    except Exception as e:
        # If PesaPal fails, still create the payment record as FAILED
        status = "GATEWAY_ERROR"
        redirect_url = None
        import logging
        logging.getLogger("agrichain.payments").error(f"PesaPal error: {e}")

    # Save payment record
    with connect() as conn:
        conn.execute("""
            INSERT INTO payments (
                payment_id, contract_id, amount, currency,
                amount_ugx, amount_usd, method, method_label,
                status, payer_name, payer_phone, payer_email,
                reference, gateway_ref, pesapal_tracking_id,
                created_at, completed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            payment_id, req.contract_id, req.amount, req.currency,
            amount_ugx, amount_usd, req.method, method_lbl,
            status, req.payer_name, req.payer_phone, req.payer_email,
            reference, None, pesapal_tracking_id,
            now, None,
        ))

        # Record ledger event
        insert_ledger_event(
            conn,
            action="PAYMENT_INITIATED",
            actor=req.payer_name,
            contract_id=req.contract_id,
            meta={
                "payment_id": payment_id,
                "amount": f"{req.amount:.2f} {req.currency}",
                "method": method_lbl,
                "reference": reference,
                "status": status,
            },
        )

    msg = (
        f"Payment initiated. Complete payment at PesaPal checkout."
        if redirect_url
        else f"Payment gateway error. Please try again."
    )

    return PaymentResponse(
        payment_id=payment_id,
        contract_id=req.contract_id,
        amount=req.amount,
        currency=req.currency,
        amount_ugx=round(amount_ugx, 0),
        amount_usd=round(amount_usd, 2),
        method=req.method,
        method_label=method_lbl,
        status=status,
        payer_name=req.payer_name,
        reference=reference,
        message=msg,
        created_at=now,
        redirect_url=redirect_url,
        pesapal_tracking_id=pesapal_tracking_id,
    )


# ── PesaPal IPN callback ─────────────────────────────────────
@router.get("/ipn")
async def pesapal_ipn(
    OrderTrackingId: str = Query(...),
    OrderMerchantReference: str = Query(...),
    OrderNotificationType: str = Query(default=""),
):
    """
    PesaPal sends a GET to this endpoint when a payment status changes.
    We query PesaPal for the real status and update our DB.
    """
    try:
        status_data = await pesapal.get_transaction_status(OrderTrackingId)
    except Exception as e:
        return {"orderNotificationType": "CHANGE", "orderTrackingId": OrderTrackingId, "status": 500}

    pp_status = (status_data.get("payment_status_description") or "").upper()
    confirmation_code = status_data.get("confirmation_code", "")
    payment_method = status_data.get("payment_method", "")

    now = datetime.now(timezone.utc).isoformat()

    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM payments WHERE pesapal_tracking_id=? OR reference=?",
            (OrderTrackingId, OrderMerchantReference),
        ).fetchone()

        if row:
            new_status = "COMPLETED" if pp_status == "COMPLETED" else (
                "FAILED" if pp_status in ("FAILED", "INVALID") else pp_status
            )

            conn.execute(
                """UPDATE payments
                   SET status=?, gateway_ref=?, completed_at=?
                   WHERE payment_id=?""",
                (new_status, confirmation_code, now, row["payment_id"]),
            )

            # If payment completed, update contract status
            if new_status == "COMPLETED":
                conn.execute(
                    "UPDATE contracts SET status='PURCHASED', buyer_name=?, updated_at=? WHERE id=?",
                    (row["payer_name"], now, row["contract_id"]),
                )
                insert_ledger_event(
                    conn,
                    action="PAYMENT_COMPLETED",
                    actor=row["payer_name"],
                    contract_id=row["contract_id"],
                    meta={
                        "payment_id": row["payment_id"],
                        "gateway_ref": confirmation_code,
                        "payment_method": payment_method,
                        "pesapal_status": pp_status,
                    },
                )

                # ── SMS notification to farmer ─────────────────────
                try:
                    contract_row = conn.execute(
                        "SELECT farmer_phone, currency FROM contracts WHERE id=?",
                        (row["contract_id"],),
                    ).fetchone()
                    if contract_row and contract_row["farmer_phone"]:
                        from agrichain.services.sms_service import notify_payment_completed
                        import asyncio
                        amount_str = f"{row['amount']:.0f} {contract_row['currency']}"
                        asyncio.ensure_future(notify_payment_completed(
                            farmer_phone=contract_row["farmer_phone"],
                            contract_id=row["contract_id"],
                            amount=amount_str,
                            reference=confirmation_code or row["payment_id"],
                        ))
                except Exception as e:
                    import logging
                    logging.getLogger("agrichain.payments").warning(f"SMS notification failed: {e}")

    return {
        "orderNotificationType": "CHANGE",
        "orderTrackingId": OrderTrackingId,
        "orderMerchantReference": OrderMerchantReference,
        "status": 200,
    }


# ── PesaPal callback (user redirect after payment) ───────────
@router.get("/callback")
async def pesapal_callback(
    OrderTrackingId: str = Query(default=""),
    OrderMerchantReference: str = Query(default=""),
):
    """
    PesaPal redirects the user here after payment.
    We query the status and return it (Flutter app polls this).
    """
    if OrderTrackingId:
        try:
            status_data = await pesapal.get_transaction_status(OrderTrackingId)
            pp_status = (status_data.get("payment_status_description") or "").upper()

            return {
                "status": pp_status,
                "tracking_id": OrderTrackingId,
                "reference": OrderMerchantReference,
                "message": f"Payment {pp_status.lower()}.",
            }
        except Exception:
            pass

    return {
        "status": "UNKNOWN",
        "tracking_id": OrderTrackingId,
        "reference": OrderMerchantReference,
        "message": "Payment status could not be determined. Please check your app.",
    }


# ── Existing endpoints ────────────────────────────────────────
@router.get("/{payment_id}")
async def get_payment(payment_id: str):
    """Get payment details. Flutter polls this to check if payment completed."""
    _init_payments_table()

    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM payments WHERE payment_id=?", (payment_id,)
        ).fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="Payment not found")

    result = dict(row)

    # If still PENDING and we have a tracking ID, check PesaPal for latest status
    if result.get("status") == "PENDING" and result.get("pesapal_tracking_id"):
        try:
            status_data = await pesapal.get_transaction_status(
                result["pesapal_tracking_id"]
            )
            pp_status = (status_data.get("payment_status_description") or "").upper()

            if pp_status in ("COMPLETED", "FAILED", "INVALID", "REVERSED"):
                now = datetime.now(timezone.utc).isoformat()
                new_status = "COMPLETED" if pp_status == "COMPLETED" else "FAILED"

                with connect() as conn:
                    conn.execute(
                        "UPDATE payments SET status=?, completed_at=? WHERE payment_id=?",
                        (new_status, now, payment_id),
                    )
                    if new_status == "COMPLETED":
                        conn.execute(
                            "UPDATE contracts SET status='PURCHASED', buyer_name=?, updated_at=? WHERE id=?",
                            (result["payer_name"], now, result["contract_id"]),
                        )

                result["status"] = new_status
        except Exception:
            pass  # Can't reach PesaPal, return cached status

    return result


@router.get("")
async def list_payments(contract_id: Optional[str] = None):
    _init_payments_table()
    with connect() as conn:
        if contract_id:
            rows = conn.execute(
                "SELECT * FROM payments WHERE contract_id=? ORDER BY created_at DESC",
                (contract_id,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM payments ORDER BY created_at DESC"
            ).fetchall()
    return [dict(r) for r in rows]


# ── Payout Endpoints ─────────────────────────────────────────────────────────

@router.get("/payouts")
async def list_payouts(contract_id: Optional[str] = None):
    """
    List payouts. If contract_id is provided, filter by contract.
    Otherwise returns all pending payouts.
    """
    from agrichain.services.payout_service import (
        list_payouts_for_contract,
        list_pending_payouts,
    )

    if contract_id:
        return {"payouts": list_payouts_for_contract(contract_id)}
    return {"payouts": list_pending_payouts()}


@router.get("/payouts/{payout_id}")
async def get_payout_detail(payout_id: str):
    """Get details for a specific payout."""
    from agrichain.services.payout_service import get_payout
    payout = get_payout(payout_id)
    if not payout:
        raise HTTPException(status_code=404, detail="Payout not found")
    return payout


class ProcessPayoutRequest(BaseModel):
    disbursement_method: str = Field(default="MOBILE_MONEY", description="MOBILE_MONEY | BANK_TRANSFER | MANUAL")
    disbursement_ref: str = Field(default="", description="External reference (e.g. MoMo transaction ID)")


@router.post("/payouts/{payout_id}/process")
async def process_payout_endpoint(payout_id: str, req: ProcessPayoutRequest):
    """
    Mark a payout as disbursed. In production, this would trigger
    MTN MoMo API or PesaPal Openfloat. For now it records the
    disbursement method and reference.
    """
    from agrichain.services.payout_service import process_payout
    try:
        result = process_payout(
            payout_id=payout_id,
            disbursement_method=req.disbursement_method,
            disbursement_ref=req.disbursement_ref,
        )
        return {"status": "success", "payout": result}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

