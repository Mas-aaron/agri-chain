"""
Layer 3 — Dynamic Token Adjustment Service.

Computes the token supply change required after oracle-confirmed yield
and coordinates with insurance (Layer 2) and reputation (Layer 5).
This is the central post-harvest settlement pipeline.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, Optional

from agrichain.db.risk_db import insert_adjustment_event
from agrichain.services.insurance_service import InsuranceService, DEDUCTIBLE_PCT
from agrichain.services.reputation_service import ReputationService

logger = logging.getLogger(__name__)

# Shortfall below this → partial burn, no insurance claim
SMALL_SHORTFALL_LIMIT = 0.10


class AdjustmentService:
    """
    Orchestrates the full post-harvest risk settlement:
    1. Compute adjustment factor (actual / predicted).
    2. If over-performance → mint bonus tokens.
    3. If small shortfall (≤10%) → proportional burn.
    4. If large shortfall (>10%) → trigger insurance, then burn.
    5. Update farmer reputation.
    6. Call chaincode UpdateActualYield to settle on-chain.
    7. Record adjustment event in DB.
    """

    def __init__(self, blockchain_store=None):
        self._store = blockchain_store
        self._insurance = InsuranceService(blockchain_store)
        self._reputation = ReputationService(blockchain_store)

    # ─────────────────────────────────────────────────────────────
    # COMPUTATION
    # ─────────────────────────────────────────────────────────────

    def compute_adjustment(
        self,
        actual_yield: float,
        predicted_yield: float,
        token_amount: float,
    ) -> Dict[str, Any]:
        """
        Pure calculation — no side effects.

        Returns a dict describing the required adjustment:
          action: MINT_BONUS | BURN_PARTIAL | BURN_SHORTFALL | NONE
          adjustment_factor: actual / predicted
          tokens_delta: positive = minted, negative = burned
          insurance_required: bool
        """
        if predicted_yield <= 0:
            return {"action": "NONE", "adjustment_factor": 1.0, "tokens_delta": 0.0,
                    "insurance_required": False}

        factor = actual_yield / predicted_yield
        shortfall_pct = max(0.0, 1.0 - factor)

        if factor >= 1.0:
            bonus_tokens = token_amount * (factor - 1.0)
            return {
                "action": "MINT_BONUS",
                "adjustment_factor": round(factor, 6),
                "tokens_delta": round(bonus_tokens, 4),
                "farmer_bonus": round(bonus_tokens * 0.5, 4),
                "holders_bonus": round(bonus_tokens * 0.5, 4),
                "insurance_required": False,
                "shortfall_pct": 0.0,
            }

        burn_tokens = token_amount * shortfall_pct

        if shortfall_pct <= SMALL_SHORTFALL_LIMIT:
            return {
                "action": "BURN_PARTIAL",
                "adjustment_factor": round(factor, 6),
                "tokens_delta": round(-burn_tokens, 4),
                "insurance_required": False,
                "shortfall_pct": round(shortfall_pct, 4),
            }

        return {
            "action": "BURN_SHORTFALL",
            "adjustment_factor": round(factor, 6),
            "tokens_delta": round(-burn_tokens, 4),
            "insurance_required": True,
            "shortfall_pct": round(shortfall_pct, 4),
        }

    # ─────────────────────────────────────────────────────────────
    # EXECUTION
    # ─────────────────────────────────────────────────────────────

    def execute(
        self,
        asset_id: str,
        farmer_id: str,
        crop_type: str,
        actual_yield: float,
        predicted_yield: float,
        token_amount: float,
        oracle_confidence: float,
        ipfs_hash: str,
    ) -> Dict[str, Any]:
        """
        Full settlement pipeline for a single asset after harvest.
        """
        logger.info(
            f"Adjustment: settling asset={asset_id}, "
            f"predicted={predicted_yield:.1f}, actual={actual_yield:.1f}"
        )

        # ── Step 1: Compute adjustment ────────────────────────────
        adj = self.compute_adjustment(actual_yield, predicted_yield, token_amount)

        # ── Step 2: Insurance claim if needed ─────────────────────
        claim_result = None
        if adj["insurance_required"]:
            claim_result = self._insurance.process_claim(
                asset_id=asset_id,
                actual_yield=actual_yield,
                predicted_yield=predicted_yield,
                token_amount=token_amount,
            )

        # ── Step 3: On-chain settlement ───────────────────────────
        chaincode_result = None
        if self._store:
            try:
                chaincode_result = self._store._try_fabric_invoke(
                    "UpdateActualYield",
                    [asset_id, str(actual_yield), str(oracle_confidence), ipfs_hash],
                )
                logger.info(f"Chaincode UpdateActualYield: {chaincode_result}")
            except Exception as exc:
                logger.error(f"Chaincode UpdateActualYield failed: {exc}")

        # ── Step 4: Update farmer reputation ─────────────────────
        rep_result = self._reputation.update_after_harvest(
            farmer_id=farmer_id,
            actual_yield=actual_yield,
            predicted_yield=predicted_yield,
        )

        # ── Step 5: Persist adjustment event ─────────────────────
        event_id = insert_adjustment_event(
            asset_id=asset_id,
            action=adj["action"],
            adjustment_factor=adj["adjustment_factor"],
            tokens_delta=adj["tokens_delta"],
            oracle_confidence=oracle_confidence,
            ipfs_hash=ipfs_hash,
        )

        return {
            "asset_id": asset_id,
            "farmer_id": farmer_id,
            "adjustment": adj,
            "claim": claim_result,
            "reputation": rep_result,
            "chaincode_invoked": chaincode_result is not None,
            "adjustment_event_id": event_id,
        }
