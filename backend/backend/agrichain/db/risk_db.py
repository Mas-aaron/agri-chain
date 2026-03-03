"""
Database migrations for the AgriYield 5-Layer Risk Management System.
Run this module directly to apply all migrations to the SQLite database (init_risk_tables).
Called automatically from init_db() in sqlite.py.
"""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from typing import Optional
from pathlib import Path
import os

_BASE_DIR = Path(__file__).resolve().parent.parent
_DB_PATH = Path(os.getenv("AGRICHAIN_DB_PATH", str(_BASE_DIR / "agrichain.db")))


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(str(_DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_risk_tables() -> None:
    """Create all risk management tables (idempotent)."""
    with connect() as conn:
        # ── Layer 1: Oracle Reports ──────────────────────────────
        conn.execute("""
            CREATE TABLE IF NOT EXISTS oracle_reports (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                asset_id    TEXT    NOT NULL,
                consensus_yield REAL NOT NULL,
                confidence  REAL    NOT NULL,
                ipfs_hash   TEXT    NOT NULL,
                sources     TEXT    NOT NULL,  -- JSON array of {source, value, weight}
                status      TEXT    NOT NULL DEFAULT 'PENDING',
                created_at  TEXT    NOT NULL,
                reviewed_by_admin INTEGER DEFAULT 0,
                admin_notes TEXT
            )
        """)
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_oracle_asset ON oracle_reports (asset_id)"
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_oracle_status ON oracle_reports (status)"
        )

        # ── Layer 2: Insurance Premiums ──────────────────────────
        conn.execute("""
            CREATE TABLE IF NOT EXISTS insurance_premiums (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                asset_id        TEXT    NOT NULL,
                farmer_id       TEXT    NOT NULL,
                crop_type       TEXT    NOT NULL,
                premium_amount  REAL    NOT NULL,
                base_rate       REAL    NOT NULL DEFAULT 0.02,
                rep_discount    REAL    NOT NULL DEFAULT 0.0,
                vol_surcharge   REAL    NOT NULL DEFAULT 0.0,
                paid_at         TEXT    NOT NULL
            )
        """)
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_prem_asset ON insurance_premiums (asset_id)"
        )

        # ── Layer 2: Insurance Claims ────────────────────────────
        conn.execute("""
            CREATE TABLE IF NOT EXISTS insurance_claims (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                asset_id        TEXT    NOT NULL,
                shortfall_pct   REAL    NOT NULL,
                payout_amount   REAL    NOT NULL,
                status          TEXT    NOT NULL DEFAULT 'PENDING',
                processed_at    TEXT
            )
        """)
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_claim_asset ON insurance_claims (asset_id)"
        )

        # ── Layer 5: Farmer Reputation ──────────────────────────
        conn.execute("""
            CREATE TABLE IF NOT EXISTS farmer_reputation (
                farmer_id       TEXT PRIMARY KEY,
                score           REAL    NOT NULL DEFAULT 500.0,
                tier            TEXT    NOT NULL DEFAULT 'New',
                total_harvests  INTEGER NOT NULL DEFAULT 0,
                updated_at      TEXT    NOT NULL
            )
        """)

        # ── Layer 4: ML Model Stakes ─────────────────────────────
        conn.execute("""
            CREATE TABLE IF NOT EXISTS ml_model_stakes (
                provider_id     TEXT    NOT NULL,
                model_id        TEXT    NOT NULL,
                stake_amount    REAL    NOT NULL DEFAULT 0.0,
                total_slashed   REAL    NOT NULL DEFAULT 0.0,
                total_rewarded  REAL    NOT NULL DEFAULT 0.0,
                locked_until    TEXT,
                created_at      TEXT    NOT NULL,
                updated_at      TEXT    NOT NULL,
                PRIMARY KEY (provider_id, model_id)
            )
        """)

        # ── Layer 4: ML Model Performance History ───────────────
        conn.execute("""
            CREATE TABLE IF NOT EXISTS ml_model_performance (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                model_id        TEXT    NOT NULL,
                asset_id        TEXT    NOT NULL,
                season          INTEGER NOT NULL,
                discrepancy_pct REAL    NOT NULL,  -- |actual-predicted|/predicted
                recorded_at     TEXT    NOT NULL
            )
        """)
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_perf_model ON ml_model_performance (model_id, season)"
        )

        # ── Layer 3: Token Adjustment Events ────────────────────
        conn.execute("""
            CREATE TABLE IF NOT EXISTS token_adjustment_events (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                asset_id        TEXT    NOT NULL,
                action          TEXT    NOT NULL,  -- MINT_BONUS | BURN_PARTIAL | BURN_SHORTFALL
                adjustment_factor REAL  NOT NULL,
                tokens_delta    REAL    NOT NULL,
                oracle_confidence REAL  NOT NULL,
                ipfs_hash       TEXT    NOT NULL,
                triggered_at    TEXT    NOT NULL
            )
        """)
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_adj_asset ON token_adjustment_events (asset_id)"
        )


