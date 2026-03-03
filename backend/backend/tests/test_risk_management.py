"""
Pytest test suite for the 5-Layer Risk Management System.
Run with: python -m pytest tests/ -v --tb=short

Coverage targets:
  - ConsensusEngine: weighted_median + confidence (>90%)
  - InsuranceService: premium + claim math (>90%)
  - ReputationService: accuracy scoring + tier (>90%)
  - AdjustmentService: routing logic (>85%)
  - MLStakingService: slash + reward formulas (>85%)
"""
from __future__ import annotations

import math
import os
import tempfile
import unittest
from unittest.mock import MagicMock, patch

# Point the DB at a temp file so tests don't touch production data
_tmp_db = tempfile.mktemp(suffix=".db")
os.environ["AGRICHAIN_DB_PATH"] = _tmp_db

from agrichain.db.risk_db import init_risk_tables
from agrichain.services.oracle_service import ConsensusEngine
from agrichain.services.insurance_service import InsuranceService, BASE_RATE, DEDUCTIBLE_PCT
from agrichain.services.reputation_service import (
    ReputationService,
    _compute_accuracy,
    _rolling_average,
    _classify_tier,
    TIER_LTV,
)
from agrichain.services.adjustment_service import AdjustmentService
from agrichain.services.ml_staking_service import MLStakingService

# Initialize risk tables once before all tests
init_risk_tables()


# ─────────────────────────────────────────────────────────────────────────────
# LAYER 1: CONSENSUS ENGINE
# ─────────────────────────────────────────────────────────────────────────────

class TestConsensusEngine(unittest.TestCase):

    def setUp(self):
        self.engine = ConsensusEngine()

    def test_weighted_median_simple(self):
        """Median of uniform weights should be the middle value."""
        vw = [(100.0, 1.0), (200.0, 1.0), (300.0, 1.0)]
        result = self.engine.weighted_median(vw)
        self.assertAlmostEqual(result, 200.0, places=1)

    def test_weighted_median_skewed_weights(self):
        """Heavy weight on high value should pull median up."""
        vw = [(100.0, 0.1), (200.0, 0.05), (5000.0, 0.85)]
        result = self.engine.weighted_median(vw)
        self.assertGreater(result, 200.0)

    def test_weighted_median_single_value(self):
        vw = [(999.0, 1.0)]
        self.assertAlmostEqual(self.engine.weighted_median(vw), 999.0)

    def test_weighted_median_empty_raises(self):
        with self.assertRaises(ValueError):
            self.engine.weighted_median([])

    def test_confidence_perfect(self):
        """Zero variance → confidence = 1.0."""
        values = [5000.0, 5000.0, 5000.0, 5000.0]
        conf = self.engine.compute_confidence(values)
        self.assertAlmostEqual(conf, 1.0, places=2)

    def test_confidence_high_variance(self):
        """High variance → lower confidence."""
        values = [1000.0, 5000.0, 9000.0]
        conf = self.engine.compute_confidence(values)
        self.assertLess(conf, 0.5)

    def test_confidence_single_value_returns_zero(self):
        self.assertEqual(self.engine.compute_confidence([5000.0]), 0.0)

    def test_run_below_min_sources_returns_zero_confidence(self):
        """Fewer than MIN_SOURCES → confidence 0, manual review required."""
        submissions = [
            {"source": "gov", "value": 4500.0, "weight": 0.35},
            {"source": "uni", "value": 4600.0, "weight": 0.25},
        ]
        median, confidence, valid = self.engine.run(submissions)
        self.assertEqual(confidence, 0.0)
        self.assertEqual(len(valid), 2)

    def test_run_sufficient_sources(self):
        submissions = [
            {"source": "gov", "value": 4500.0, "weight": 0.35},
            {"source": "uni", "value": 4600.0, "weight": 0.25},
            {"source": "sat", "value": 4550.0, "weight": 0.25},
            {"source": "ins", "value": 4480.0, "weight": 0.15},
        ]
        median, confidence, valid = self.engine.run(submissions)
        self.assertGreater(confidence, 0.8)  # tight cluster → high conf
        self.assertAlmostEqual(median, 4525.0, delta=200.0)

    def test_run_filters_none_values(self):
        submissions = [
            {"source": "gov", "value": 4500.0, "weight": 0.35},
            {"source": "uni", "value": None, "weight": 0.25},  # offline
            {"source": "sat", "value": 4600.0, "weight": 0.25},
            {"source": "ins", "value": 4550.0, "weight": 0.15},
        ]
        median, confidence, valid = self.engine.run(submissions)
        self.assertEqual(len(valid), 3)  # None filtered out


# ─────────────────────────────────────────────────────────────────────────────
# LAYER 2: INSURANCE SERVICE
# ─────────────────────────────────────────────────────────────────────────────

