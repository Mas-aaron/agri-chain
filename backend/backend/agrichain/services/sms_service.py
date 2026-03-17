"""
Twilio SMS & WhatsApp Service for AgriChain.

Sends notifications to farmers via Twilio.
Environment variables:
  TWILIO_ACCOUNT_SID  - Twilio Account SID
  TWILIO_AUTH_TOKEN   - Twilio Auth Token
  TWILIO_PHONE_NUMBER - Your Twilio Sender Number (e.g. +1234567890)
  TWILIO_WHATSAPP_NUMBER - (Optional) Twilio WhatsApp Sender Number (e.g. +1234567890)
"""
from __future__ import annotations

import logging
import os
from typing import Dict, Optional

# The twilio package must be installed (pip install twilio)
from twilio.rest import Client
from twilio.base.exceptions import TwilioRestException

logger = logging.getLogger("agrichain.sms")

def _get_twilio_config() -> Dict[str, str]:
    return {
        "account_sid": os.getenv("TWILIO_ACCOUNT_SID", "").strip(),
        "auth_token": os.getenv("TWILIO_AUTH_TOKEN", "").strip(),
        "phone_number": os.getenv("TWILIO_PHONE_NUMBER", "").strip(),
        "whatsapp_number": os.getenv("TWILIO_WHATSAPP_NUMBER", "").strip(),
    }

async def send_twilio_message(
    phone: str,
    message: str,
    use_whatsapp: bool = False
) -> Dict[str, str]:
    """
    Send an SMS or WhatsApp message via Twilio.
    """
    if not phone or not phone.strip():
        logger.debug("Twilio skipped \u2014 no phone number provided")
        return {"status": "skipped", "reason": "no_phone"}

    cfg = _get_twilio_config()

    if not cfg["account_sid"] or not cfg["auth_token"]:
        logger.warning("Twilio skipped \u2014 TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN not configured")
        return {"status": "skipped", "reason": "not_configured"}

    # Format the sender and recipient for WhatsApp if requested
    if use_whatsapp:
        sender = cfg.get("whatsapp_number")
        if not sender:
            # Fall back to standard SMS if WhatsApp isn't configured
            sender = cfg["phone_number"]
            to_phone = phone
        else:
            sender = f"whatsapp:{sender}"
            to_phone = f"whatsapp:{phone}"
    else:
        sender = cfg["phone_number"]
        to_phone = phone

    if not sender:
        logger.warning("Twilio skipped \u2014 TWILIO_PHONE_NUMBER not configured")
        return {"status": "skipped", "reason": "no_sender"}

    try:
        # Twilio's Python SDK is synchronous, but we can call it in this async wrapper
        # For a high-load production environment, you'd wrap this in run_in_executor.
        client = Client(cfg["account_sid"], cfg["auth_token"])
        
        msg = client.messages.create(
            body=message,
            from_=sender,
            to=to_phone
        )
        logger.info(f"\u2705 Twilio message sent successfully to {to_phone}. SID: {msg.sid}")
        return {"status": "sent", "sid": msg.sid}

    except TwilioRestException as e:
        logger.error(f"Twilio API error for {to_phone}: {e}")
        return {"status": "error", "detail": str(e)}
    except Exception as e:
        logger.error(f"Twilio send failed for {to_phone}: {e}")
        return {"status": "error", "detail": str(e)}

# \u2500\u2500 Convenience wrappers for AgriChain events \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

async def notify_contract_purchased(
    farmer_phone: str,
    contract_id: str,
    buyer_name: str,
    crop: str,
    total: float,
    currency: str,
) -> Dict[str, str]:
    """Notify farmer that their contract has been purchased."""
    message = (
        f"AgriChain Alert: Amazing news! Your {crop} contract ({contract_id}) "
        f"has just been purchased by {buyer_name} for {currency} {total:,.0f}."
    )
    logger.info(f"Sending contract-purchased Twilio msg to {farmer_phone} for {contract_id}")
    return await send_twilio_message(farmer_phone, message=message, use_whatsapp=True)

async def notify_token_traded(
    farmer_phone: str,
    asset_id: str,
    trade_id: str,
    amount: float,
    trade_type: str,
) -> Dict[str, str]:
    """Notify farmer that their tokens have been traded."""
    message = (
        f"AgriChain Alert: Your asset {asset_id} had a {trade_type} trade "
        f"(ID: {trade_id}) for an amount of {amount:,.2f}."
    )
    logger.info(f"Sending token-trade Twilio msg to {farmer_phone} for {asset_id}")
    return await send_twilio_message(farmer_phone, message=message, use_whatsapp=True)

async def notify_payment_completed(
    farmer_phone: str,
    contract_id: str,
    amount: str,
    reference: str,
) -> Dict[str, str]:
    """Notify farmer that payment has been completed."""
    message = (
        f"AgriChain Alert: Payment for contract {contract_id} is complete! "
        f"Amount: {amount}. Reference: {reference}."
    )
    logger.info(f"Sending payment-completed Twilio msg to {farmer_phone} for {contract_id}")
    # SMS fallback example (use_whatsapp=False)
    return await send_twilio_message(farmer_phone, message=message, use_whatsapp=False)

async def notify_payout_initiated(
    farmer_phone: str,
    contract_id: str,
    amount: str,
    currency: str,
) -> Dict[str, str]:
    """Notify farmer that their payout has been initiated after verification."""
    message = (
        f"AgriChain Alert: Your payout of {currency} {amount} for "
        f"contract {contract_id} has been initiated and is on the way!"
    )
    logger.info(f"Sending payout-initiated Twilio msg to {farmer_phone} for {contract_id}")
    return await send_twilio_message(farmer_phone, message=message, use_whatsapp=True)
