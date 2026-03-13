"""
Huawei Cloud SMS Service for AgriChain.

Sends SMS notifications to farmers via Huawei Cloud Message & SMS API.
Uses X-WSSE authentication as per Huawei docs:
https://support.huaweicloud.com/intl/en-us/devg-msgsms/sms_04_0004.html

Environment variables:
  HUAWEI_SMS_API_URL      – API endpoint (default: ap-southeast-1)
  HUAWEI_SMS_APP_KEY      – Application Key from SMS console
  HUAWEI_SMS_APP_SECRET   – Application Secret from SMS console
  HUAWEI_SMS_SENDER       – Channel/sender number
  HUAWEI_SMS_TEMPLATE_ID  – Default template ID for notifications

All SMS sending is fire-and-forget: errors are logged but never block
the main business logic.
"""
from __future__ import annotations

import hashlib
import base64
import json
import logging
import os
import time
import uuid
from typing import Dict, List, Optional

import httpx

logger = logging.getLogger("agrichain.sms")


# ── Configuration (read lazily so Docker env_file is loaded first) ──────
def _get_sms_config() -> Dict[str, str]:
    return {
        "api_url": os.getenv(
            "HUAWEI_SMS_API_URL",
            "https://smsapi.ap-southeast-1.myhuaweicloud.com:443/sms/batchSendSms/v1",
        ).strip(),
        "app_key": os.getenv("HUAWEI_SMS_APP_KEY", "").strip(),
        "app_secret": os.getenv("HUAWEI_SMS_APP_SECRET", "").strip(),
        "sender": os.getenv("HUAWEI_SMS_SENDER", "").strip(),
        "template_id": os.getenv("HUAWEI_SMS_TEMPLATE_ID", "").strip(),
    }


def _is_configured() -> bool:
    """Return True if all required SMS credentials are set."""
    cfg = _get_sms_config()
    return bool(cfg["app_key"] and cfg["app_secret"] and cfg["sender"])


# ── X-WSSE Authentication ────────────────────────────────────────────
def _build_wsse_header(app_key: str, app_secret: str) -> str:
    """
    Build the X-WSSE header value as per Huawei Cloud SMS specification.
    UsernameToken with SHA-256 PasswordDigest.
    """
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ")
    nonce = uuid.uuid4().hex
    digest = hashlib.sha256((nonce + now + app_secret).encode()).hexdigest()
    digest_b64 = base64.b64encode(digest.encode()).decode()
    return (
        f'UsernameToken Username="{app_key}",'
        f'PasswordDigest="{digest_b64}",'
        f'Nonce="{nonce}",'
        f'Created="{now}"'
    )


# ── Core send function ───────────────────────────────────────────────
async def send_sms(
    phone: str,
    template_params: List[str],
    template_id: Optional[str] = None,
) -> Dict[str, str]:
    """
    Send an SMS via Huawei Cloud Message & SMS API.

    Args:
        phone: Recipient number in global format, e.g. "+256700123456".
        template_params: List of template variable values, e.g. ["FH-abc123", "John"].
        template_id: Override the default template ID. If None, uses env var.

    Returns:
        dict with "status" ("sent", "skipped", or "error") and optional details.
    """
    if not phone or not phone.strip():
        logger.debug("SMS skipped — no phone number provided")
        return {"status": "skipped", "reason": "no_phone"}

    cfg = _get_sms_config()

    if not cfg["app_key"] or not cfg["app_secret"]:
        logger.warning("SMS skipped — HUAWEI_SMS_APP_KEY / APP_SECRET not configured")
        return {"status": "skipped", "reason": "not_configured"}

    if not cfg["sender"]:
        logger.warning("SMS skipped — HUAWEI_SMS_SENDER not configured")
        return {"status": "skipped", "reason": "no_sender"}

    tid = template_id or cfg["template_id"]
    if not tid:
        logger.warning("SMS skipped — no template_id provided or configured")
        return {"status": "skipped", "reason": "no_template"}

    # Build headers
    headers = {
        "Authorization": 'WSSE realm="SDP",profile="UsernameToken",type="Appkey"',
        "X-WSSE": _build_wsse_header(cfg["app_key"], cfg["app_secret"]),
        "Content-Type": "application/x-www-form-urlencoded",
    }

    # Build form body
    form_data = {
        "from": cfg["sender"],
        "to": phone.strip(),
        "templateId": tid,
        "templateParas": json.dumps(template_params, ensure_ascii=False),
        "statusCallback": "",
    }

    try:
        async with httpx.AsyncClient(timeout=15, verify=False) as client:
            resp = await client.post(cfg["api_url"], data=form_data, headers=headers)

        body = resp.text
        logger.info(f"SMS to {phone}: status={resp.status_code}, body={body[:200]}")

        if resp.status_code == 200:
            resp_data = resp.json() if resp.text else {}
            code = resp_data.get("code", "")
            if code == "000000":
                logger.info(f"✅ SMS sent successfully to {phone}")
                return {"status": "sent", "code": code}
            else:
                logger.warning(f"SMS API returned code={code}: {resp_data.get('description', '')}")
                return {"status": "error", "code": code, "detail": resp_data.get("description", "")}
        else:
            logger.warning(f"SMS API HTTP error: {resp.status_code}")
            return {"status": "error", "http_status": str(resp.status_code), "detail": body[:200]}

    except Exception as e:
        logger.error(f"SMS send failed for {phone}: {e}")
        return {"status": "error", "detail": str(e)}


# ── Convenience wrappers for AgriChain events ─────────────────────────

async def notify_contract_purchased(
    farmer_phone: str,
    contract_id: str,
    buyer_name: str,
    crop: str,
    total: float,
    currency: str,
) -> Dict[str, str]:
    """Notify farmer that their contract has been purchased."""
    params = [contract_id, crop, buyer_name, f"{total:,.0f}", currency]
    logger.info(f"Sending contract-purchased SMS to {farmer_phone} for {contract_id}")
    return await send_sms(farmer_phone, template_params=params)


async def notify_token_traded(
    farmer_phone: str,
    asset_id: str,
    trade_id: str,
    amount: float,
    trade_type: str,
) -> Dict[str, str]:
    """Notify farmer that their tokens have been traded."""
    params = [asset_id, f"{amount:,.2f}", trade_type, trade_id]
    logger.info(f"Sending token-trade SMS to {farmer_phone} for {asset_id}")
    return await send_sms(farmer_phone, template_params=params)


async def notify_payment_completed(
    farmer_phone: str,
    contract_id: str,
    amount: str,
    reference: str,
) -> Dict[str, str]:
    """Notify farmer that payment has been completed."""
    params = [contract_id, amount, reference]
    logger.info(f"Sending payment-completed SMS to {farmer_phone} for {contract_id}")
    return await send_sms(farmer_phone, template_params=params)


async def notify_payout_initiated(
    farmer_phone: str,
    contract_id: str,
    amount: str,
    currency: str,
) -> Dict[str, str]:
    """Notify farmer that their payout has been initiated after verification."""
    params = [contract_id, amount, currency]
    logger.info(f"Sending payout-initiated SMS to {farmer_phone} for {contract_id}")
    return await send_sms(farmer_phone, template_params=params)
