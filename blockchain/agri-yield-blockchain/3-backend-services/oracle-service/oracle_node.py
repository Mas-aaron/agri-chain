"""
Independent Oracle Node Microservice.

This is a standalone FastAPI application that acts as one node in
a multi-oracle network. Each node independently fetches yield estimates
from its configured sources, signs the report with its ECDSA private key,
and submits it to the aggregator (main backend oracle endpoint).

In production: run multiple instances (university, agri-tech company,
farmers' cooperative) each with their own key pairs and source configs.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import secrets
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx
import uvicorn
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ── Configuration ─────────────────────────────────────────────────────────────
NODE_ID = os.getenv("ORACLE_NODE_ID", "node-university-01")
NODE_PORT = int(os.getenv("ORACLE_NODE_PORT", "8001"))
AGGREGATOR_URL = os.getenv("AGGREGATOR_URL", "http://localhost:8000/oracle/trigger")
BASE_YIELD_ESTIMATE = float(os.getenv("BASE_YIELD_ESTIMATE", "4500.0"))

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# ── ECDSA Key Pair (in production: loaded from KMS / env secrets) ─────────────
_private_key = ec.generate_private_key(ec.SECP256R1())
_public_key = _private_key.public_key()
_public_key_pem = _public_key.public_bytes(
    serialization.Encoding.PEM,
    serialization.PublicFormat.SubjectPublicKeyInfo,
).decode()


def sign_report(report: dict) -> str:
    """Sign a report dict with this node's ECDSA private key."""
    payload = json.dumps(report, sort_keys=True, default=str).encode()
    digest = hashlib.sha256(payload).digest()
    signature = _private_key.sign(digest, ec.ECDSA(hashes.Prehashed(hashes.SHA256())))
    return signature.hex()


def _node_yield_estimate(asset_id: str, crop_type: str, geo_hash: str) -> float:
    """
    This node's yield estimate.
    In production: call the university's ML model or remote-sensing API.
    Here: deterministic per-asset estimate ± Gaussian noise.
    """
    import random
    import math
    seed = int(hashlib.md5(f"{NODE_ID}:{asset_id}".encode()).hexdigest()[:8], 16)
    random.seed(seed + int(datetime.now().hour))  # hourly variation
    base = BASE_YIELD_ESTIMATE
    # Node-specific bias
    bias_map = {
        "node-university-01": 0.02,
        "node-agritech-02": -0.01,
        "node-coop-03": 0.005,
    }
    bias = bias_map.get(NODE_ID, 0.0)
    noise = random.gauss(bias, 0.06)
    return max(0.0, base * (1 + noise))

# ── FastAPI app ───────────────────────────────────────────────────────────────
app = FastAPI(
    title=f"AgriYield Oracle Node — {NODE_ID}",
    description="Independent oracle node for AgriYield yield verification.",
    version="1.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class OracleSubmitRequest(BaseModel):
    asset_id: str
    crop_type: Optional[str] = "Maize"
    geo_hash: Optional[str] = ""


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {
        "node_id": NODE_ID,
        "status": "ok",
        "public_key": _public_key_pem[:80] + "...",
    }


@app.get("/oracle/asset/{asset_id}", response_model=Dict[str, Any])
async def estimate_asset_yield(asset_id: str, crop_type: str = "Maize", geo_hash: str = ""):
    """Return this node's independently computed yield estimate for an asset."""
    value = _node_yield_estimate(asset_id, crop_type, geo_hash)
    report = {
        "node_id": NODE_ID,
        "asset_id": asset_id,
        "crop_type": crop_type,
        "geo_hash": geo_hash,
        "yield_estimate_kg": round(value, 2),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    report["signature"] = sign_report(report)
    return report


@app.post("/oracle/submit", response_model=Dict[str, Any])
async def submit_to_aggregator(body: OracleSubmitRequest):
    """
    Compute this node's yield estimate, sign it, and forward it to the
    main backend oracle aggregator endpoint (POST /oracle/trigger/{asset_id}).
    """
    value = _node_yield_estimate(body.asset_id, body.crop_type, body.geo_hash)
    report = {
        "node_id": NODE_ID,
        "asset_id": body.asset_id,
        "crop_type": body.crop_type,
        "yield_estimate_kg": round(value, 2),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    signature = sign_report(report)
    payload = {**report, "signature": signature, "public_key": _public_key_pem}

    # Forward to aggregator (main backend)
    aggregator_url = f"{AGGREGATOR_URL}/{body.asset_id}"
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                aggregator_url,
                json={"crop_type": body.crop_type, "geo_hash": body.geo_hash or ""},
            )
            resp.raise_for_status()
            agg_result = resp.json()
    except httpx.RequestError as e:
        logger.error(f"Aggregator unreachable: {e}")
        agg_result = {"error": "aggregator unreachable", "details": str(e)}

    return {
        "node_report": payload,
        "aggregator_response": agg_result,
    }


@app.get("/oracle/pubkey", response_model=Dict[str, Any])
async def get_public_key():
    """Return this node's ECDSA public key for signature verification."""
    return {"node_id": NODE_ID, "public_key_pem": _public_key_pem}


if __name__ == "__main__":
    uvicorn.run("oracle_node:app", host="0.0.0.0", port=NODE_PORT, reload=False)
