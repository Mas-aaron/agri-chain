"""
Independent Verifier router — endpoints for verifier registration,
yield-report submission, consensus viewing, staking, rewards, and profiles.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from agrichain.services.verifier_service import VerifierService

router = APIRouter(prefix="/verifier", tags=["verifier"])

_svc = VerifierService()


# ── Request/Response Models ───────────────────────────────────────────────────


class RegisterRequest(BaseModel):
    user_id: str
    organization_name: str
    organization_type: str = "INSPECTOR"
    api_endpoint: str = ""
    public_key: str = ""


class SubmitReportRequest(BaseModel):
    verifier_id: int
    asset_id: str
    submitted_yield: float
    confidence: float = 0.8
    data_source: str = "INSPECTOR"
    measurement_method: str = ""
    notes: str = ""


class StakeRequest(BaseModel):
    verifier_id: int
    amount: float
    lock_days: int = 30


class UpdateProfileRequest(BaseModel):
    organization_name: Optional[str] = None
    organization_type: Optional[str] = None
    api_endpoint: Optional[str] = None
    public_key: Optional[str] = None


# ── Endpoints ─────────────────────────────────────────────────────────────────


@router.get("/health", response_model=Dict[str, Any])
async def verifier_health():
    """Health check for the verifier subsystem."""
    verifiers = _svc.list_all_verifiers()
    return {
        "status": "ok",
        "subsystem": "independent_verifier",
        "active_verifiers": len(verifiers),
        "min_submissions_for_consensus": _svc.MIN_SUBMISSIONS_FOR_CONSENSUS,
    }


@router.get("/lookup", response_model=Dict[str, Any])
async def lookup_verifier_by_user(user_id: str = Query(...)):
    """Lookup a verifier by their Firebase user_id. Returns the profile or 404."""
    from agrichain.db.risk_db import get_verifier_by_user_id

    verifier = get_verifier_by_user_id(user_id)
    if not verifier:
        raise HTTPException(status_code=404, detail="Not a verifier")
    return {"verifier": verifier}


@router.post("/register", response_model=Dict[str, Any])
async def register_verifier(body: RegisterRequest):
    """Register a new independent verifier."""
    try:
        verifier = _svc.register(
            user_id=body.user_id,
            organization_name=body.organization_name,
            organization_type=body.organization_type,
            api_endpoint=body.api_endpoint,
            public_key=body.public_key,
        )
        return {"verifier": verifier}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/dashboard", response_model=Dict[str, Any])
async def get_dashboard(verifier_id: int = Query(...)):
    """Return dashboard statistics for a verifier."""
    stats = _svc.dashboard_stats(verifier_id)
    if not stats:
        raise HTTPException(status_code=404, detail="Verifier not found")
    return {"dashboard": stats}


@router.get("/pending-assets", response_model=Dict[str, Any])
async def get_pending_assets():
    """Return assets that need verifier yield reports."""
    assets = _svc.get_pending_assets()
    return {"assets": assets, "count": len(assets)}


@router.post("/submit-report", response_model=Dict[str, Any])
async def submit_report(body: SubmitReportRequest):
    """Submit a yield report for an asset."""
    try:
        result = _svc.submit_report(
            verifier_id=body.verifier_id,
            asset_id=body.asset_id,
            submitted_yield=body.submitted_yield,
            confidence=body.confidence,
            data_source=body.data_source,
            measurement_method=body.measurement_method,
            notes=body.notes,
        )
        return result
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/my-submissions", response_model=Dict[str, Any])
async def get_my_submissions(
    verifier_id: int = Query(...),
    limit: int = Query(default=50, le=200),
):
    """Return submission history for a verifier."""
    subs = _svc.get_my_submissions(verifier_id, limit)
    return {"submissions": subs, "count": len(subs)}


@router.get("/submission/{submission_id}", response_model=Dict[str, Any])
async def get_submission_detail(submission_id: int):
    """Return details for a single submission."""
    sub = _svc.get_submission_detail(submission_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Submission not found")
    return {"submission": sub}


@router.get("/consensus-reports", response_model=Dict[str, Any])
async def get_consensus_reports(limit: int = Query(default=50, le=200)):
    """Return recent consensus reports formed by verifiers."""
    reports = _svc.get_consensus_reports(limit)
    return {"reports": reports, "count": len(reports)}


@router.post("/stake", response_model=Dict[str, Any])
async def stake_tokens(body: StakeRequest):
    """Stake tokens to increase verifier weight."""
    try:
        result = _svc.stake_tokens(
            verifier_id=body.verifier_id,
            amount=body.amount,
            lock_days=body.lock_days,
        )
        return result
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/rewards", response_model=Dict[str, Any])
async def get_rewards(
    verifier_id: int = Query(...),
    limit: int = Query(default=50, le=200),
):
    """Return reward history for a verifier."""
    rewards = _svc.get_rewards(verifier_id, limit)
    total = _svc.get_total_rewards(verifier_id)
    return {"rewards": rewards, "total": total}


@router.get("/profile", response_model=Dict[str, Any])
async def get_profile(verifier_id: int = Query(...)):
    """Return verifier profile."""
    profile = _svc.get_profile(verifier_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Verifier not found")
    return {"profile": profile}


@router.put("/profile", response_model=Dict[str, Any])
async def update_profile(verifier_id: int = Query(...), body: UpdateProfileRequest = None):
    """Update verifier profile fields."""
    body = body or UpdateProfileRequest()
    kwargs = {k: v for k, v in body.dict().items() if v is not None}
    updated = _svc.update_profile(verifier_id, **kwargs)
    if not updated:
        raise HTTPException(status_code=404, detail="Verifier not found")
    return {"profile": updated}


# ── Admin endpoints (for completeness) ────────────────────────────────────────


@router.get("/admin/list", response_model=Dict[str, Any])
async def admin_list_verifiers(active_only: bool = Query(default=True)):
    """Admin: list all registered verifiers."""
    verifiers = _svc.list_all_verifiers(active_only)
    return {"verifiers": verifiers, "count": len(verifiers)}
