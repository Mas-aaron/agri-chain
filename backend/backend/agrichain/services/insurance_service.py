"""
Layer 2 — Insurance Pool Service.

Handles premium calculation, deduction at minting, and automatic claim
processing when yield shortfall exceeds the deductible threshold.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from agrichain.db.risk_db import (
    connect,
    insert_insurance_premium,
    insert_insurance_claim,
    update_claim_status,
)
from agrichain.services.reputation_service import ReputationService

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

BASE_RATE = 0.02          # 2% of notional value
DEDUCTIBLE_PCT = 0.05     # 5% of predicted yield
COVERAGE_RATE = 0.80      # insurer covers 80% of eligible loss
PRICE_PER_KG = 0.25       # USD/kg (configurable / from market feed in prod)

VOLATILITY_SURCHARGE: Dict[str, float] = {
    "maize": 0.20,
    "wheat": 0.05,
    "rice": 0.15,
    "sorghum": 0.10,
    "barley": 0.08,
    "default": 0.12,
}


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _surcharge(crop_type: str) -> float:
    return VOLATILITY_SURCHARGE.get(crop_type.lower(), VOLATILITY_SURCHARGE["default"])


def _reputation_discount(score: float) -> float:
    """Max 50% discount for top-tier (score 1000)."""
    return min(0.5, score / 2000.0)


# ─────────────────────────────────────────────────────────────────────────────
# INSURANCE SERVICE
# ─────────────────────────────────────────────────────────────────────────────

class InsuranceService:
    """
    Computes and records insurance premiums and processes yield-shortfall claims.
    """

    def __init__(self, blockchain_store=None):
        self._store = blockchain_store
        self._rep_svc = ReputationService(blockchain_store)

    # ── Premiums ──────────────────────────────────────────────────────────────

    def calculate_premium(
        self,
        asset_id: str,
        farmer_id: str,
        crop_type: str,
        predicted_yield: float,
    ) -> Dict[str, Any]:
        """
        premium = BASE_RATE × (1 - rep_discount) × (1 + vol_surcharge) × notional_value
        notional_value = predicted_yield × PRICE_PER_KG
        """
        rep = self._rep_svc.get_reputation(farmer_id)
        rep_discount = _reputation_discount(rep["score"])
        vol_surcharge = _surcharge(crop_type)
        notional = predicted_yield * PRICE_PER_KG

        premium = BASE_RATE * (1 - rep_discount) * (1 + vol_surcharge) * notional

        return {
            "asset_id": asset_id,
            "farmer_id": farmer_id,
            "crop_type": crop_type,
            "predicted_yield": predicted_yield,
            "notional_value": round(notional, 2),
            "base_rate": BASE_RATE,
            "rep_discount": round(rep_discount, 4),
            "vol_surcharge": round(vol_surcharge, 4),
            "premium_amount": round(premium, 2),
            "reputation_tier": rep["tier"],
        }

    def record_premium(
        self,
        asset_id: str,
        farmer_id: str,
        crop_type: str,
        predicted_yield: float,
    ) -> Dict[str, Any]:
        """Calculate premium and persist it to the DB."""
        details = self.calculate_premium(asset_id, farmer_id, crop_type, predicted_yield)
        premium_id = insert_insurance_premium(
            asset_id=asset_id,
            farmer_id=farmer_id,
            crop_type=crop_type,
            premium_amount=details["premium_amount"],
            base_rate=details["base_rate"],
            rep_discount=details["rep_discount"],
            vol_surcharge=details["vol_surcharge"],
        )
        logger.info(
            f"Insurance premium recorded: asset={asset_id}, "
            f"amount={details['premium_amount']:.2f}, id={premium_id}"
        )
        # Optionally call chaincode InitInsurancePool
        if self._store:
            try:
                self._store._try_fabric_invoke(
                    "InitInsurancePool",
                    [asset_id, str(details["premium_amount"])],
                )
            except Exception as e:
                logger.warning(f"Chaincode InitInsurancePool failed (non-fatal): {e}")

        return {**details, "premium_id": premium_id}

    # ── Claims ────────────────────────────────────────────────────────────────

    def pool_balance(self, asset_id: str) -> Dict[str, Any]:
        """Calculate current pool balance from DB records."""
        with connect() as conn:
            premiums = conn.execute(
                "SELECT COALESCE(SUM(premium_amount),0) as total FROM insurance_premiums WHERE asset_id=?",
                (asset_id,),
            ).fetchone()
            claims = conn.execute(
                "SELECT COALESCE(SUM(payout_amount),0) as total FROM insurance_claims "
                "WHERE asset_id=? AND status='PAID'",
                (asset_id,),
            ).fetchone()
        premium_total = premiums["total"] if premiums else 0.0
        payout_total = claims["total"] if claims else 0.0
        return {
            "asset_id": asset_id,
            "premium_collected": round(premium_total, 2),
            "claims_paid": round(payout_total, 2),
            "current_balance": round(premium_total - payout_total, 2),
        }

    def process_claim(
        self,
        asset_id: str,
        actual_yield: float,
        predicted_yield: float,
        token_amount: float,
    ) -> Optional[Dict[str, Any]]:
        """
        Trigger a claim if shortfall > DEDUCTIBLE_PCT.

        Payout = (shortfall_pct - DEDUCTIBLE_PCT) × COVERAGE_RATE × token_amount × PRICE_PER_KG
        Capped to current pool balance.
        """
        if predicted_yield <= 0:
            logger.error("process_claim: predicted_yield is zero")
            return None

        shortfall_pct = max(0, (predicted_yield - actual_yield) / predicted_yield)

        if shortfall_pct <= DEDUCTIBLE_PCT:
            logger.info(f"Asset {asset_id}: shortfall {shortfall_pct:.1%} within deductible — no claim.")
            return None

        eligible_shortfall = shortfall_pct - DEDUCTIBLE_PCT
        payout = eligible_shortfall * COVERAGE_RATE * token_amount * PRICE_PER_KG

        # Cap to pool balance
        balance = self.pool_balance(asset_id)
        payout = min(payout, balance["current_balance"])

        if payout <= 0:
            logger.warning(f"Asset {asset_id}: pool empty, no payout possible.")
            return None

        # Persist claim
        claim_id = insert_insurance_claim(
            asset_id=asset_id,
            shortfall_pct=shortfall_pct,
            payout_amount=round(payout, 2),
        )

        # Call chaincode ProcessClaim
        chaincode_ok = False
        if self._store:
            try:
                self._store._try_fabric_invoke(
                    "ProcessClaim",
                    [asset_id, str(shortfall_pct), str(payout)],
                )
                chaincode_ok = True
            except Exception as e:
                logger.warning(f"Chaincode ProcessClaim failed (non-fatal): {e}")

        # Mark as PAID in DB
        update_claim_status(claim_id, "PAID")
        logger.info(
            f"Insurance claim processed: asset={asset_id}, shortfall={shortfall_pct:.1%}, "
            f"payout={payout:.2f}, claim_id={claim_id}"
        )

        return {
            "claim_id": claim_id,
            "asset_id": asset_id,
            "shortfall_pct": round(shortfall_pct, 4),
            "payout_amount": round(payout, 2),
            "status": "PAID",
            "chaincode_invoked": chaincode_ok,
        }

    def list_claims(self, asset_id: Optional[str] = None) -> list:
        with connect() as conn:
            if asset_id:
                rows = conn.execute(
                    "SELECT * FROM insurance_claims WHERE asset_id=? ORDER BY id DESC",
                    (asset_id,),
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT * FROM insurance_claims ORDER BY id DESC"
                ).fetchall()
        return [dict(r) for r in rows]
