from __future__ import annotations

import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from agrichain.services.blockchain_store import STORE
# from agrichain.services.fabric_gateway import get_fabric_client

router = APIRouter(prefix="/blockchain", tags=["blockchain"])


class YieldAssetIn(BaseModel):
    assetId: Optional[str] = None
    tokenId: Optional[str] = None
    farmerId: str
    farmerDid: Optional[str] = None
    farmId: Optional[str] = None
    geoHash: Optional[str] = None
    cropType: str = "Maize"
    season: int = Field(default=2026, ge=2000)
    predictedYield: float = Field(default=0, ge=0)
    confidence: float = Field(default=0)
    mlModelVersion: Optional[str] = None
    mlModelHash: Optional[str] = None
    roverDataHash: Optional[str] = None
    metadataUri: Optional[str] = None
    tokenAmount: Optional[float] = None
    currentValue: Optional[float] = None
    status: str = "PREDICTED"


class TradeRequest(BaseModel):
    assetId: str
    amount: float
    tradeType: str


def _new_asset_id() -> str:
    return f"ASSET_{uuid.uuid4().hex[:12].upper()}"


def _new_token_id(*, season: int, crop_type: str, asset_id: str) -> str:
    crop = (crop_type or "CROP").upper()
    crop3 = crop[:3] if len(crop) >= 3 else crop
    tail = asset_id[-3:]
    return f"AYW-{int(season)}-{crop3}-{tail}"


def _fabric_enabled() -> bool:
    return False


@router.get("/assets", response_model=List[Dict[str, Any]])
async def list_assets(farmerId: Optional[str] = Query(default=None)):
    return STORE.list_assets(farmer_id=farmerId)


@router.get("/assets/{asset_id}", response_model=Dict[str, Any])
async def get_asset(asset_id: str):
    asset = STORE.get_asset(asset_id)
    if asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return asset


@router.post("/assets", response_model=Dict[str, Any])
async def create_asset(payload: YieldAssetIn):
    asset_id = payload.assetId or _new_asset_id()
    token_id = payload.tokenId or _new_token_id(season=payload.season, crop_type=payload.cropType, asset_id=asset_id)

    token_amount = float(payload.tokenAmount) if payload.tokenAmount is not None else float(payload.predictedYield)
    current_value = float(payload.currentValue) if payload.currentValue is not None else float(payload.predictedYield) * 5.0

    try:
        return STORE.create_asset(
            asset_id=asset_id,
            token_id=token_id,
            farmer_id=payload.farmerId,
            crop_type=payload.cropType,
            season=payload.season,
            predicted_yield=payload.predictedYield,
            confidence=payload.confidence,
            token_amount=token_amount,
            current_value=current_value,
            status=payload.status,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put("/assets/{asset_id}", response_model=Dict[str, Any])
async def update_asset(asset_id: str, payload: YieldAssetIn):
    updates = payload.model_dump(exclude_unset=True)
    updated = STORE.update_asset(asset_id, updates)
    if updated is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    return updated


@router.delete("/assets/{asset_id}")
async def delete_asset(asset_id: str):
    deleted = STORE.delete_asset(asset_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Asset not found")
    return {"status": "deleted"}


@router.get("/portfolio/{farmer_id}/summary", response_model=Dict[str, Any])
async def portfolio_summary(farmer_id: str):
    assets = STORE.list_assets(farmer_id=farmer_id)
    total_value = sum(float(a.get("currentValue") or 0) for a in assets)
    total_tokens = sum(float(a.get("tokenAmount") or 0) for a in assets)
    return {
        "farmerId": farmer_id,
        "assetCount": len(assets),
        "totalValue": total_value,
        "totalTokens": total_tokens,
        "statusBreakdown": {},
    }


@router.post("/trades", response_model=Dict[str, Any])
async def execute_trade(payload: TradeRequest):
    trade_type = (payload.tradeType or "").upper()
    if trade_type not in {"BUY", "SELL"}:
        raise HTTPException(status_code=400, detail="tradeType must be BUY or SELL")

    asset = STORE.get_asset(payload.assetId)
    if asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")

    return {
        "tradeId": f"TR-{uuid.uuid4().hex[:10].upper()}",
        "assetId": payload.assetId,
        "amount": payload.amount,
        "tradeType": trade_type,
        "status": "ACCEPTED",
    }


@router.get("/market/crop/{crop_type}", response_model=Dict[str, Any])
async def market_data(crop_type: str):
    # Placeholder market response so the app UI can render.
    return {
        "cropType": crop_type,
        "currency": "USD",
        "pricePerKg": 0.25,
        "lastUpdated": None,
        "source": "mock",
    }