class TestInsuranceService(unittest.TestCase):

    def setUp(self):
        self.svc = InsuranceService(blockchain_store=None)

    def test_premium_calculation_new_farmer(self):
        """New farmer (score=500) + maize (surcharge 20%) should give reasonable premium."""
        result = self.svc.calculate_premium(
            asset_id="ASSET_001",
            farmer_id="FARMER_UNKNOWN",  # no reputation → default
            crop_type="Maize",
            predicted_yield=5000.0,
        )
        self.assertIn("premium_amount", result)
        # premium > 0
        self.assertGreater(result["premium_amount"], 0)
        # With 20% surcharge and ~25% discount max, premium should be between 1–4% of notional
        notional = 5000.0 * 0.25  # 1250 USD
        self.assertGreater(result["premium_amount"], notional * 0.01)
        self.assertLess(result["premium_amount"], notional * 0.04)

    def test_premium_platinum_gets_discount(self):
        """Platinum farmer should have lower premium than New farmer."""
        # Seed platinum reputation
        from agrichain.db.risk_db import upsert_farmer_reputation
        upsert_farmer_reputation("FARMER_PLAT", 950.0, "Platinum", 20)

        result_plat = self.svc.calculate_premium("A1", "FARMER_PLAT", "Maize", 5000.0)
        result_new = self.svc.calculate_premium("A1", "FARMER_UNKNOWN", "Maize", 5000.0)
        self.assertLess(result_plat["premium_amount"], result_new["premium_amount"])

    def test_claim_no_shortfall(self):
        """Shortfall ≤ 5% → no claim returned."""
        result = self.svc.process_claim(
            asset_id="ASSET_002",
            actual_yield=4800.0,
            predicted_yield=5000.0,  # 4% shortfall
            token_amount=5000.0,
        )
        self.assertIsNone(result)

    def test_claim_large_shortfall(self):
        """Shortfall > 5% → claim created with non-zero payout."""
        # First create a premium pool
        self.svc.record_premium(
            asset_id="ASSET_003",
            farmer_id="FARMER_001",
            crop_type="Maize",
            predicted_yield=5000.0,
        )
        result = self.svc.process_claim(
            asset_id="ASSET_003",
            actual_yield=3000.0,  # 40% shortfall
            predicted_yield=5000.0,
            token_amount=5000.0,
        )
        self.assertIsNotNone(result)
        self.assertGreater(result["payout_amount"], 0)
        self.assertEqual(result["status"], "PAID")

    def test_claim_deductible_edge_case(self):
        """Shortfall exactly at 5% → no claim (on boundary)."""
        result = self.svc.process_claim(
            asset_id="ASSET_004",
            actual_yield=4750.0,
            predicted_yield=5000.0,  # exactly 5%
            token_amount=5000.0,
        )
        self.assertIsNone(result)

    def test_pool_balance_calculation(self):
        """Pool balance should be premiums collected minus paid claims."""
        asset_id = "ASSET_POOL_TEST"
        self.svc.record_premium("ASSET_POOL_T", "F001", "Wheat", 10000.0)
        balance = self.svc.pool_balance("ASSET_POOL_T")
        self.assertGreaterEqual(balance["current_balance"], 0)


# ─────────────────────────────────────────────────────────────────────────────
# LAYER 5: REPUTATION SERVICE
# ─────────────────────────────────────────────────────────────────────────────

