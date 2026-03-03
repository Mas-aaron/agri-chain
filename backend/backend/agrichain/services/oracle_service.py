"""
Layer 1 — Multi‑Oracle Consensus Service.

Simulates querying 4 independent external data sources and computing a
weighted median to determine actual yield. Stores results in the DB
and optionally calls the BCS chaincode to settle the asset.
"""
from __future__ import annotations

import hashlib
import json
import logging
import random
import statistics
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from agrichain.db.risk_db import insert_oracle_report, connect as _rdb_connect

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# ORACLE SOURCE CLIENTS
# ─────────────────────────────────────────────────────────────────────────────

class OracleSourceClient(ABC):
    """Abstract base for any external yield-data source."""

    name: str
    weight: float  # 0–1, contribution weight in consensus

    @abstractmethod
    def fetch_yield(self, asset_id: str, crop_type: str, geo_hash: str) -> Optional[float]:
        """Return yield in kg or None if data unavailable."""
        ...


class GovernmentAPIClient(OracleSourceClient):
    """
    Simulates the national agricultural department's harvest API.
    High weight: authoritative low-noise source.
    """
    name = "government_api"
    weight = 0.35

    def fetch_yield(self, asset_id: str, crop_type: str, geo_hash: str) -> Optional[float]:
        # In production: call real HTTP endpoint with API key from env.
        # Returns None ~10% of the time to simulate downtime.
        if random.random() < 0.10:
            logger.warning("GovernmentAPIClient: simulated downtime")
            return None
        # Simulate ±8% noise around a base estimate seeded by asset_id
        base = _seed_estimate(asset_id, 4500.0)
        noise_factor = 1 + random.gauss(0, 0.04)  # σ=4%
        return max(0, base * noise_factor)


class UniversityResearchClient(OracleSourceClient):
    """
    Simulates a university's remote-sensing yield model API.
    Medium weight: useful independent cross-check.
    """
    name = "university_research"
    weight = 0.25

    def fetch_yield(self, asset_id: str, crop_type: str, geo_hash: str) -> Optional[float]:
        if random.random() < 0.15:
            logger.warning("UniversityResearchClient: simulated downtime")
            return None
        base = _seed_estimate(asset_id, 4500.0)
        noise_factor = 1 + random.gauss(0, 0.07)
        return max(0, base * noise_factor)


class SatelliteImageryClient(OracleSourceClient):
    """
    Simulates an agri-tech satellite NDVI→yield model.
    Medium weight: objective but model-dependent.
    """
    name = "satellite_imagery"
    weight = 0.25

    def fetch_yield(self, asset_id: str, crop_type: str, geo_hash: str) -> Optional[float]:
        if random.random() < 0.20:
            logger.warning("SatelliteImageryClient: simulated downtime")
            return None
        base = _seed_estimate(asset_id, 4500.0)
        noise_factor = 1 + random.gauss(0, 0.10)
        return max(0, base * noise_factor)


class LocalInspectorClient(OracleSourceClient):
    """
    Simulates a network of on-the-ground crop inspectors.
    Lower weight: subjective human assessment.
    """
    name = "local_inspector"
    weight = 0.15

    def fetch_yield(self, asset_id: str, crop_type: str, geo_hash: str) -> Optional[float]:
        if random.random() < 0.25:
            logger.warning("LocalInspectorClient: simulated downtime (inspector unavailable)")
            return None
        base = _seed_estimate(asset_id, 4500.0)
        noise_factor = 1 + random.gauss(0, 0.12)
        return max(0, base * noise_factor)


def _seed_estimate(asset_id: str, base: float) -> float:
    """Derive a deterministic per-asset base yield from the asset ID hash."""
    h = int(hashlib.md5(asset_id.encode()).hexdigest()[:8], 16)
    pct = (h % 4000 - 2000) / 20000.0  # ±10% range
    return base * (1 + pct)


# ─────────────────────────────────────────────────────────────────────────────
# CONSENSUS ENGINE
# ─────────────────────────────────────────────────────────────────────────────

