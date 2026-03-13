"""
Test suite for the Independent Verifier subsystem.
Run with:  python -m pytest tests/test_verifier.py -v --tb=short
"""
from __future__ import annotations

import os
import tempfile
import unittest

# Use a temporary database file so tests don't pollute production data
# (SQLite :memory: creates a new DB per connect() call, which doesn't work)
_test_db = os.path.join(tempfile.gettempdir(), "agrichain_test_verifier.db")
os.environ["AGRICHAIN_DB_PATH"] = _test_db

from agrichain.db.risk_db import init_risk_tables, connect
from agrichain.services.verifier_service import VerifierService

# Ensure tables exist before any tests
init_risk_tables()


class TestVerifierRegistration(unittest.TestCase):
    def setUp(self):
        self.svc = VerifierService()
        # Clean tables before each test
        with connect() as conn:
            conn.execute("DELETE FROM verifier_rewards")
            conn.execute("DELETE FROM verifier_stakes")
            conn.execute("DELETE FROM verifier_oracle_submissions")
            conn.execute("DELETE FROM verifier_consensus_reports")
            conn.execute("DELETE FROM verifiers")

    def test_register_creates_verifier(self):
        """Registration should insert a verifier row and return it."""
        result = self.svc.register(
            user_id="user-001",
            organization_name="Kenya Agri Board",
            organization_type="GOVERNMENT",
        )
        self.assertEqual(result["user_id"], "user-001")
        self.assertEqual(result["organization_name"], "Kenya Agri Board")
        self.assertEqual(result["organization_type"], "GOVERNMENT")
        self.assertEqual(result["reputation_score"], 500)
        self.assertEqual(result["total_submissions"], 0)
        self.assertTrue(result["is_active"])

    def test_register_idempotent(self):
        """Re-registering the same user_id returns existing profile without error."""
        v1 = self.svc.register(user_id="user-002", organization_name="Org A")
        v2 = self.svc.register(user_id="user-002", organization_name="Org B")
        self.assertEqual(v1["id"], v2["id"])  # Same verifier


class TestSubmitReport(unittest.TestCase):
    def setUp(self):
        self.svc = VerifierService()
        with connect() as conn:
            conn.execute("DELETE FROM verifier_rewards")
            conn.execute("DELETE FROM verifier_stakes")
            conn.execute("DELETE FROM verifier_oracle_submissions")
            conn.execute("DELETE FROM verifier_consensus_reports")
            conn.execute("DELETE FROM verifiers")
        self.verifier = self.svc.register(
            user_id="v-010",
            organization_name="Test Inspector",
            organization_type="INSPECTOR",
        )

    def test_submit_stores_submission(self):
        """Submitting a report should store it and return the submission."""
        result = self.svc.submit_report(
            verifier_id=self.verifier["id"],
            asset_id="ASSET_001",
            submitted_yield=4200.0,
            confidence=0.85,
            data_source="INSPECTOR",
            measurement_method="Direct Weighing",
        )
        sub = result["submission"]
        self.assertEqual(sub["asset_id"], "ASSET_001")
        self.assertAlmostEqual(sub["submitted_yield"], 4200.0)
        self.assertEqual(sub["status"], "PENDING")
        self.assertFalse(result["consensus_formed"])

    def test_submit_increments_counter(self):
        """Each submission should increment the verifier's total_submissions."""
        self.svc.submit_report(
            verifier_id=self.verifier["id"],
            asset_id="ASSET_002",
            submitted_yield=3900.0,
        )
        updated = self.svc.get_profile(self.verifier["id"])
        self.assertEqual(updated["total_submissions"], 1)

    def test_submit_awards_reward(self):
        """Each submission should earn a SUBMISSION_FEE reward."""
        self.svc.submit_report(
            verifier_id=self.verifier["id"],
            asset_id="ASSET_003",
            submitted_yield=4000.0,
        )
        rewards = self.svc.get_rewards(self.verifier["id"])
        self.assertEqual(len(rewards), 1)
        self.assertEqual(rewards[0]["reason"], "SUBMISSION_FEE")
        self.assertAlmostEqual(rewards[0]["amount"], 5.0)


class TestConsensusFormation(unittest.TestCase):
    def setUp(self):
        self.svc = VerifierService()
        with connect() as conn:
            conn.execute("DELETE FROM verifier_rewards")
            conn.execute("DELETE FROM verifier_stakes")
            conn.execute("DELETE FROM verifier_oracle_submissions")
            conn.execute("DELETE FROM verifier_consensus_reports")
            conn.execute("DELETE FROM verifiers")

        # Register 3 verifiers
        self.v1 = self.svc.register(user_id="v1", organization_name="Gov Agency")
        self.v2 = self.svc.register(user_id="v2", organization_name="University Lab")
        self.v3 = self.svc.register(user_id="v3", organization_name="Satellite Co")

    def test_consensus_forms_with_three_submissions(self):
        """When 3 verifiers submit for the same asset, consensus should form."""
        self.svc.submit_report(self.v1["id"], "ASSET_C1", 4200.0)
        self.svc.submit_report(self.v2["id"], "ASSET_C1", 4300.0)
        result = self.svc.submit_report(self.v3["id"], "ASSET_C1", 4250.0)

        self.assertTrue(result["consensus_formed"])
        self.assertIsNotNone(result["consensus"])
        consensus = result["consensus"]
        # Weighted median should be close to the middle value
        self.assertGreater(consensus["consensus_yield"], 4100)
        self.assertLess(consensus["consensus_yield"], 4400)
        self.assertGreater(consensus["confidence"], 0.5)
        self.assertEqual(consensus["submission_count"], 3)

    def test_no_consensus_with_two_submissions(self):
        """Fewer than 3 submissions should not form consensus."""
        self.svc.submit_report(self.v1["id"], "ASSET_C2", 4200.0)
        result = self.svc.submit_report(self.v2["id"], "ASSET_C2", 4300.0)

        self.assertFalse(result["consensus_formed"])
        self.assertIsNone(result["consensus"])

    def test_consensus_marks_submissions_accepted(self):
        """After consensus, all submissions should be marked ACCEPTED."""
        self.svc.submit_report(self.v1["id"], "ASSET_C3", 5000.0)
        self.svc.submit_report(self.v2["id"], "ASSET_C3", 5100.0)
        self.svc.submit_report(self.v3["id"], "ASSET_C3", 5050.0)

        subs = self.svc.get_my_submissions(self.v1["id"])
        asset_subs = [s for s in subs if s["asset_id"] == "ASSET_C3"]
        self.assertTrue(all(s["status"] == "ACCEPTED" for s in asset_subs))