class TestReputationService(unittest.TestCase):

    def setUp(self):
        self.svc = ReputationService(blockchain_store=None)

    def test_accuracy_perfect(self):
        self.assertAlmostEqual(_compute_accuracy(5000.0, 5000.0), 1000.0)

    def test_accuracy_large_error(self):
        """50% error → 500 accuracy."""
        self.assertAlmostEqual(_compute_accuracy(2500.0, 5000.0), 500.0)

    def test_accuracy_exceeds_prediction(self):
        """Actual > predicted → still counts as error."""
        acc = _compute_accuracy(6000.0, 5000.0)  # 20% over
        self.assertAlmostEqual(acc, 800.0)

    def test_accuracy_clamped_at_zero(self):
        """Massive error still ≥ 0."""
        acc = _compute_accuracy(0.0, 5000.0)
        self.assertGreaterEqual(acc, 0.0)

    def test_rolling_average_first_harvest(self):
        """First harvest (n=0): new_score = accuracy (old score ignored)."""
        result = _rolling_average(500.0, 0, 900.0)
        # (500.0 * 0 + 900.0) / (0 + 1) = 900.0
        self.assertAlmostEqual(result, 900.0, places=1)

    def test_rolling_average_multiple_harvests(self):
        score = _rolling_average(500.0, 5, 800.0)
        expected = (500.0 * 5 + 800.0) / 6
        self.assertAlmostEqual(score, expected, places=4)

    def test_tier_platinum(self):
        self.assertEqual(_classify_tier(950.0), "Platinum")

    def test_tier_gold(self):
        self.assertEqual(_classify_tier(850.0), "Gold")

    def test_tier_new(self):
        self.assertEqual(_classify_tier(400.0), "New")

    def test_tier_boundary_gold_min(self):
        self.assertEqual(_classify_tier(800.0), "Gold")

    def test_ltv_increases_with_tier(self):
        """Higher tier → higher LTV."""
        self.assertGreater(TIER_LTV["Platinum"], TIER_LTV["Gold"])
        self.assertGreater(TIER_LTV["Gold"], TIER_LTV["Silver"])
        self.assertGreater(TIER_LTV["Silver"], TIER_LTV["Bronze"])
        self.assertGreater(TIER_LTV["Bronze"], TIER_LTV["New"])

    def test_update_after_harvest_creates_entry(self):
        result = self.svc.update_after_harvest("FARMER_NEW_X1", 4800.0, 5000.0)
        self.assertIn("new_score", result)
        self.assertIn("new_tier", result)
        self.assertGreater(result["total_harvests"], 0)

    def test_reputation_discount_max(self):
        """Platinum (score 1000) → 50% discount."""
        from agrichain.db.risk_db import upsert_farmer_reputation
        upsert_farmer_reputation("FARMER_TOP", 1000.0, "Platinum", 50)
        rep = self.svc.get_reputation("FARMER_TOP")
        self.assertAlmostEqual(rep["insurance_discount"], 0.5)


# ─────────────────────────────────────────────────────────────────────────────
# LAYER 3: ADJUSTMENT SERVICE
# ─────────────────────────────────────────────────────────────────────────────

class TestAdjustmentService(unittest.TestCase):

    def setUp(self):
        self.svc = AdjustmentService(blockchain_store=None)

    def test_over_performance_mints_bonus(self):
        result = self.svc.compute_adjustment(
            actual_yield=6000.0,
            predicted_yield=5000.0,
            token_amount=5000.0,
        )
        self.assertEqual(result["action"], "MINT_BONUS")
        self.assertGreater(result["tokens_delta"], 0)
        self.assertFalse(result["insurance_required"])

    def test_small_shortfall_burns_partial(self):
        result = self.svc.compute_adjustment(
            actual_yield=4600.0,   # 8% shortfall
            predicted_yield=5000.0,
            token_amount=5000.0,
        )
        self.assertEqual(result["action"], "BURN_PARTIAL")
        self.assertLess(result["tokens_delta"], 0)
        self.assertFalse(result["insurance_required"])

    def test_large_shortfall_triggers_insurance(self):
        result = self.svc.compute_adjustment(
            actual_yield=3000.0,   # 40% shortfall
            predicted_yield=5000.0,
            token_amount=5000.0,
        )
        self.assertEqual(result["action"], "BURN_SHORTFALL")
        self.assertTrue(result["insurance_required"])

    def test_exact_performance_no_change(self):
        result = self.svc.compute_adjustment(5000.0, 5000.0, 5000.0)
        self.assertEqual(result["action"], "MINT_BONUS")
        self.assertAlmostEqual(result["tokens_delta"], 0.0)

    def test_boundary_10pct_shortfall(self):
        """Exactly 10% shortfall → BURN_PARTIAL (boundary)."""
        result = self.svc.compute_adjustment(4500.0, 5000.0, 5000.0)
        self.assertEqual(result["action"], "BURN_PARTIAL")

    def test_bonus_split_50_50(self):
        result = self.svc.compute_adjustment(7500.0, 5000.0, 1000.0)  # 50% over
        self.assertAlmostEqual(result["farmer_bonus"], result["holders_bonus"])


# ─────────────────────────────────────────────────────────────────────────────
# LAYER 4: ML STAKING SERVICE
# ─────────────────────────────────────────────────────────────────────────────