class ConsensusEngine:
    """
    Computes a weighted median and confidence score from multiple oracle reports.
    """

    # Minimum sources required before confidence is trusted
    MIN_SOURCES = 3
    CONFIDENCE_THRESHOLD = 0.60

    @staticmethod
    def weighted_median(values_weights: List[Tuple[float, float]]) -> float:
        """
        Compute the weighted median.
        values_weights: list of (value, weight) tuples.
        """
        if not values_weights:
            raise ValueError("No data for weighted median")

        # Sort by value
        sorted_vw = sorted(values_weights, key=lambda x: x[0])
        total_weight = sum(w for _, w in sorted_vw)
        cumulative = 0.0
        half = total_weight / 2.0
        for value, weight in sorted_vw:
            cumulative += weight
            if cumulative >= half:
                return value
        return sorted_vw[-1][0]

    @staticmethod
    def compute_confidence(values: List[float]) -> float:
        """
        Confidence = 1 − (std_dev / mean).
        Returned in [0, 1]. Returns 0 if insufficient data.
        """
        if len(values) < 2:
            return 0.0
        mean = statistics.mean(values)
        if mean == 0:
            return 0.0
        std = statistics.stdev(values)
        # Coefficient of variation penalty
        cv = std / mean
        confidence = max(0.0, 1.0 - cv)
        return round(min(1.0, confidence), 4)

    def run(
        self, submissions: List[Dict[str, Any]]
    ) -> Tuple[float, float, List[Dict]]:
        """
        Run consensus over a list of source submissions.
        Each submission: {"source": str, "value": float, "weight": float}

        Returns:
            (consensus_yield, confidence, filtered_sources_list)
        """
        valid = [s for s in submissions if s.get("value") is not None]

        if len(valid) < self.MIN_SOURCES:
            logger.warning(
                f"Only {len(valid)} sources responded — below minimum {self.MIN_SOURCES}. "
                "Confidence set to 0; manual review required."
            )
            if valid:
                # Best-effort median with zero confidence
                vw = [(s["value"], s["weight"]) for s in valid]
                median = self.weighted_median(vw)
                return median, 0.0, valid
            return 0.0, 0.0, []

        vw = [(s["value"], s["weight"]) for s in valid]
        median = self.weighted_median(vw)
        values = [s["value"] for s in valid]
        confidence = self.compute_confidence(values)

        return median, confidence, valid


# ─────────────────────────────────────────────────────────────────────────────
# IPFS MOCK
# ─────────────────────────────────────────────────────────────────────────────

def mock_ipfs_store(report: dict) -> str:
    """
    In production: pin the JSON report to IPFS and return the CID.
    For now, returns a SHA-256 hash of the serialised report as a stand-in.
    """
    blob = json.dumps(report, sort_keys=True, default=str).encode()
    digest = hashlib.sha256(blob).hexdigest()
    return f"Qm{digest[:44]}"  # Mimics a CIDv0 prefix


# ─────────────────────────────────────────────────────────────────────────────
# ORACLE SERVICE
# ─────────────────────────────────────────────────────────────────────────────

