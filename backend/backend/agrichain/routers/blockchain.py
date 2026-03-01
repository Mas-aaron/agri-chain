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
    return {
        "cropType": crop_type,
        "currency": "USD",
        "pricePerKg": 0.25,
        "lastUpdated": None,
        "source": "mock",
    }


# ── Blockchain Explorer (human-readable HTML pages) ───────────────────────

from fastapi.responses import HTMLResponse
from agrichain.db.sqlite import connect as _db_connect

_EXPLORER_CSS = """
  body{font-family:system-ui,sans-serif;background:#0d1117;color:#e6edf3;
       margin:0;padding:24px}
  .card{background:#161b22;border:1px solid #30363d;border-radius:12px;
        padding:24px;max-width:700px;margin:0 auto}
  h1{font-size:1.1rem;font-weight:700;color:#58a6ff;margin:0 0 4px}
  .sub{color:#8b949e;font-size:.85rem;margin-bottom:20px}
  table{width:100%;border-collapse:collapse}
  tr:not(:last-child) td{border-bottom:1px solid #21262d}
  td{padding:10px 4px;font-size:.9rem}
  td:first-child{color:#8b949e;width:40%}
  td:last-child{font-weight:600;word-break:break-all}
  .chip{display:inline-block;padding:2px 10px;border-radius:20px;
        font-size:.75rem;font-weight:700}
  .listed{background:#1f6feb22;color:#58a6ff}
  .purchased{background:#f0883e22;color:#f0883e}
  .delivered{background:#3fb95022;color:#3fb950}
  .token{background:#8b5cf622;color:#a78bfa}
  .logo{font-size:1.4rem;font-weight:900;color:#3fb950;margin-bottom:16px}
  .footer{text-align:center;color:#8b949e;font-size:.75rem;margin-top:16px}
"""


def _status_chip(status: str) -> str:
    cls = status.lower()
    return f'<span class="chip {cls}">{status}</span>'


@router.get("/explorer/assets/{asset_id}", response_class=HTMLResponse)
async def explorer_asset(asset_id: str):
    """Human-readable block explorer page for a yield token asset."""
    asset = STORE.get_asset(asset_id)
    if asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")

    rows = "".join(
        f"<tr><td>{k}</td><td>{v}</td></tr>"
        for k, v in {
            "Asset ID": asset.get("assetId", asset_id),
            "Token ID": asset.get("tokenId", "—"),
            "Farmer ID": asset.get("farmerId", "—"),
            "Crop Type": asset.get("cropType", "—"),
            "Season": asset.get("season", "—"),
            "Predicted Yield": f"{asset.get('predictedYield', 0):,.0f} kg",
            "Confidence": f"{float(asset.get('confidence', 0))*100:.1f}%",
            "Token Amount": f"{asset.get('tokenAmount', 0):,.2f}",
            "Current Value": f"${float(asset.get('currentValue', 0)):,.2f} USD",
            "Status": _status_chip(str(asset.get("status", "UNKNOWN"))),
            "Created At": asset.get("createdAt", "—"),
        }.items()
    )

    return HTMLResponse(f"""<!DOCTYPE html><html><head>
<title>AgriChain Explorer — {asset_id}</title>
<meta charset="UTF-8">
<style>{_EXPLORER_CSS}</style></head><body>
<div class="card">
  <div class="logo">⛓ AgriChain</div>
  <h1>Yield Token Asset</h1>
  <div class="sub">Hyperledger Fabric · yieldchannel · AgriToken chaincode</div>
  <table>{rows}</table>
  <div class="footer">AgriChain — Huawei Cloud BCS · ECS · SWR</div>
</div></body></html>""")


@router.get("/explorer/contracts/{contract_id}", response_class=HTMLResponse)
async def explorer_contract(contract_id: str):
    """Human-readable block explorer page for a harvest contract."""
    with _db_connect() as conn:
        row = conn.execute(
            "SELECT * FROM contracts WHERE id = ?", (contract_id,)
        ).fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="Contract not found")

    c = dict(row)
    total = float(c.get("quantity_kg", 0)) * float(c.get("unit_price", 0))
    rows = "".join(
        f"<tr><td>{k}</td><td>{v}</td></tr>"
        for k, v in {
            "Contract ID": c.get("id", contract_id),
            "Crop": c.get("crop", "—"),
            "Quantity": f"{float(c.get('quantity_kg', 0)):,.0f} kg",
            "Unit Price": f"{float(c.get('unit_price', 0)):,.2f} {c.get('currency', 'USD')}",
            "Total Value": f"{total:,.2f} {c.get('currency', 'USD')}",
            "Farmer": c.get("farmer_name", "—"),
            "Buyer": c.get("buyer_name") or "Not yet purchased",
            "Status": _status_chip(str(c.get("status", "UNKNOWN"))),
            "Created At": c.get("created_at", "—"),
            "Updated At": c.get("updated_at", "—"),
        }.items()
    )

    return HTMLResponse(f"""<!DOCTYPE html><html><head>
<title>AgriChain Explorer — {contract_id}</title>
<meta charset="UTF-8">
<style>{_EXPLORER_CSS}</style></head><body>
<div class="card">
  <div class="logo">⛓ AgriChain</div>
  <h1>Harvest Contract</h1>
  <div class="sub">Hyperledger Fabric · yieldchannel · FutureHarvest chaincode</div>
  <table>{rows}</table>
  <div class="footer">AgriChain — Huawei Cloud BCS · ECS · SWR</div>
</div></body></html>""")
