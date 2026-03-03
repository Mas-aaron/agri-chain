"""
Layer 4 — ML Model Staking Service.

Manages token stakes by ML model providers.
Tracks per-harvest accuracy and runs season-end evaluation
to slash underperformers and reward high-accuracy providers.
"""
from __future__ import annotations

import logging
import statistics
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional

from agrichain.db.risk_db import (
    get_ml_stake,
    upsert_ml_stake,
    insert_ml_performance,
    get_model_season_performance,
)

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

SLASH_THRESHOLD = 0.15   # avg discrepancy > 15% → slash
REWARD_THRESHOLD = 0.05  # avg discrepancy < 5%  → reward
LOCK_DAYS = 30           # unstake lock period


class MLStakingService:
    """
    Manages ML model provider stakes, accuracy tracking,
    slashing, and rewards.
    """

    def __init__(self, blockchain_store=None):
        self._store = blockchain_store

    # ─────────────────────────────────────────────────────────────
    # STAKING
    # ─────────────────────────────────────────────────────────────

    def stake(
        self, provider_id: str, model_id: str, amount: float
    ) -> Dict[str, Any]:
        """Add tokens to a provider's model stake."""
        if amount <= 0:
            raise ValueError("Stake amount must be positive")

        existing = get_ml_stake(provider_id, model_id)
        now_iso = datetime.now(timezone.utc).isoformat()

        if existing:
            new_stake = existing["stake_amount"] + amount
            total_slashed = existing["total_slashed"]
            total_rewarded = existing["total_rewarded"]
            locked_until = existing["locked_until"]
        else:
            new_stake = amount
            total_slashed = 0.0
            total_rewarded = 0.0
            locked_until = None

        upsert_ml_stake(
            provider_id, model_id, new_stake,
            total_slashed, total_rewarded, locked_until
        )

        # Optionally call chaincode
        if self._store:
            try:
                self._store._try_fabric_invoke(
                    "StakeMLModel", [provider_id, model_id, str(amount)]
                )
            except Exception as e:
                logger.warning(f"Chaincode StakeMLModel skipped: {e}")

        logger.info(f"Stake added: provider={provider_id}, model={model_id}, amount={amount}")
        return {
            "provider_id": provider_id,
            "model_id": model_id,
            "added_amount": amount,
            "total_stake": new_stake,
        }

    def unstake(
        self, provider_id: str, model_id: str, amount: float
    ) -> Dict[str, Any]:
        """
        Withdraw from stake, subject to 30-day lock period.
        Initiating an unstake resets the lock.
        """
        if amount <= 0:
            raise ValueError("Unstake amount must be positive")

        existing = get_ml_stake(provider_id, model_id)
        if not existing:
            raise ValueError(f"No stake found for {provider_id}/{model_id}")

        # Check lock period
        if existing.get("locked_until"):
            lock_dt = datetime.fromisoformat(existing["locked_until"])
            if datetime.now(timezone.utc) < lock_dt:
                raise ValueError(
                    f"Stake is locked until {existing['locked_until']}. "
                    f"Cannot unstake yet."
                )

        if amount > existing["stake_amount"]:
            raise ValueError(
                f"Insufficient stake: have {existing['stake_amount']:.2f}, requested {amount:.2f}"
            )

        new_stake = existing["stake_amount"] - amount
        # Re-lock for LOCK_DAYS from now
        new_lock = (datetime.now(timezone.utc) + timedelta(days=LOCK_DAYS)).isoformat()
        upsert_ml_stake(
            provider_id, model_id, new_stake,
            existing["total_slashed"], existing["total_rewarded"], new_lock
        )

        return {
            "provider_id": provider_id,
            "model_id": model_id,
            "withdrawn": amount,
            "remaining_stake": new_stake,
            "locked_until": new_lock,
        }

    def get_stake_info(self, provider_id: str, model_id: str) -> Optional[Dict[str, Any]]:
        """Return current stake details."""
        return get_ml_stake(provider_id, model_id)

    # ─────────────────────────────────────────────────────────────
    # PERFORMANCE TRACKING
    # ─────────────────────────────────────────────────────────────

    def record_accuracy(
        self,
        model_id: str,
        asset_id: str,
        season: int,
        actual_yield: float,
        predicted_yield: float,
    ) -> Dict[str, Any]:
        """
        Compute and persist the discrepancy for one harvest.
        discrepancy_pct = |actual - predicted| / predicted
        """
        if predicted_yield <= 0:
            return {"error": "predicted_yield must be positive"}

        disc = abs(actual_yield - predicted_yield) / predicted_yield
        rec_id = insert_ml_performance(model_id, asset_id, season, disc)

        # Also call chaincode
        if self._store:
            try:
                self._store._try_fabric_invoke(
                    "RecordPredictionAccuracy",
                    [asset_id, model_id, str(disc)],
                )
            except Exception as e:
                logger.warning(f"Chaincode RecordPredictionAccuracy skipped: {e}")

        return {
            "record_id": rec_id,
            "model_id": model_id,
            "asset_id": asset_id,
            "season": season,
            "discrepancy_pct": round(disc, 4),
        }

    # ─────────────────────────────────────────────────────────────
    # SEASON EVALUATION (Slash / Reward)
    # ─────────────────────────────────────────────────────────────

    def evaluate_season(
        self, provider_id: str, model_id: str, season: int
    ) -> Dict[str, Any]:
        """
        Called at end of each season.
        - avg_discrepancy > 15%: slash
        - avg_discrepancy < 5%: reward
        - between 5–15%: no action
        """
        records = get_model_season_performance(model_id, season)
        if not records:
            return {
                "provider_id": provider_id,
                "model_id": model_id,
                "season": season,
                "action": "NO_RECORDS",
                "message": "No performance records for this season.",
            }

        discrepancies = [r["discrepancy_pct"] for r in records]
        avg_disc = statistics.mean(discrepancies)

        existing = get_ml_stake(provider_id, model_id)
        current_stake = existing["stake_amount"] if existing else 0.0

        action = "NONE"
        amount = 0.0
        result_detail = {}

        if avg_disc > SLASH_THRESHOLD:
            slash_factor = min(1.0, (avg_disc - SLASH_THRESHOLD) / SLASH_THRESHOLD)
            amount = current_stake * slash_factor
            action = "SLASH"
            new_stake = max(0.0, current_stake - amount)
            new_slashed = (existing["total_slashed"] if existing else 0.0) + amount
            upsert_ml_stake(
                provider_id, model_id, new_stake,
                new_slashed,
                existing["total_rewarded"] if existing else 0.0,
                existing["locked_until"] if existing else None,
            )
            # Call chaincode
            if self._store:
                try:
                    self._store._try_fabric_invoke(
                        "SlashStake", [provider_id, model_id, str(amount)]
                    )
                except Exception as e:
                    logger.warning(f"Chaincode SlashStake skipped: {e}")

            result_detail = {
                "slash_amount": round(amount, 4),
                "remaining_stake": round(new_stake, 4),
                "slash_factor": round(slash_factor, 4),
            }
            logger.warning(
                f"SLASH: model={model_id}, avg_disc={avg_disc:.1%}, "
                f"slashed={amount:.2f}"
            )

        elif avg_disc < REWARD_THRESHOLD and current_stake > 0:
            reward_amount = current_stake * (REWARD_THRESHOLD - avg_disc) * 2.0
            amount = reward_amount
            action = "REWARD"
            new_stake = current_stake + reward_amount
            new_rewarded = (existing["total_rewarded"] if existing else 0.0) + reward_amount
            upsert_ml_stake(
                provider_id, model_id, new_stake,
                existing["total_slashed"] if existing else 0.0,
                new_rewarded,
                existing["locked_until"] if existing else None,
            )
            # Call chaincode
            if self._store:
                try:
                    self._store._try_fabric_invoke(
                        "RewardStake", [provider_id, model_id, str(reward_amount)]
                    )
                except Exception as e:
                    logger.warning(f"Chaincode RewardStake skipped: {e}")

            result_detail = {
                "reward_amount": round(reward_amount, 4),
                "new_stake": round(new_stake, 4),
            }
            logger.info(
                f"REWARD: model={model_id}, avg_disc={avg_disc:.1%}, "
                f"reward={reward_amount:.2f}"
            )

        return {
            "provider_id": provider_id,
            "model_id": model_id,
            "season": season,
            "num_records": len(records),
            "avg_discrepancy_pct": round(avg_disc, 4),
            "action": action,
            "amount": round(amount, 4),
            **result_detail,
        }
