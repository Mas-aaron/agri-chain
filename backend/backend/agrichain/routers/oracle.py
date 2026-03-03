"""
Oracle admin review router — Layer 1 endpoints.
"""
from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException, Query
from pydantic import BaseModel

from agrichain.db.risk_db import connect
from agrichain.services.oracle_service import OracleService
from agrichain.services.blockchain_store import STORE
from agrichain.services.adjustment_service import AdjustmentService

router = APIRouter(prefix="/oracle", tags=["oracle"])

_oracle = OracleService(blockchain_store=STORE)
_adjustment = AdjustmentService(blockchain_store=STORE)


# ── Models ────────────────────────────────────────────────────────────────────

class TriggerRequest(BaseModel):
    crop_type: Optional[str] = "Maize"
    geo_hash: Optional[str] = ""


class ApproveRequest(BaseModel):
    admin_notes: Optional[str] = None


class RejectRequest(BaseModel):
    admin_notes: str


class OracleSettleRequest(BaseModel):
    """Manual settlement after oracle report approval."""
    farmer_id: str
    crop_type: str
    predicted_yield: float
    token_amount: float


# ── Helpers ───────────────────────────────────────────────────────────────────

def _parse_sources(row: dict) -> dict:
    row["sources"] = json.loads(row.get("sources") or "[]")
    return row


def _fetch_reports(status: Optional[str] = None) -> List[Dict]:
    with connect() as conn:
        if status:
            rows = conn.execute(
                "SELECT * FROM oracle_reports WHERE status=? ORDER BY id DESC",
                (status,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM oracle_reports ORDER BY id DESC"
            ).fetchall()
    return [_parse_sources(dict(r)) for r in rows]


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/reports", response_model=List[Dict[str, Any]])
async def list_reports(status: Optional[str] = Query(default=None)):
    """List all oracle reports, optionally filtered by status (PENDING_REVIEW, APPROVED, REJECTED)."""
    return _fetch_reports(status)


@router.get("/reports/pending", response_model=List[Dict[str, Any]])
async def list_pending_reports():
    """List oracle reports requiring admin review (low confidence or pending status)."""
    return _fetch_reports("PENDING_REVIEW")


@router.get("/reports/{report_id}", response_model=Dict[str, Any])
async def get_report(report_id: int):
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM oracle_reports WHERE id=?", (report_id,)
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    return _parse_sources(dict(row))


@router.post("/trigger/{asset_id}", response_model=Dict[str, Any])
async def trigger_consensus(asset_id: str, body: TriggerRequest = None):
    """
    Manually trigger oracle consensus for an asset.
    In production this is called by a cron job when harvest date passes.
    """
    body = body or TriggerRequest()
    try:
        result = _oracle.run_consensus(
            asset_id=asset_id,
            crop_type=body.crop_type or "Maize",
            geo_hash=body.geo_hash or "",
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
    return result


@router.post("/reports/{report_id}/approve", response_model=Dict[str, Any])
async def approve_report(
    report_id: int, body: ApproveRequest, settle: OracleSettleRequest = None
):
    """
    Admin approves an oracle report.
    Triggers chaincode UpdateActualYield and optionally runs full adjustment pipeline.
    """
    result = _oracle.approve_report(report_id)
    if not result:
        raise HTTPException(status_code=404, detail="Report not found")

    # If settlement params provided, run full adjustment pipeline
    adj_result = None
    if settle:
        adj_result = _adjustment.execute(
            asset_id=result["asset_id"],
            farmer_id=settle.farmer_id,
            crop_type=settle.crop_type,
            actual_yield=result["consensus_yield"],
            predicted_yield=settle.predicted_yield,
            token_amount=settle.token_amount,
            oracle_confidence=result["confidence"],
            ipfs_hash=result["ipfs_hash"],
        )

    return {"report": result, "adjustment": adj_result}


@router.post("/reports/{report_id}/reject", response_model=Dict[str, Any])
async def reject_report(report_id: int, body: RejectRequest):
    """Admin rejects a report and provides notes."""
    ok = _oracle.reject_report(report_id, body.admin_notes)
    if not ok:
        raise HTTPException(status_code=404, detail="Report not found")
    return {"status": "rejected", "report_id": report_id, "admin_notes": body.admin_notes}


@router.get("/sources/health", response_model=Dict[str, Any])
async def source_health():
    """Return configured oracle sources and their weights."""
    return {
        "sources": [
            {"name": s.name, "weight": s.weight}
            for s in _oracle.SOURCES
        ],
        "min_sources_required": _oracle._engine.MIN_SOURCES,
        "confidence_threshold": _oracle._engine.CONFIDENCE_THRESHOLD,
    }
