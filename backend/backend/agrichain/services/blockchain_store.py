"""
Hybrid Blockchain Store — tries real BCS via gRPC, falls back to mock.
Now persists to SQLite so data survives restarts.
"""
from __future__ import annotations

import json
import logging
import os
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# ── DB path ───────────────────────────────────────────────────
_BASE_DIR = Path(__file__).resolve().parent.parent
_DB_PATH = Path(os.getenv("AGRICHAIN_DB_PATH", str(_BASE_DIR / "agrichain.db")))


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(str(_DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def _init_assets_table() -> None:
    with _connect() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS blockchain_assets (
                asset_id TEXT PRIMARY KEY,
                token_id TEXT NOT NULL,
                farmer_id TEXT NOT NULL,
                crop_type TEXT NOT NULL,
                season INTEGER NOT NULL,
                predicted_yield REAL NOT NULL,
                confidence REAL NOT NULL,
                token_amount REAL NOT NULL,
                token_symbol TEXT,
                token_standard TEXT DEFAULT 'ERC-1155',
                current_value REAL NOT NULL,
                status TEXT NOT NULL DEFAULT 'PREDICTED',
                collateralized INTEGER DEFAULT 0,
                source TEXT DEFAULT 'mock',
                tx_status TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                extra_json TEXT DEFAULT '{}'
            )
        """)


_init_assets_table()


# ── Configuration ─────────────────────────────────────────────
def _env(key: str, default: str = "") -> str:
    return os.getenv(key, default).strip()


FABRIC_MODE = _env("FABRIC_MODE", "mock")
PEER_ENDPOINT = _env("FABRIC_PEER_ENDPOINT", "176.52.136.255:30605")
MSP_ID = _env("FABRIC_MSP_ID", "4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8MSP")
TLS_CERT_PATH = _env("FABRIC_TLS_CERT_PATH")
CERT_PATH = _env("FABRIC_CERT_PATH")
KEY_PATH = _env("FABRIC_KEY_PATH")
CHANNEL = _env("FABRIC_CHANNEL", "yieldchannel")
CHAINCODE = _env("FABRIC_CHAINCODE", "agriyeild")
PEER_HOSTNAME = _env(
    "FABRIC_PEER_HOSTNAME",
    "peer-4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8-0."
    "peer-4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.default.svc.cluster.local",
)


def _is_fabric_configured() -> bool:
    if FABRIC_MODE not in ("gateway", "fabric", "real"):
        return False
    if not PEER_ENDPOINT or not MSP_ID:
        return False
    for p in (TLS_CERT_PATH, CERT_PATH, KEY_PATH):
        if not p or not Path(p).exists():
            return False
    return True


# ── Real Fabric Client (lazy init) ───────────────────────────
_fabric_client = None


def _get_fabric_client():
    """Lazily initialize the real Fabric gRPC client."""
    global _fabric_client
    if _fabric_client is not None:
        return _fabric_client

    if not _is_fabric_configured():
        return None

    try:
        from agrichain.services.fabric_client import FabricGrpcClient, PROTOS_AVAILABLE
        if not PROTOS_AVAILABLE:
            logger.warning("Proto stubs not available — using mock")
            return None

        _fabric_client = FabricGrpcClient(
            peer_endpoint=PEER_ENDPOINT,
            peer_hostname=PEER_HOSTNAME,
            tls_cert_path=TLS_CERT_PATH,
            cert_path=CERT_PATH,
            key_path=KEY_PATH,
            msp_id=MSP_ID,
            channel=CHANNEL,
            chaincode=CHAINCODE,
        )
        _fabric_client.connect()
        logger.info("✅ Connected to real Fabric peer via gRPC!")
        return _fabric_client
    except Exception as e:
        logger.error(f"Failed to connect to Fabric: {e}")
        return None


# ── Helper: row → dict ───────────────────────────────────────
def _row_to_dict(row: sqlite3.Row) -> Dict[str, Any]:
    return {
        "assetId": row["asset_id"],
        "tokenId": row["token_id"],
        "farmerId": row["farmer_id"],
        "cropType": row["crop_type"],
        "season": row["season"],
        "predictedYield": row["predicted_yield"],
        "confidence": row["confidence"],
        "tokenAmount": row["token_amount"],
        "tokenSymbol": row["token_symbol"] or "",
        "tokenStandard": row["token_standard"] or "ERC-1155",
        "currentValue": row["current_value"],
        "status": row["status"],
        "collateralized": bool(row["collateralized"]),
        "source": row["source"],
        "txStatus": row["tx_status"],
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }


# ── Hybrid Store ──────────────────────────────────────────────
class HybridBlockchainStore:
    """
    Stores tokenized assets in SQLite. Tries real BCS chaincode first,
    falls back to local-only storage.
    """

    def __init__(self):
        self._fabric_available = False
        logger.info(f"HybridBlockchainStore initialized (mode={FABRIC_MODE}, db={_DB_PATH})")

    def _try_fabric_query(self, function: str, args: List[str] = None) -> Optional[Any]:
        client = _get_fabric_client()
        if client is None:
            return None
        try:
            result = client.query(function, args or [])
            self._fabric_available = True
            return result
        except Exception as e:
            logger.warning(f"Fabric query {function} failed: {e}")
            return None

    def _try_fabric_invoke(self, function: str, args: List[str] = None) -> Optional[Dict]:
        client = _get_fabric_client()
        if client is None:
            return None
        try:
            result = client.invoke(function, args or [])
            self._fabric_available = True
            return result
        except Exception as e:
            logger.warning(f"Fabric invoke {function} failed: {e}")
            return None

    def create_asset(
        self,
        asset_id: str,
        token_id: str,
        farmer_id: str,
        crop_type: str,
        season: int,
        predicted_yield: float,
        confidence: float,
        token_amount: float,
        current_value: float,
        status: str = "PREDICTED",
        **kwargs,
    ) -> Dict[str, Any]:
        """Create a tokenized yield asset — persisted to SQLite."""
        now = datetime.now(timezone.utc).isoformat()
        source = "mock"
        tx_status = None

        # Try real blockchain
        fabric_result = self._try_fabric_invoke("CreateYieldAsset", [
            asset_id,
            farmer_id,
            f"did:agri:farmer:{farmer_id}",
            f"farm_{farmer_id}",
            "",
            crop_type,
            str(season),
            str(predicted_yield),
            str(confidence),
            "v2.1.0",
            "",
            "",
            "",
        ])

        if fabric_result is not None:
            source = "blockchain"
            tx_status = fabric_result.get("status", "endorsed")
            logger.info(f"✅ Asset {asset_id} written to REAL blockchain!")
        else:
            logger.info(f"Asset {asset_id} stored locally (Fabric unavailable)")

        token_symbol = f"AYW-{season}-{crop_type.upper()[:3]}"

        with _connect() as conn:
            conn.execute("""
                INSERT OR REPLACE INTO blockchain_assets 
                (asset_id, token_id, farmer_id, crop_type, season,
                 predicted_yield, confidence, token_amount, token_symbol,
                 token_standard, current_value, status, collateralized,
                 source, tx_status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                asset_id, token_id, farmer_id, crop_type, season,
                predicted_yield, confidence, token_amount, token_symbol,
                "ERC-1155", current_value, status, 0,
                source, tx_status, now, now,
            ))

        return {
            "assetId": asset_id,
            "tokenId": token_id,
            "farmerId": farmer_id,
            "cropType": crop_type,
            "season": season,
            "predictedYield": predicted_yield,
            "confidence": confidence,
            "tokenAmount": token_amount,
            "tokenSymbol": token_symbol,
            "tokenStandard": "ERC-1155",
            "currentValue": current_value,
            "status": status,
            "collateralized": False,
            "source": source,
            "txStatus": tx_status,
            "createdAt": now,
            "updatedAt": now,
        }

    def get_asset(self, asset_id: str) -> Optional[Dict]:
        with _connect() as conn:
            row = conn.execute("SELECT * FROM blockchain_assets WHERE asset_id=?", (asset_id,)).fetchone()
        if row:
            return _row_to_dict(row)
        return None

    def list_assets(self, farmer_id: Optional[str] = None) -> List[Dict]:
        with _connect() as conn:
            if farmer_id:
                rows = conn.execute(
                    "SELECT * FROM blockchain_assets WHERE farmer_id=? ORDER BY created_at DESC",
                    (farmer_id,)
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT * FROM blockchain_assets ORDER BY created_at DESC"
                ).fetchall()
        return [_row_to_dict(r) for r in rows]

    def update_asset(self, asset_id: str, updates: Dict) -> Optional[Dict]:
        existing = self.get_asset(asset_id)
        if existing is None:
            return None
        now = datetime.now(timezone.utc).isoformat()
        # Map camelCase keys to snake_case columns
        col_map = {
            "status": "status", "currentValue": "current_value",
            "tokenAmount": "token_amount", "collateralized": "collateralized",
        }
        with _connect() as conn:
            for key, val in updates.items():
                col = col_map.get(key)
                if col:
                    conn.execute(f"UPDATE blockchain_assets SET {col}=?, updated_at=? WHERE asset_id=?",
                                 (val, now, asset_id))
        return self.get_asset(asset_id)

    def delete_asset(self, asset_id: str) -> bool:
        with _connect() as conn:
            cursor = conn.execute("DELETE FROM blockchain_assets WHERE asset_id=?", (asset_id,))
        return cursor.rowcount > 0

    def get_farmer_assets(self, farmer_id: str) -> List[Dict]:
        return self.list_assets(farmer_id=farmer_id)

    def create_trade(self, seller_id: str, buyer_id: str, asset_id: str,
                     token_amount: float, price_per_token: float) -> Dict:
        trade_id = f"TRADE_{uuid.uuid4().hex[:8].upper()}"
        trade = {
            "tradeId": trade_id,
            "sellerId": seller_id,
            "buyerId": buyer_id,
            "assetId": asset_id,
            "tokenAmount": token_amount,
            "pricePerToken": price_per_token,
            "totalPrice": token_amount * price_per_token,
            "status": "COMPLETED",
            "createdAt": datetime.now(timezone.utc).isoformat(),
        }
        return trade

    def list_trades(self) -> List[Dict]:
        return []

    def get_market_data(self, crop_type: str) -> Dict:
        assets = [a for a in self.list_assets() if a.get("cropType", "").lower() == crop_type.lower()]
        total_tokens = sum(a.get("tokenAmount", 0) for a in assets)
        total_value = sum(a.get("currentValue", 0) for a in assets)
        return {
            "cropType": crop_type,
            "totalAssets": len(assets),
            "totalTokens": total_tokens,
            "totalValue": total_value,
            "averageYield": (sum(a.get("predictedYield", 0) for a in assets) / len(assets)) if assets else 0,
            "pricePerToken": 5.0,
            "fabricConnected": self._fabric_available,
        }


# Singleton
STORE = HybridBlockchainStore()
