"""
Layer 5 — Farmer Reputation Service.

Computes a rolling-average accuracy score (0–1000) based on past
harvest discrepancies and classifies farmers into tiers.
Tier affects loan LTV and insurance premiums.
"""
from __future__ import annotations

import logging
import math
from typing import Any, Dict, Optional

from agrichain.db.risk_db import (
    get_farmer_reputation,
    upsert_farmer_reputation,
)

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

TIER_THRESHOLDS = {
    "Platinum": 900,
    "Gold": 800,
    "Silver": 700,
    "Bronze": 600,
    "New": 0,
}

# Loan-to-Value ratios per tier
TIER_LTV = {
    "Platinum": 0.80,
    "Gold": 0.75,
    "Silver": 0.70,
    "Bronze": 0.65,
    "New": 0.60,
}

DEFAULT_SCORE = 500.0


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _classify_tier(score: float) -> str:
    for tier, threshold in TIER_THRESHOLDS.items():
        if score >= threshold:
            return tier
    return "New"


def _compute_accuracy(actual: float, predicted: float) -> float:
    """
    Harvest accuracy score ∈ [0, 1000].
    accuracy = max(0, 1 − |actual − predicted| / predicted) × 1000
    """
    if predicted <= 0:
        return 0.0
    raw = max(0.0, 1.0 - abs(actual - predicted) / predicted)
    return round(raw * 1000.0, 2)


def _rolling_average(old_score: float, old_n: int, new_accuracy: float) -> float:
    """Incremental weighted average."""
    n = float(old_n)
    new_score = (old_score * n + new_accuracy) / (n + 1.0)
    return round(max(0.0, min(1000.0, new_score)), 4)


# ─────────────────────────────────────────────────────────────────────────────
# REPUTATION SERVICE
# ─────────────────────────────────────────────────────────────────────────────

class ReputationService:
    """
    Manages farmer reputation scores.
    """

    def __init__(self, blockchain_store=None):
        self._store = blockchain_store

    def get_reputation(self, farmer_id: str) -> Dict[str, Any]:
        """Return current reputation profile; creates a default if none exists."""
        data = get_farmer_reputation(farmer_id)
        if data:
            score = data["score"]
            tier = data["tier"]
            total_harvests = data["total_harvests"]
        else:
            score = DEFAULT_SCORE
            tier = _classify_tier(score)
            total_harvests = 0

        ltv = TIER_LTV.get(tier, 0.60)
        discount = min(0.5, score / 2000.0)

        return {
            "farmer_id": farmer_id,
            "score": score,
            "tier": tier,
            "total_harvests": total_harvests,
            "loan_ltv": ltv,
            "insurance_discount": round(discount, 4),
        }

    def update_after_harvest(
        self,
        farmer_id: str,
        actual_yield: float,
        predicted_yield: float,
    ) -> Dict[str, Any]:
        """
        Called after oracle confirms actual yield.
        Updates rolling score and tier.
        """
        accuracy = _compute_accuracy(actual_yield, predicted_yield)
        existing = get_farmer_reputation(farmer_id)

        old_score = existing["score"] if existing else DEFAULT_SCORE
        old_n = existing["total_harvests"] if existing else 0

        new_score = _rolling_average(old_score, old_n, accuracy)
        new_tier = _classify_tier(new_score)
        new_n = old_n + 1

        upsert_farmer_reputation(farmer_id, new_score, new_tier, new_n)

        logger.info(
            f"Reputation updated: farmer={farmer_id}, "
            f"accuracy={accuracy:.1f}, score={old_score:.1f}→{new_score:.1f}, "
            f"tier={new_tier}, harvests={new_n}"
        )

        # Optionally push to chaincode for on-chain transparency (best-effort)
        if self._store:
            try:
                self._store._try_fabric_invoke(
                    "UpdateReputation",
                    [farmer_id, str(actual_yield), str(predicted_yield)],
                )
            except Exception as e:
                logger.warning(f"Chaincode UpdateReputation skipped: {e}")

        return {
            "farmer_id": farmer_id,
            "accuracy_this_harvest": accuracy,
            "old_score": old_score,
            "new_score": new_score,
            "old_tier": _classify_tier(old_score),
            "new_tier": new_tier,
            "total_harvests": new_n,
            "loan_ltv": TIER_LTV.get(new_tier, 0.60),
            "insurance_discount": round(min(0.5, new_score / 2000.0), 4),
        }

    def get_loan_terms(self, farmer_id: str) -> Dict[str, Any]:
        """Return loan terms influenced by reputation tier."""
        rep = self.get_reputation(farmer_id)
        tier = rep["tier"]
        return {
            "farmer_id": farmer_id,
            "tier": tier,
            "score": rep["score"],
            "max_ltv_pct": int(TIER_LTV.get(tier, 0.60) * 100),
            "insurance_discount_pct": int(rep["insurance_discount"] * 100),
            "description": (
                f"{tier} tier farmers qualify for up to "
                f"{int(TIER_LTV.get(tier, 0.60) * 100)}% LTV loans and "
                f"{int(rep['insurance_discount'] * 100)}% insurance premium discount."
            ),
        }
