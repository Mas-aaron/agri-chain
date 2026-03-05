"""
Independent Verifier Service — manages verifier registration, yield report
submissions, weighted-median consensus, staking, and rewards.

Reuses the existing ConsensusEngine from oracle_service.py for median calculation.
"""
from __future__ import annotations

import json
from typing import Any, Dict, List, Optional

from agrichain.db.risk_db import (
    connect,
    insert_verifier,
    get_verifier,
    get_verifier_by_user_id,
    list_verifiers as db_list_verifiers,
    update_verifier,
    insert_verifier_submission,
    get_submissions_for_asset,
    get_verifier_submissions,
    get_submission,
    update_submission_status,
    insert_verifier_consensus,
    get_verifier_consensus,
    list_verifier_consensus,
    upsert_verifier_stake,
    get_verifier_stakes,
    insert_verifier_reward,
    get_verifier_rewards,
    get_verifier_total_rewards,
)
from agrichain.services.oracle_service import ConsensusEngine, mock_ipfs_store


# ─────────────────────────────────────────────────────────────────────────────
# SERVICE
# ─────────────────────────────────────────────────────────────────────────────


class VerifierService:
    """Business logic for the Independent Verifier subsystem."""

    MIN_SUBMISSIONS_FOR_CONSENSUS = 3
    REWARD_PER_SUBMISSION = 5.0  # AYT tokens

    def __init__(self) -> None:
        self._engine = ConsensusEngine()

    # ── Registration ──────────────────────────────────────────────

    def register(
        self,
        user_id: str,
        organization_name: str,
        organization_type: str = "INSPECTOR",
        api_endpoint: str = "",
        public_key: str = "",
    ) -> dict:
        """Register a new verifier and return their profile."""
        existing = get_verifier_by_user_id(user_id)
        if existing:
            return existing
        vid = insert_verifier(
            user_id=user_id,
            organization_name=organization_name,
            organization_type=organization_type,
            api_endpoint=api_endpoint,
            public_key=public_key,
        )
        return get_verifier(vid)

    # ── Dashboard ─────────────────────────────────────────────────

    def dashboard_stats(self, verifier_id: int) -> Dict[str, Any]:
        """Return aggregate stats for a verifier's dashboard."""
        verifier = get_verifier(verifier_id)
        if not verifier:
            return {}

        total_rewards = get_verifier_total_rewards(verifier_id)
        pending_assets = self.get_pending_assets()

        return {
            "totalSubmissions": verifier["total_submissions"],
            "accuracyRate": verifier["accuracy_rate"],
            "stakeAmount": verifier["stake_amount"],
            "reputationScore": verifier["reputation_score"],
            "rewardsEarned": total_rewards,
            "pendingAssetsCount": len(pending_assets),
            "isActive": bool(verifier["is_active"]),
        }

    # ── Pending assets ────────────────────────────────────────────

    def get_pending_assets(self) -> List[Dict[str, Any]]:
        """
        Return assets that need oracle yield reports.

        In a real system this would query a yield_assets table for assets
        past harvest date. Here we return any assets that already have ≥1
        oracle report (from the automated system) but no verifier consensus
        yet, plus a set of demo mock assets.
        """
        with connect() as conn:
            # Assets with oracle reports but no verifier consensus
            rows = conn.execute("""
                SELECT DISTINCT r.asset_id,
                       r.consensus_yield AS predicted_yield,
                       'Maize' AS crop_type,
                       '2025-B' AS season
                FROM oracle_reports r
                LEFT JOIN verifier_consensus_reports vc ON r.asset_id = vc.asset_id
                WHERE vc.id IS NULL
                ORDER BY r.created_at DESC
                LIMIT 100
            """).fetchall()

        assets = [dict(r) for r in rows]

        # If no real assets, provide demo data so the UI is functional
        if not assets:
            assets = [
                {"asset_id": "ASSET_DEMO_001", "predicted_yield": 4500.0, "crop_type": "Maize", "season": "2025-B"},
                {"asset_id": "ASSET_DEMO_002", "predicted_yield": 3800.0, "crop_type": "Wheat", "season": "2025-A"},
                {"asset_id": "ASSET_DEMO_003", "predicted_yield": 5200.0, "crop_type": "Rice", "season": "2025-B"},
            ]

        return assets

    # ── Submit report ─────────────────────────────────────────────

    def submit_report(
        self,
        verifier_id: int,
        asset_id: str,
        submitted_yield: float,
        confidence: float = 0.8,
        data_source: str = "INSPECTOR",
        measurement_method: str = "",
        notes: str = "",
    ) -> Dict[str, Any]:
        """Accept a verifier's yield submission and check for consensus."""
        verifier = get_verifier(verifier_id)
        if not verifier:
            raise ValueError(f"Verifier {verifier_id} not found")
        if not verifier["is_active"]:
            raise ValueError("Verifier account is suspended")

        sub_id = insert_verifier_submission(
            asset_id=asset_id,
            verifier_id=verifier_id,
            submitted_yield=submitted_yield,
            confidence=confidence,
            data_source=data_source,
            measurement_method=measurement_method,
            notes=notes,
        )

        submission = get_submission(sub_id)

        # Award a small reward for each accepted submission
        insert_verifier_reward(verifier_id, self.REWARD_PER_SUBMISSION, "SUBMISSION_FEE")

        # Check if we can form consensus
        consensus = self._try_consensus(asset_id)

        return {
            "submission": submission,
            "consensus_formed": consensus is not None,
            "consensus": consensus,
        }

    # ── Consensus ─────────────────────────────────────────────────

    def _try_consensus(self, asset_id: str) -> Optional[Dict[str, Any]]:
        """Check if enough submissions exist and form consensus."""
        existing = get_verifier_consensus(asset_id)
        if existing:
            return existing  # Already have consensus

        submissions = get_submissions_for_asset(asset_id, status="PENDING")
        if len(submissions) < self.MIN_SUBMISSIONS_FOR_CONSENSUS:
            return None

        # Build input for the consensus engine
        engine_input = []
        for sub in submissions:
            v = get_verifier(sub["verifier_id"])
            # Weight = base(1) + stake_bonus + reputation_bonus
            weight = 1.0
            if v:
                weight += v["stake_amount"] / 10000.0
                weight += v["reputation_score"] / 500.0
            engine_input.append({
                "source": f"verifier_{sub['verifier_id']}",
                "value": sub["submitted_yield"],
                "weight": weight,
            })

        consensus_yield, confidence, filtered = self._engine.run(engine_input)

        # Build sources list
        sources = []
        for sub in submissions:
            sources.append({
                "verifier_id": sub["verifier_id"],
                "yield": sub["submitted_yield"],
                "source": sub["data_source"],
                "submission_id": sub["id"],
            })

        # IPFS mock
        report_data = {
            "asset_id": asset_id,
            "consensus_yield": consensus_yield,
            "confidence": confidence,
            "sources": sources,
        }
        ipfs_hash = mock_ipfs_store(report_data)

        # Save consensus
        insert_verifier_consensus(
            asset_id=asset_id,
            consensus_yield=consensus_yield,
            confidence=confidence,
            submission_count=len(submissions),
            ipfs_hash=ipfs_hash,
            sources=sources,
        )

        # Mark submissions as ACCEPTED
        sub_ids = [s["id"] for s in submissions]
        update_submission_status(sub_ids, "ACCEPTED")

        # Award accuracy bonuses to verifiers close to the consensus
        for sub in submissions:
            deviation = abs(sub["submitted_yield"] - consensus_yield) / max(consensus_yield, 1)
            if deviation < 0.05:  # within 5%
                insert_verifier_reward(sub["verifier_id"], 10.0, "ACCURACY_BONUS")

        return get_verifier_consensus(asset_id)

    # ── History ───────────────────────────────────────────────────

    def get_my_submissions(self, verifier_id: int, limit: int = 50) -> list:
        return get_verifier_submissions(verifier_id, limit)

    def get_submission_detail(self, submission_id: int) -> Optional[dict]:
        return get_submission(submission_id)

    def get_consensus_reports(self, limit: int = 50) -> list:
        return list_verifier_consensus(limit)

    # ── Staking ───────────────────────────────────────────────────

    def stake_tokens(self, verifier_id: int, amount: float, lock_days: int = 30) -> dict:
        """Record a new stake deposit for a verifier."""
        if amount <= 0:
            raise ValueError("Stake amount must be positive")
        from datetime import datetime, timedelta, timezone
        lock_until = (datetime.now(timezone.utc) + timedelta(days=lock_days)).isoformat()
        stake_id = upsert_verifier_stake(verifier_id, amount, lock_until)
        return {
            "stake_id": stake_id,
            "amount": amount,
            "lock_until": lock_until,
            "verifier": get_verifier(verifier_id),
        }

    def get_stakes(self, verifier_id: int) -> list:
        return get_verifier_stakes(verifier_id)

    # ── Rewards ───────────────────────────────────────────────────

    def get_rewards(self, verifier_id: int, limit: int = 50) -> list:
        return get_verifier_rewards(verifier_id, limit)

    def get_total_rewards(self, verifier_id: int) -> float:
        return get_verifier_total_rewards(verifier_id)

    # ── Profile ───────────────────────────────────────────────────

    def get_profile(self, verifier_id: int) -> Optional[dict]:
        return get_verifier(verifier_id)

    def update_profile(self, verifier_id: int, **kwargs) -> dict:
        allowed = {"organization_name", "organization_type", "api_endpoint", "public_key"}
        filtered = {k: v for k, v in kwargs.items() if k in allowed}
        update_verifier(verifier_id, **filtered)
        return get_verifier(verifier_id)

    # ── Admin helpers ─────────────────────────────────────────────

    def list_all_verifiers(self, active_only: bool = True) -> list:
        return db_list_verifiers(active_only)