def get_farmer_reputation(farmer_id: str) -> Optional[dict]:
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM farmer_reputation WHERE farmer_id=?", (farmer_id,)
        ).fetchone()
    return dict(row) if row else None


def upsert_farmer_reputation(
    farmer_id: str, score: float, tier: str, total_harvests: int
) -> None:
    now = datetime.now(timezone.utc).isoformat()
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO farmer_reputation (farmer_id, score, tier, total_harvests, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(farmer_id) DO UPDATE SET
                score=excluded.score,
                tier=excluded.tier,
                total_harvests=excluded.total_harvests,
                updated_at=excluded.updated_at
            """,
            (farmer_id, score, tier, total_harvests, now),
        )


def insert_oracle_report(
    asset_id: str,
    consensus_yield: float,
    confidence: float,
    ipfs_hash: str,
    sources: list,
    status: str = "PENDING",
) -> int:
    now = datetime.now(timezone.utc).isoformat()
    with connect() as conn:
        cur = conn.execute(
            """
            INSERT INTO oracle_reports
            (asset_id, consensus_yield, confidence, ipfs_hash, sources, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (asset_id, consensus_yield, confidence, ipfs_hash,
             json.dumps(sources), status, now),
        )
        return cur.lastrowid


def insert_insurance_premium(
    asset_id: str,
    farmer_id: str,
    crop_type: str,
    premium_amount: float,
    base_rate: float,
    rep_discount: float,
    vol_surcharge: float,
) -> int:
    now = datetime.now(timezone.utc).isoformat()
    with connect() as conn:
        cur = conn.execute(
            """
            INSERT INTO insurance_premiums
            (asset_id, farmer_id, crop_type, premium_amount, base_rate, rep_discount, vol_surcharge, paid_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (asset_id, farmer_id, crop_type, premium_amount,
             base_rate, rep_discount, vol_surcharge, now),
        )
        return cur.lastrowid


def insert_insurance_claim(
    asset_id: str, shortfall_pct: float, payout_amount: float
) -> int:
    with connect() as conn:
        cur = conn.execute(
            """
            INSERT INTO insurance_claims (asset_id, shortfall_pct, payout_amount, status)
            VALUES (?, ?, ?, 'PENDING')
            """,
            (asset_id, shortfall_pct, payout_amount),
        )
        return cur.lastrowid


def update_claim_status(claim_id: int, status: str) -> None:
    now = datetime.now(timezone.utc).isoformat()
    with connect() as conn:
        conn.execute(
            "UPDATE insurance_claims SET status=?, processed_at=? WHERE id=?",
            (status, now, claim_id),
        )


def insert_adjustment_event(
    asset_id: str,
    action: str,
    adjustment_factor: float,
    tokens_delta: float,
    oracle_confidence: float,
    ipfs_hash: str,
) -> int:
    now = datetime.now(timezone.utc).isoformat()
    with connect() as conn:
        cur = conn.execute(
            """
            INSERT INTO token_adjustment_events
            (asset_id, action, adjustment_factor, tokens_delta, oracle_confidence, ipfs_hash, triggered_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (asset_id, action, adjustment_factor, tokens_delta,
             oracle_confidence, ipfs_hash, now),
        )
        return cur.lastrowid


def upsert_ml_stake(
    provider_id: str,
    model_id: str,
    stake_amount: float,
    total_slashed: float,
    total_rewarded: float,
    locked_until: Optional[str],
) -> None:
    now = datetime.now(timezone.utc).isoformat()
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO ml_model_stakes
            (provider_id, model_id, stake_amount, total_slashed, total_rewarded, locked_until, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(provider_id, model_id) DO UPDATE SET
                stake_amount=excluded.stake_amount,
                total_slashed=excluded.total_slashed,
                total_rewarded=excluded.total_rewarded,
                locked_until=excluded.locked_until,
                updated_at=excluded.updated_at
            """,
            (provider_id, model_id, stake_amount, total_slashed,
             total_rewarded, locked_until, now, now),
        )


def get_ml_stake(provider_id: str, model_id: str) -> Optional[dict]:
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM ml_model_stakes WHERE provider_id=? AND model_id=?",
            (provider_id, model_id),
        ).fetchone()
    return dict(row) if row else None


def insert_ml_performance(
    model_id: str, asset_id: str, season: int, discrepancy_pct: float
) -> int:
    now = datetime.now(timezone.utc).isoformat()
    with connect() as conn:
        cur = conn.execute(
            """
            INSERT INTO ml_model_performance (model_id, asset_id, season, discrepancy_pct, recorded_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (model_id, asset_id, season, discrepancy_pct, now),
        )
        return cur.lastrowid


def get_model_season_performance(model_id: str, season: int) -> list:
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM ml_model_performance WHERE model_id=? AND season=?",
            (model_id, season),
        ).fetchall()
    return [dict(r) for r in rows]
