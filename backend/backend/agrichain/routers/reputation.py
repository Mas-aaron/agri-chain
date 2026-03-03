"""
Reputation router — Layer 5 endpoints.
"""
from __future__ import annotations

from typing import Any, Dict

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from agrichain.services.reputation_service import ReputationService
from agrichain.services.blockchain_store import STORE

router = APIRouter(prefix="/reputation", tags=["reputation"])
_rep = ReputationService(blockchain_store=STORE)


class HarvestUpdateRequest(BaseModel):
    actual_yield: float = Field(ge=0)
    predicted_yield: float = Field(gt=0)


@router.get("/{farmer_id}", response_model=Dict[str, Any])
async def get_reputation(farmer_id: str):
    """
    Returns farmer's current reputation score, tier, loan LTV,
    and insurance discount rate.
    """
    return _rep.get_reputation(farmer_id)


@router.get("/{farmer_id}/loan-terms", response_model=Dict[str, Any])
async def get_loan_terms(farmer_id: str):
    """
    Returns loan terms applicable to the farmer based on their tier.
    Consumed by the loan application UI to pre-fill LTV.
    """
    return _rep.get_loan_terms(farmer_id)


@router.post("/{farmer_id}/update", response_model=Dict[str, Any])
async def update_reputation(farmer_id: str, body: HarvestUpdateRequest):
    """
    Manually trigger a reputation update for a farmer.
    Typically called internally after oracle settlement (Layer 1→3→5 pipeline).
    """
    return _rep.update_after_harvest(
        farmer_id=farmer_id,
        actual_yield=body.actual_yield,
        predicted_yield=body.predicted_yield,
    )