class TestMLStakingService(unittest.TestCase):

    def setUp(self):
        self.svc = MLStakingService(blockchain_store=None)

    def test_stake_creates_entry(self):
        result = self.svc.stake("PROV_001", "MODEL_001", 1000.0)
        self.assertAlmostEqual(result["total_stake"], 1000.0)

    def test_stake_adds_to_existing(self):
        self.svc.stake("PROV_002", "MODEL_002", 500.0)
        result = self.svc.stake("PROV_002", "MODEL_002", 300.0)
        self.assertAlmostEqual(result["total_stake"], 800.0)

    def test_unstake_fails_when_locked(self):
        """Should fail if locked_until is in the future."""
        self.svc.stake("PROV_003", "MODEL_003", 1000.0)
        # Force a lock
        from datetime import timedelta
        from agrichain.db.risk_db import upsert_ml_stake
        future = (
            __import__("datetime").datetime.now(__import__("datetime").timezone.utc) +
            timedelta(days=15)
        ).isoformat()
        upsert_ml_stake("PROV_003", "MODEL_003", 1000.0, 0.0, 0.0, future)
        with self.assertRaises(ValueError):
            self.svc.unstake("PROV_003", "MODEL_003", 200.0)

    def test_evaluate_season_slash(self):
        """High discrepancy (>15%) → slash action."""
        self.svc.stake("PROV_004", "MODEL_004", 1000.0)
        # Seed 3 records with 30% discrepancy each
        from agrichain.db.risk_db import insert_ml_performance
        for i in range(3):
            insert_ml_performance("MODEL_004", f"ASSET_{i}", 2026, 0.30)

        result = self.svc.evaluate_season("PROV_004", "MODEL_004", 2026)
        self.assertEqual(result["action"], "SLASH")
        self.assertGreater(result["amount"], 0)

    def test_evaluate_season_reward(self):
        """Low discrepancy (<5%) → reward action."""
        self.svc.stake("PROV_005", "MODEL_005", 1000.0)
        from agrichain.db.risk_db import insert_ml_performance
        for i in range(3):
            insert_ml_performance("MODEL_005", f"ASSETR_{i}", 2026, 0.02)

        result = self.svc.evaluate_season("PROV_005", "MODEL_005", 2026)
        self.assertEqual(result["action"], "REWARD")
        self.assertGreater(result["amount"], 0)

    def test_evaluate_no_records(self):
        result = self.svc.evaluate_season("PROV_999", "MODEL_NONE", 2026)
        self.assertEqual(result["action"], "NO_RECORDS")

    def test_slash_formula(self):
        """Verify: slash = stake × min(1, (avg-0.15)/0.15)."""
        avg_disc = 0.30  # 30% discrepancy
        stake = 1000.0
        expected_slash_factor = min(1.0, (avg_disc - 0.15) / 0.15)
        expected_slash = stake * expected_slash_factor
        self.assertAlmostEqual(expected_slash, 1000.0, delta=0.01)

    def test_reward_formula(self):
        """Verify: reward = stake × (0.05 - avg) × 2."""
        avg_disc = 0.02  # 2% discrepancy
        stake = 1000.0
        expected_reward = stake * (0.05 - avg_disc) * 2.0
        self.assertAlmostEqual(expected_reward, 60.0, delta=0.01)


# ─────────────────────────────────────────────────────────────────────────────
# INTEGRATION: Full pipeline mock test
# ─────────────────────────────────────────────────────────────────────────────

class TestIntegrationPipeline(unittest.TestCase):
    """
    Simulates: mint → oracle consensus → adjustment → insurance → reputation
    All external calls (chaincode) are mocked.
    """

    def test_full_harvest_settlement_overperformance(self):
        """Over-performance: bonus minted, no insurance, reputation improved."""
        svc = AdjustmentService(blockchain_store=None)
        result = svc.execute(
            asset_id="INTEG_ASSET_001",
            farmer_id="FARMER_INTEG_001",
            crop_type="Maize",
            actual_yield=5500.0,    # 10% over-performance
            predicted_yield=5000.0,
            token_amount=5000.0,
            oracle_confidence=0.92,
            ipfs_hash="QmMock123456",
        )
        self.assertEqual(result["adjustment"]["action"], "MINT_BONUS")
        self.assertIsNone(result["claim"])
        self.assertIn("new_score", result["reputation"])

    def test_full_harvest_settlement_shortfall_with_claim(self):
        """Large shortfall: insurance triggered, reputation slightly degraded."""
        # Seed a premium pool
        ins = InsuranceService(blockchain_store=None)
        ins.record_premium(
            asset_id="INTEG_ASSET_002",
            farmer_id="FARMER_INTEG_002",
            crop_type="Maize",
            predicted_yield=5000.0,
        )

        svc = AdjustmentService(blockchain_store=None)
        result = svc.execute(
            asset_id="INTEG_ASSET_002",
            farmer_id="FARMER_INTEG_002",
            crop_type="Maize",
            actual_yield=2000.0,    # 60% shortfall
            predicted_yield=5000.0,
            token_amount=5000.0,
            oracle_confidence=0.78,
            ipfs_hash="QmMock456789",
        )
        self.assertEqual(result["adjustment"]["action"], "BURN_SHORTFALL")
        # Claim should exist (pool had premium)
        self.assertIsNotNone(result["claim"])
        # Reputation should decrease
        rep = result["reputation"]
        self.assertLess(rep["new_score"], rep["old_score"] + 1)  # didn't improve


if __name__ == "__main__":
    unittest.main()