class TestStaking(unittest.TestCase):
    def setUp(self):
        self.svc = VerifierService()
        with connect() as conn:
            conn.execute("DELETE FROM verifier_rewards")
            conn.execute("DELETE FROM verifier_stakes")
            conn.execute("DELETE FROM verifier_oracle_submissions")
            conn.execute("DELETE FROM verifier_consensus_reports")
            conn.execute("DELETE FROM verifiers")
        self.verifier = self.svc.register(user_id="staker-1", organization_name="Stake Corp")

    def test_stake_records_and_updates_profile(self):
        """Staking tokens should be recorded and reflected on the profile."""
        result = self.svc.stake_tokens(self.verifier["id"], 1000.0, lock_days=30)
        self.assertEqual(result["amount"], 1000.0)
        self.assertIn("lock_until", result)

        profile = self.svc.get_profile(self.verifier["id"])
        self.assertAlmostEqual(profile["stake_amount"], 1000.0)

    def test_multiple_stakes_accumulate(self):
        """Multiple stakes should sum on the profile."""
        self.svc.stake_tokens(self.verifier["id"], 500.0)
        self.svc.stake_tokens(self.verifier["id"], 300.0)
        profile = self.svc.get_profile(self.verifier["id"])
        self.assertAlmostEqual(profile["stake_amount"], 800.0)

    def test_negative_stake_raises(self):
        """Negative stake amounts should raise ValueError."""
        with self.assertRaises(ValueError):
            self.svc.stake_tokens(self.verifier["id"], -100.0)


class TestDashboardStats(unittest.TestCase):
    def setUp(self):
        self.svc = VerifierService()
        with connect() as conn:
            conn.execute("DELETE FROM verifier_rewards")
            conn.execute("DELETE FROM verifier_stakes")
            conn.execute("DELETE FROM verifier_oracle_submissions")
            conn.execute("DELETE FROM verifier_consensus_reports")
            conn.execute("DELETE FROM verifiers")
        self.verifier = self.svc.register(user_id="dash-1", organization_name="Dashboard Org")

    def test_dashboard_returns_all_fields(self):
        """Dashboard stats should include all expected keys."""
        stats = self.svc.dashboard_stats(self.verifier["id"])
        expected_keys = {
            "totalSubmissions", "accuracyRate", "stakeAmount",
            "reputationScore", "rewardsEarned", "pendingAssetsCount", "isActive",
        }
        self.assertTrue(expected_keys.issubset(set(stats.keys())))

    def test_dashboard_reflects_submissions(self):
        """Dashboard should pick up new submissions."""
        self.svc.submit_report(self.verifier["id"], "ASSET_D1", 3000.0)
        stats = self.svc.dashboard_stats(self.verifier["id"])
        self.assertEqual(stats["totalSubmissions"], 1)
        self.assertGreater(stats["rewardsEarned"], 0)

    def test_dashboard_nonexistent_returns_empty(self):
        """Non-existent verifier_id should return empty dict."""
        stats = self.svc.dashboard_stats(9999)
        self.assertEqual(stats, {})


class TestRewards(unittest.TestCase):
    def setUp(self):
        self.svc = VerifierService()
        with connect() as conn:
            conn.execute("DELETE FROM verifier_rewards")
            conn.execute("DELETE FROM verifier_stakes")
            conn.execute("DELETE FROM verifier_oracle_submissions")
            conn.execute("DELETE FROM verifier_consensus_reports")
            conn.execute("DELETE FROM verifiers")
        self.verifier = self.svc.register(user_id="rew-1", organization_name="Reward Org")

    def test_total_rewards_sums_correctly(self):
        """Total rewards should sum all individual reward entries."""
        from agrichain.db.risk_db import insert_verifier_reward
        insert_verifier_reward(self.verifier["id"], 10.0, "SUBMISSION_FEE")
        insert_verifier_reward(self.verifier["id"], 15.0, "ACCURACY_BONUS")
        insert_verifier_reward(self.verifier["id"], 5.0, "SUBMISSION_FEE")

        total = self.svc.get_total_rewards(self.verifier["id"])
        self.assertAlmostEqual(total, 30.0)


if __name__ == "__main__":
    unittest.main()
