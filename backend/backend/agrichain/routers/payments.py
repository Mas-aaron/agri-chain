"""
Payment router — simulated payment gateway for AgriChain contracts.
Supports Mobile Money (MTN/Airtel), Card, and Bank Transfer.
Ready to swap in Flutterwave/Stripe with just API keys.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from agrichain.db.sqlite import connect, init_db, insert_ledger_event

router = APIRouter(prefix="/payments", tags=["payments"])

# ── Exchange rate (demo) ──────────────────────────────────────
UGX_PER_USD = 3750.0


class PaymentRequest(BaseModel):
    contract_id: str
    amount: float = Field(gt=0)
    currency: str = Field(default="UGX", pattern="^(UGX|USD)$")
    method: str = Field(description="momo_mtn | momo_airtel | card | bank")
    payer_name: str
    payer_phone: Optional[str] = None
    payer_email: Optional[str] = None
    # Card fields (optional, for card method)
    card_last4: Optional[str] = None
    # MoMo fields
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
                created_at TEXT NOT NULL,
                completed_at TEXT
            )
        """)


_init_payments_table()


@router.post("", response_model=PaymentResponse)
async def create_payment(req: PaymentRequest):
    """
    Process a payment for a contract.
    In production, this would call Flutterwave/Stripe API.
    For now, simulates a successful payment.
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

    # ── In production, call Flutterwave/Stripe here ──
    # flutterwave_response = await flutterwave.charge(...)
    # For demo, we simulate instant success:
    status = "COMPLETED"
    gateway_ref = f"FLW-{uuid.uuid4().hex[:12].upper()}"

    # Save payment
    with connect() as conn:
        conn.execute("""
            INSERT INTO payments (
                payment_id, contract_id, amount, currency,
                amount_ugx, amount_usd, method, method_label,
                status, payer_name, payer_phone, payer_email,
                reference, gateway_ref, created_at, completed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            payment_id, req.contract_id, req.amount, req.currency,
            amount_ugx, amount_usd, req.method, method_lbl,
            status, req.payer_name, req.payer_phone, req.payer_email,
            reference, gateway_ref, now, now,
        ))

        # Update contract status to PURCHASED
        conn.execute(
            "UPDATE contracts SET status='PURCHASED', buyer_name=?, updated_at=? WHERE id=?",
            (req.payer_name, now, req.contract_id),
        )

        # Record ledger event
        insert_ledger_event(
            conn,
            action="PAYMENT_COMPLETED",
            actor=req.payer_name,
            contract_id=req.contract_id,
            meta={
                "payment_id": payment_id,
                "amount": f"{req.amount:.2f} {req.currency}",
                "method": method_lbl,
                "reference": reference,
                "gateway_ref": gateway_ref,
            },
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
        message=f"Payment of {req.amount:,.0f} {req.currency} via {method_lbl} completed successfully.",
        created_at=now,
    )


@router.get("/{payment_id}")
async def get_payment(payment_id: str):
    _init_payments_table()
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM payments WHERE payment_id=?", (payment_id,)
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Payment not found")
    return dict(row)


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
