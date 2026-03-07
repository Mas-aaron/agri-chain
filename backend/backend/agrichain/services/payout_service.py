"""
Payout Service — manages farmer payouts after verification consensus.

When independent verifiers reach consensus on a yield asset, a payout record
is created for the farmer. Payouts can be processed via:
  - PesaPal Openfloat dashboard (manual)
  - MTN MoMo API (future automation)
  - Bank transfer (manual)

The service records payout requests and tracks their status.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from agrichain.db.sqlite import connect, init_db, insert_ledger_event

logger = logging.getLogger("agrichain.payout")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _init_payouts_table():
    """Create the payouts table if it doesn't exist."""
    with connect() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS payouts (
                id TEXT PRIMARY KEY,
                contract_id TEXT NOT NULL,
                asset_id TEXT,
                farmer_name TEXT NOT NULL,
                farmer_phone TEXT,
                amount REAL NOT NULL,
                currency TEXT NOT NULL DEFAULT 'UGX',
                status TEXT NOT NULL DEFAULT 'PENDING_DISBURSEMENT',
                disbursement_method TEXT,
                disbursement_ref TEXT,
                created_at TEXT NOT NULL,
                processed_at TEXT,
                notes TEXT
            )
        """)


# Initialize on module load
_init_payouts_table()


# ── Create payout ────────────────────────────────────────────────────────────

def create_payout(
    contract_id: str,
    farmer_name: str,
    farmer_phone: Optional[str],
    amount: float,
    currency: str = "UGX",
    asset_id: Optional[str] = None,
    notes: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Create a payout record for a farmer after verification consensus.
    Returns the created payout record.
    """
    payout_id = f"PAY-{uuid.uuid4().hex[:12].upper()}"
    now = _utc_now()

    with connect() as conn:
        conn.execute(
            """
            INSERT INTO payouts (
                id, contract_id, asset_id, farmer_name, farmer_phone,
                amount, currency, status, created_at, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                payout_id,
                contract_id,
                asset_id,
                farmer_name,
                farmer_phone,
                amount,
                currency,
                "PENDING_DISBURSEMENT",
                now,
                notes,
            ),
        )

        # Record ledger event
        insert_ledger_event(
            conn,
            action="PAYOUT_INITIATED",
            actor="system",
            contract_id=contract_id,
            meta={
                "payout_id": payout_id,
                "amount": amount,
                "currency": currency,
                "farmer_phone": farmer_phone or "",
                "farmer_name": farmer_name,
            },
        )

    logger.info(
        f"Payout {payout_id} created: {amount} {currency} → "
        f"{farmer_name} ({farmer_phone or 'no phone'}) for contract {contract_id}"
    )

    return get_payout(payout_id)  # type: ignore


# ── Process payout (mark as disbursed) ───────────────────────────────────────

def process_payout(
    payout_id: str,
    disbursement_method: str = "MOBILE_MONEY",
    disbursement_ref: str = "",
) -> Dict[str, Any]:
    """
    Mark a payout as processed/disbursed.
    In a production system, this would call MTN MoMo API or PesaPal Openfloat.
    """
    now = _utc_now()

    with connect() as conn:
        row = conn.execute("SELECT * FROM payouts WHERE id=?", (payout_id,)).fetchone()
        if not row:
            raise ValueError(f"Payout {payout_id} not found")

        if row["status"] == "DISBURSED":
            raise ValueError(f"Payout {payout_id} already disbursed")

        conn.execute(
            """
            UPDATE payouts
            SET status=?, disbursement_method=?, disbursement_ref=?, processed_at=?
            WHERE id=?
            """,
            ("DISBURSED", disbursement_method, disbursement_ref, now, payout_id),
        )

        insert_ledger_event(
            conn,
            action="PAYOUT_DISBURSED",
            actor="admin",
            contract_id=row["contract_id"],
            meta={
                "payout_id": payout_id,
                "method": disbursement_method,
                "ref": disbursement_ref,
            },
        )

    logger.info(f"Payout {payout_id} disbursed via {disbursement_method} ref={disbursement_ref}")
    return get_payout(payout_id)  # type: ignore


# ── Query payouts ────────────────────────────────────────────────────────────

def get_payout(payout_id: str) -> Optional[Dict[str, Any]]:
    """Get a single payout by ID."""
    with connect() as conn:
        row = conn.execute("SELECT * FROM payouts WHERE id=?", (payout_id,)).fetchone()
    if not row:
        return None
    return dict(row)


def list_payouts_for_contract(contract_id: str) -> List[Dict[str, Any]]:
    """Get all payouts for a given contract."""
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM payouts WHERE contract_id=? ORDER BY created_at DESC",
            (contract_id,),
        ).fetchall()
    return [dict(r) for r in rows]


def list_pending_payouts() -> List[Dict[str, Any]]:
    """Get all payouts awaiting disbursement."""
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM payouts WHERE status='PENDING_DISBURSEMENT' ORDER BY created_at",
        ).fetchall()
    return [dict(r) for r in rows]