class OracleService:
    """
    Orchestrates multi-source data collection, consensus computation,
    IPFS storage, DB persistence, and chaincode notification.
    """

    SOURCES: List[OracleSourceClient] = [
        GovernmentAPIClient(),
        UniversityResearchClient(),
        SatelliteImageryClient(),
        LocalInspectorClient(),
    ]

    def __init__(self, blockchain_store=None):
        self._store = blockchain_store
        self._engine = ConsensusEngine()

    def run_consensus(
        self,
        asset_id: str,
        crop_type: str = "Maize",
        geo_hash: str = "",
    ) -> Dict[str, Any]:
        """
        Full pipeline:
        1. Query all sources.
        2. Run weighted median consensus.
        3. Store report on mock-IPFS.
        4. Persist to oracle_reports table.
        5. If confidence ≥ threshold → invoke chaincode UpdateActualYield.
        6. Return report summary.
        """
        logger.info(f"Oracle: starting consensus for asset {asset_id}")

        # ── 1. Collect source submissions ────────────────────────
        submissions: List[Dict[str, Any]] = []
        for src in self.SOURCES:
            try:
                value = src.fetch_yield(asset_id, crop_type, geo_hash)
                submissions.append({
                    "source": src.name,
                    "value": value,
                    "weight": src.weight,
                })
                logger.debug(f"  {src.name}: {value}")
            except Exception as exc:
                logger.error(f"Source {src.name} error: {exc}")
                submissions.append({"source": src.name, "value": None, "weight": src.weight})

        # ── 2. Run consensus ─────────────────────────────────────
        consensus_yield, confidence, valid_sources = self._engine.run(submissions)

        # ── 3. Mock-IPFS storage ─────────────────────────────────
        report_data = {
            "asset_id": asset_id,
            "consensus_yield": consensus_yield,
            "confidence": confidence,
            "sources": valid_sources,
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }
        ipfs_hash = mock_ipfs_store(report_data)

        # ── 4. Determine status ───────────────────────────────────
        status = "APPROVED" if (
            confidence >= self._engine.CONFIDENCE_THRESHOLD
            and len(valid_sources) >= self._engine.MIN_SOURCES
        ) else "PENDING_REVIEW"

        # ── 5. Persist to DB ──────────────────────────────────────
        report_id = insert_oracle_report(
            asset_id=asset_id,
            consensus_yield=consensus_yield,
            confidence=confidence,
            ipfs_hash=ipfs_hash,
            sources=valid_sources,
            status=status,
        )

        # ── 6. Auto-invoke chaincode if confidence is high enough ─
        chaincode_result = None
        if status == "APPROVED" and self._store is not None:
            chaincode_result = self._invoke_chaincode_update(
                asset_id, consensus_yield, confidence, ipfs_hash
            )
        elif status == "PENDING_REVIEW":
            logger.warning(
                f"Oracle report {report_id} requires admin review "
                f"(confidence={confidence:.3f}, sources={len(valid_sources)})"
            )

        return {
            "report_id": report_id,
            "asset_id": asset_id,
            "consensus_yield": consensus_yield,
            "confidence": confidence,
            "ipfs_hash": ipfs_hash,
            "status": status,
            "sources": valid_sources,
            "chaincode_invoked": chaincode_result is not None,
        }

    def approve_report(self, report_id: int) -> Optional[Dict[str, Any]]:
        """Admin manually approves a pending report → triggers chaincode."""
        with _rdb_connect() as conn:
            row = conn.execute(
                "SELECT * FROM oracle_reports WHERE id=?", (report_id,)
            ).fetchone()
        if not row:
            return None

        report = dict(row)
        # Trigger chaincode
        result = self._invoke_chaincode_update(
            report["asset_id"],
            report["consensus_yield"],
            report["confidence"],
            report["ipfs_hash"],
        )
        # Mark approved
        with _rdb_connect() as conn:
            conn.execute(
                "UPDATE oracle_reports SET status='APPROVED', reviewed_by_admin=1 WHERE id=?",
                (report_id,),
            )
        return {**report, "chaincode_result": result}

    def reject_report(self, report_id: int, admin_notes: str) -> bool:
        with _rdb_connect() as conn:
            cur = conn.execute(
                "UPDATE oracle_reports SET status='REJECTED', reviewed_by_admin=1, admin_notes=? WHERE id=?",
                (admin_notes, report_id),
            )
        return cur.rowcount > 0

    def _invoke_chaincode_update(
        self,
        asset_id: str,
        consensus_yield: float,
        confidence: float,
        ipfs_hash: str,
    ) -> Optional[Dict]:
        """Call UpdateActualYield on the Fabric chaincode (best-effort)."""
        if self._store is None:
            return None
        try:
            result = self._store._try_fabric_invoke(
                "UpdateActualYield",
                [asset_id, str(consensus_yield), str(confidence), ipfs_hash],
            )
            logger.info(f"Chaincode UpdateActualYield for {asset_id}: {result}")
            return result
        except Exception as exc:
            logger.error(f"Chaincode invoke failed for {asset_id}: {exc}")
            return None
