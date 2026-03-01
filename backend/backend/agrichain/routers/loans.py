"""
Loans router — Credit/Loan Collateral flow for AgriChain.
Farmers can pledge a yield token as collateral and apply for a loan.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from agrichain.db.sqlite import connect, insert_ledger_event

router = APIRouter(prefix="/loans", tags=["loans"])


# ── DB Init ───────────────────────────────────────────────────

def _init_loans_table():
    with connect() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS loans (
                loan_id        TEXT PRIMARY KEY,
                token_id       TEXT NOT NULL,
                asset_id       TEXT NOT NULL,
                farmer_id      TEXT NOT NULL,
                loan_amount    REAL NOT NULL,
                currency       TEXT NOT NULL DEFAULT 'USD',
                collateral_value REAL NOT NULL,
                ltv_percent    REAL NOT NULL,
                repayment_months INTEGER NOT NULL,
                interest_rate  REAL NOT NULL,
                monthly_payment REAL NOT NULL,
                lender         TEXT NOT NULL,
                status         TEXT NOT NULL DEFAULT 'PENDING',
                crop_type      TEXT,
                quality_grade  TEXT,
                created_at     TEXT NOT NULL,
                approved_at    TEXT
            )
        """)


_init_loans_table()


# ── Models ────────────────────────────────────────────────────

class LoanApplicationRequest(BaseModel):
    token_id: str
    asset_id: str
    farmer_id: str
    loan_amount: float = Field(gt=0)
    currency: str = Field(default="USD", pattern="^(USD|UGX)$")
    collateral_value: float = Field(gt=0)
    ltv_percent: float = Field(ge=10, le=90, description="Loan-to-value ratio as percentage")
    repayment_months: int = Field(ge=1, le=60)
    interest_rate: float = Field(ge=0)
    monthly_payment: float = Field(ge=0)
    lender: str
    crop_type: Optional[str] = None
    quality_grade: Optional[str] = None


class LoanResponse(BaseModel):
    loan_id: str
    token_id: str
    asset_id: str
    farmer_id: str
    loan_amount: float
    currency: str
    collateral_value: float
    ltv_percent: float
    repayment_months: int
    interest_rate: float
    monthly_payment: float
    lender: str
    status: str
    crop_type: Optional[str]
    quality_grade: Optional[str]
    created_at: str
    message: str


# ── Endpoints ─────────────────────────────────────────────────

@router.post("", response_model=LoanResponse)
async def apply_for_loan(req: LoanApplicationRequest):
    """
    Submit a loan application backed by a yield token as collateral.
    Records a LOAN_APPLIED ledger event on success.
    """
    loan_id = f"LOAN-{uuid.uuid4().hex[:10].upper()}"
    now = datetime.now(timezone.utc).isoformat()

    with connect() as conn:
        conn.execute("""
            INSERT INTO loans (
                loan_id, token_id, asset_id, farmer_id,
                loan_amount, currency, collateral_value, ltv_percent,
                repayment_months, interest_rate, monthly_payment, lender,
                status, crop_type, quality_grade, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            loan_id, req.token_id, req.asset_id, req.farmer_id,
            req.loan_amount, req.currency, req.collateral_value, req.ltv_percent,
            req.repayment_months, req.interest_rate, req.monthly_payment, req.lender,
            "PENDING", req.crop_type, req.quality_grade, now,
        ))

        insert_ledger_event(
            conn,
            action="LOAN_APPLIED",
            actor=req.farmer_id,
            contract_id=req.token_id,
            meta={
                "loan_id": loan_id,
                "lender": req.lender,
                "amount": f"{req.loan_amount:.2f} {req.currency}",
                "ltv": f"{req.ltv_percent:.0f}%",
                "collateral_token": req.token_id,
                "repayment": f"{req.repayment_months} months @ {req.interest_rate:.1f}%",
            },
        )

    return LoanResponse(
        loan_id=loan_id,
        token_id=req.token_id,
        asset_id=req.asset_id,
        farmer_id=req.farmer_id,
        loan_amount=req.loan_amount,
        currency=req.currency,
        collateral_value=req.collateral_value,
        ltv_percent=req.ltv_percent,
        repayment_months=req.repayment_months,
        interest_rate=req.interest_rate,
        monthly_payment=req.monthly_payment,
        lender=req.lender,
        status="PENDING",
        crop_type=req.crop_type,
        quality_grade=req.quality_grade,
        created_at=now,
        message=(
            f"Loan application {loan_id} submitted successfully. "
            f"{req.lender} will review your application within 24–48 hours."
        ),
    )


@router.get("")
async def list_loans(farmer_id: Optional[str] = None, token_id: Optional[str] = None):
    """List loan applications, optionally filtered by farmer or token."""
    with connect() as conn:
        if farmer_id:
            rows = conn.execute(
                "SELECT * FROM loans WHERE farmer_id=? ORDER BY created_at DESC",
                (farmer_id,),
            ).fetchall()
        elif token_id:
            rows = conn.execute(
                "SELECT * FROM loans WHERE token_id=? ORDER BY created_at DESC",
                (token_id,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM loans ORDER BY created_at DESC"
            ).fetchall()
    return [dict(r) for r in rows]


@router.get("/{loan_id}")
async def get_loan(loan_id: str):
    """Get a single loan application by ID."""
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM loans WHERE loan_id=?", (loan_id,)
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Loan not found")
    return dict(row)
