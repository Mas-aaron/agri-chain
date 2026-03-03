"""
ML Staking router — Layer 4 endpoints.
"""
from __future__ import annotations

from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from agrichain.services.ml_staking_service import MLStakingService
from agrichain.services.blockchain_store import STORE

router = APIRouter(prefix="/ml-staking", tags=["ml-staking"])
_svc = MLStakingService(blockchain_store=STORE)


# ── Models ─────────────────────────────────────────────────────────────────

class StakeRequest(BaseModel):
    provider_id: str
    model_id: str
    amount: float = Field(gt=0)


class UnstakeRequest(BaseModel):
    provider_id: str
    model_id: str
    amount: float = Field(gt=0)


class AccuracyRequest(BaseModel):
    model_id: str
    asset_id: str
    season: int = Field(gt=2000)
    actual_yield: float = Field(ge=0)
    predicted_yield: float = Field(gt=0)


class EvaluateRequest(BaseModel):
    provider_id: str
    model_id: str
    season: int


# ── Endpoints ───────────────────────────────────────────────────────────────

@router.post("/stake", response_model=Dict[str, Any])
async def stake_model(body: StakeRequest):
    """Stake tokens as collateral for an ML model's predictions."""
    return _svc.stake(body.provider_id, body.model_id, body.amount)


@router.post("/unstake", response_model=Dict[str, Any])
async def unstake_model(body: UnstakeRequest):
    """Withdraw from a model stake (subject to 30-day lock period)."""
    try:
        return _svc.unstake(body.provider_id, body.model_id, body.amount)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/models/{provider_id}/{model_id}", response_model=Dict[str, Any])
async def get_model_stake(provider_id: str, model_id: str):
    """Return stake details and lock status for a model provider."""
    info = _svc.get_stake_info(provider_id, model_id)
    if not info:
        raise HTTPException(status_code=404, detail="Stake not found")
    return info


@router.post("/record-accuracy", response_model=Dict[str, Any])
async def record_model_accuracy(body: AccuracyRequest):
    """Record prediction accuracy for a single asset harvest."""
    return _svc.record_accuracy(
        model_id=body.model_id,
        asset_id=body.asset_id,
        season=body.season,
        actual_yield=body.actual_yield,
        predicted_yield=body.predicted_yield,
    )


@router.post("/evaluate-season", response_model=Dict[str, Any])
async def evaluate_season(body: EvaluateRequest):
    """
    Admin-triggered end-of-season evaluation.
    Calculates average discrepancy and applies slash or reward to provider's stake.
    """
    return _svc.evaluate_season(body.provider_id, body.model_id, body.season)
