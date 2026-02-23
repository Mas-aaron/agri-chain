"""
PesaPal API v3 service — handles authentication, order submission,
IPN registration, and transaction status queries.

Docs: https://developer.pesapal.com/how-to-integrate/e-commerce/api-30-json/api-reference
"""
from __future__ import annotations

import os
import time
import logging
from typing import Optional, Dict, Any

import httpx

logger = logging.getLogger("agrichain.pesapal")


# ── Environment (read lazily to ensure docker env_file is loaded) ─
def _get_config():
    """Return PesaPal config dict, reading env vars at call time."""
    env = os.getenv("PESAPAL_ENV", "sandbox").strip().lower()
    base_url = (
        "https://pay.pesapal.com/v3"
        if env == "production"
        else "https://cybqa.pesapal.com/pesapalv3"
    )
    key = os.getenv("PESAPAL_CONSUMER_KEY", "").strip()
    secret = os.getenv("PESAPAL_CONSUMER_SECRET", "").strip()
    callback = os.getenv("PESAPAL_CALLBACK_URL", "").strip()
    ipn = os.getenv("PESAPAL_IPN_URL", "").strip()

    logger.info(f"PesaPal config: ENV={env}, URL={base_url}, key={key[:8] if key else 'EMPTY'}...")
    return {
        "base_url": base_url,
        "consumer_key": key,
        "consumer_secret": secret,
        "callback_url": callback,
        "ipn_url": ipn,
    }


# ── Token cache ──────────────────────────────────────────────────
_cached_token: Optional[str] = None
_token_expiry: float = 0.0


async def get_token() -> str:
    """Obtain (or return cached) bearer token from PesaPal."""
    global _cached_token, _token_expiry

    if _cached_token and time.time() < _token_expiry:
        return _cached_token

    cfg = _get_config()
    url = f"{cfg['base_url']}/api/Auth/RequestToken"
    payload = {
        "consumer_key": cfg["consumer_key"],
        "consumer_secret": cfg["consumer_secret"],
    }

    logger.info(f"PesaPal auth → URL={url}")

    if not cfg["consumer_key"]:
        raise Exception("PESAPAL_CONSUMER_KEY is empty — check .env file")

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, json=payload, headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
        })

        logger.info(f"PesaPal auth response: status={resp.status_code}")

        if resp.status_code != 200:
            body = resp.text
            logger.error(f"PesaPal auth failed: {resp.status_code} → {body}")
            raise Exception(f"PesaPal auth failed ({resp.status_code}): {body}")

        data = resp.json()

    token = data.get("token", "")
    error = data.get("error", "")
    status = data.get("status", "")

    if error:
        logger.error(f"PesaPal auth error: {error} (status={status})")
        raise Exception(f"PesaPal auth error: {error}")

    if not token:
        logger.error(f"PesaPal returned empty token. Full response: {data}")
        raise Exception(f"PesaPal returned empty token: {data}")

    # Cache for 4 minutes (tokens last 5 min)
    _cached_token = token
    _token_expiry = time.time() + 240
    logger.info("PesaPal auth token obtained ✅")
    return token


async def register_ipn(ipn_url: Optional[str] = None) -> str:
    """
    Register an IPN URL with PesaPal.
    Returns the ipn_id (GUID) to use in SubmitOrderRequest.
    """
    cfg = _get_config()
    token = await get_token()
    url = f"{cfg['base_url']}/api/URLSetup/RegisterIPN"
    payload = {
        "url": ipn_url or cfg["ipn_url"],
        "ipn_notification_type": "GET",
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, json=payload, headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        })
        resp.raise_for_status()
        data = resp.json()

    ipn_id = data.get("ipn_id", "")
    logger.info(f"PesaPal IPN registered: {ipn_id}")
    return ipn_id


async def submit_order(
    merchant_reference: str,
    amount: float,
    currency: str,
    description: str,
    ipn_id: str,
    callback_url: Optional[str] = None,
    billing: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
    """
    Submit an order to PesaPal.
    Returns dict with 'order_tracking_id', 'merchant_reference',
    'redirect_url', and 'status'.
    """
    cfg = _get_config()
    token = await get_token()
    url = f"{cfg['base_url']}/api/Transactions/SubmitOrderRequest"

    payload: Dict[str, Any] = {
        "id": merchant_reference,
        "currency": currency,
        "amount": amount,
        "description": description,
        "callback_url": callback_url or cfg["callback_url"],
        "notification_id": ipn_id,
        "billing_address": billing or {},
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, json=payload, headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        })
        resp.raise_for_status()
        data = resp.json()

    logger.info(
        f"PesaPal order submitted: tracking={data.get('order_tracking_id')}, "
        f"ref={merchant_reference}"
    )
    return data


async def get_transaction_status(order_tracking_id: str) -> Dict[str, Any]:
    """
    Query the final status of a PesaPal transaction.
    Returns dict with 'payment_status', 'payment_method',
    'confirmation_code', etc.
    """
    cfg = _get_config()
    token = await get_token()
    url = (
        f"{cfg['base_url']}/api/Transactions/GetTransactionStatus"
        f"?orderTrackingId={order_tracking_id}"
    )

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(url, headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        })
        resp.raise_for_status()
        data = resp.json()

    logger.info(
        f"PesaPal status for {order_tracking_id}: "
        f"{data.get('payment_status_description', 'unknown')}"
    )
    return data
