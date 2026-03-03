"""
Insurance router — Layer 2 endpoints.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from agrichain.services.insurance_service import InsuranceService
from agrichain.services.blockchain_store import STORE

router = APIRouter(prefix="/insurance", tags=["insurance"])
_ins = InsuranceService(blockchain_store=STORE)


class PremiumRequest(BaseModel):
    asset_id: str
    farmer_id: str
    crop_type: str = "Maize"
    predicted_yield: float = Field(gt=0)
    record: bool = True  # whether to persist the premium


class ClaimRequest(BaseModel):
    asset_id: str
    actual_yield: float = Field(ge=0)
    predicted_yield: float = Field(gt=0)
    token_amount: float = Field(gt=0)


@router.post("/premium", response_model=Dict[str, Any])
async def calculate_or_record_premium(body: PremiumRequest):
    """
    Calculate insurance premium for a yield asset.
    If record=True (default), persists to DB and calls chaincode InitInsurancePool.
    """
    if body.record:
        return _ins.record_premium(
            asset_id=body.asset_id,
            farmer_id=body.farmer_id,
            crop_type=body.crop_type,
            predicted_yield=body.predicted_yield,
        )
    return _ins.calculate_premium(
        asset_id=body.asset_id,
        farmer_id=body.farmer_id,
        crop_type=body.crop_type,
        predicted_yield=body.predicted_yield,
    )


@router.get("/pool/{asset_id}", response_model=Dict[str, Any])
async def get_pool_balance(asset_id: str):
    """Return the current insurance pool balance for an asset."""
    return _ins.pool_balance(asset_id)


@router.post("/claim", response_model=Dict[str, Any])
async def process_claim(body: ClaimRequest):
    """
    Manually trigger an insurance claim for an asset.
    No claim is created if shortfall ≤ 5% (within deductible).
    """
    result = _ins.process_claim(
        asset_id=body.asset_id,
        actual_yield=body.actual_yield,
        predicted_yield=body.predicted_yield,
        token_amount=body.token_amount,
    )
    if result is None:
        return {
            "message": "No claim created — shortfall within deductible threshold (5%).",
            "asset_id": body.asset_id,
        }
    return result


@router.get("/claims", response_model=List[Dict[str, Any]])
async def list_claims(asset_id: Optional[str] = None):
    """List all insurance claims, optionally filtered by asset."""
    return _ins.list_claims(asset_id)


@router.get("/premiums/{asset_id}", response_model=List[Dict[str, Any]])
async def list_premiums(asset_id: str):
    """List all premium records for an asset."""
    from agrichain.db.risk_db import connect
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM insurance_premiums WHERE asset_id=? ORDER BY id DESC",
            (asset_id,),
        ).fetchall()
    return [dict(r) for r in rows]
