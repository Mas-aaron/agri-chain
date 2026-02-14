from __future__ import annotations

import json
import sqlite3
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional

from agrichain.core.config import DB_PATH


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS contracts (
                id TEXT PRIMARY KEY,
                crop TEXT NOT NULL,
                quantity_kg REAL NOT NULL,
                unit_price REAL NOT NULL,
                currency TEXT NOT NULL,
                status TEXT NOT NULL,
                farmer_name TEXT NOT NULL,
                buyer_name TEXT,
                evidence_hash TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS ledger_events (
                id TEXT PRIMARY KEY,
                time TEXT NOT NULL,
                action TEXT NOT NULL,
                actor TEXT NOT NULL,
                contract_id TEXT NOT NULL,
                meta_json TEXT NOT NULL
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ledger_contract_id ON ledger_events (contract_id)")


def insert_ledger_event(
    conn: sqlite3.Connection,
    *,
    action: str,
    actor: str,
    contract_id: str,
    meta: Dict[str, str],
) -> str:
    event_id = f"L-{uuid.uuid4().hex[:12]}"
    conn.execute(
        "INSERT INTO ledger_events (id, time, action, actor, contract_id, meta_json) VALUES (?, ?, ?, ?, ?, ?)",
        (event_id, utc_now_iso(), action, actor, contract_id, json.dumps(meta, ensure_ascii=False)),
    )
    return event_id


def fetch_ledger(
    *,
    contract_id: Optional[str] = None,
    limit: int = 100,
) -> List[sqlite3.Row]:
    init_db()
    limit = max(1, min(int(limit), 500))

    with connect() as conn:
        if contract_id:
            return conn.execute(
                "SELECT * FROM ledger_events WHERE contract_id=? ORDER BY time DESC LIMIT ?",
                (contract_id, limit),
            ).fetchall()

        return conn.execute(
            "SELECT * FROM ledger_events ORDER BY time DESC LIMIT ?",
            (limit,),
        ).fetchall()
