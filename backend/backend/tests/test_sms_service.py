"""
Tests for the Huawei Cloud SMS notification service.
Run with: python -m pytest tests/test_sms_service.py -v --tb=short
"""
from __future__ import annotations

import os
import tempfile
import unittest
from unittest.mock import AsyncMock, patch, MagicMock

# Point the DB at a temp file so tests don't touch production data
_tmp_db = tempfile.mktemp(suffix=".db")
os.environ["AGRICHAIN_DB_PATH"] = _tmp_db
# Ensure SMS keys are NOT set so we can test the skip logic
os.environ.pop("HUAWEI_SMS_APP_KEY", None)
os.environ.pop("HUAWEI_SMS_APP_SECRET", None)
os.environ.pop("HUAWEI_SMS_SENDER", None)

import asyncio

from agrichain.services.sms_service import (
    send_sms,
    notify_contract_purchased,
    notify_token_traded,
    notify_payment_completed,
    _build_wsse_header,
    _is_configured,
)


def _run(coro):
    """Helper to run async tests."""
    return asyncio.get_event_loop().run_until_complete(coro)


# ─────────────────────────────────────────────────────────────────────────────
# WSSE HEADER CONSTRUCTION
# ─────────────────────────────────────────────────────────────────────────────

class TestWSSEHeader(unittest.TestCase):

    def test_header_format(self):
        """WSSE header should contain Username, PasswordDigest, Nonce, Created."""
        header = _build_wsse_header("test_key", "test_secret")
        self.assertIn('Username="test_key"', header)
        self.assertIn("PasswordDigest=", header)
        self.assertIn("Nonce=", header)
        self.assertIn("Created=", header)
        self.assertTrue(header.startswith("UsernameToken"))

    def test_header_different_nonces(self):
        """Two calls should produce different nonces."""
        h1 = _build_wsse_header("k", "s")
        h2 = _build_wsse_header("k", "s")
        # Extract nonce values
        import re
        n1 = re.search(r'Nonce="([^"]+)"', h1)
        n2 = re.search(r'Nonce="([^"]+)"', h2)
        self.assertIsNotNone(n1)
        self.assertIsNotNone(n2)
        # Nonces should differ (UUID-based)
        self.assertNotEqual(n1.group(1), n2.group(1))


# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION CHECK
# ─────────────────────────────────────────────────────────────────────────────

class TestConfiguration(unittest.TestCase):

    def test_not_configured_when_keys_missing(self):
        """Should report not configured when env vars are empty."""
        self.assertFalse(_is_configured())

    @patch.dict(os.environ, {
        "HUAWEI_SMS_APP_KEY": "test_key",
        "HUAWEI_SMS_APP_SECRET": "test_secret",
        "HUAWEI_SMS_SENDER": "csms12345",
    })
    def test_configured_when_keys_present(self):
        """Should report configured when all required keys are set."""
        self.assertTrue(_is_configured())


# ─────────────────────────────────────────────────────────────────────────────
# SEND SMS — SKIP SCENARIOS
# ─────────────────────────────────────────────────────────────────────────────

class TestSendSmsSkip(unittest.TestCase):

    def test_skip_no_phone(self):
        """Should skip when phone is empty."""
        result = _run(send_sms("", ["param1"]))
        self.assertEqual(result["status"], "skipped")
        self.assertEqual(result["reason"], "no_phone")

    def test_skip_none_phone(self):
        """Should skip when phone is None-like empty string."""
        result = _run(send_sms("  ", ["param1"]))
        self.assertEqual(result["status"], "skipped")
        self.assertEqual(result["reason"], "no_phone")

    def test_skip_not_configured(self):
        """Should skip when API keys are not set."""
        result = _run(send_sms("+256700123456", ["param1"]))
        self.assertEqual(result["status"], "skipped")
        self.assertEqual(result["reason"], "not_configured")


# ─────────────────────────────────────────────────────────────────────────────
# SEND SMS — WITH MOCKED HTTP
# ─────────────────────────────────────────────────────────────────────────────

class TestSendSmsWithMock(unittest.TestCase):

    @patch.dict(os.environ, {
        "HUAWEI_SMS_APP_KEY": "test_key",
        "HUAWEI_SMS_APP_SECRET": "test_secret",
        "HUAWEI_SMS_SENDER": "csms12345",
        "HUAWEI_SMS_TEMPLATE_ID": "tmpl_001",
    })
    @patch("agrichain.services.sms_service.httpx.AsyncClient")
    def test_send_success(self, mock_client_cls):
        """Should return 'sent' when API returns code 000000."""
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = '{"code":"000000","description":"Success"}'
        mock_resp.json.return_value = {"code": "000000", "description": "Success"}

        mock_client = AsyncMock()
        mock_client.post.return_value = mock_resp
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client_cls.return_value = mock_client

        result = _run(send_sms("+256700123456", ["param1", "param2"]))
        self.assertEqual(result["status"], "sent")
        self.assertEqual(result["code"], "000000")

        # Verify the POST was called with correct data
        mock_client.post.assert_called_once()
        call_kwargs = mock_client.post.call_args
        self.assertIn("data", call_kwargs.kwargs)
        self.assertEqual(call_kwargs.kwargs["data"]["from"], "csms12345")
        self.assertEqual(call_kwargs.kwargs["data"]["to"], "+256700123456")
        self.assertEqual(call_kwargs.kwargs["data"]["templateId"], "tmpl_001")

    @patch.dict(os.environ, {
        "HUAWEI_SMS_APP_KEY": "test_key",
        "HUAWEI_SMS_APP_SECRET": "test_secret",
        "HUAWEI_SMS_SENDER": "csms12345",
        "HUAWEI_SMS_TEMPLATE_ID": "tmpl_001",
    })
    @patch("agrichain.services.sms_service.httpx.AsyncClient")
    def test_send_api_error(self, mock_client_cls):
        """Should return 'error' when API returns non-000000 code."""
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.text = '{"code":"E000102","description":"Invalid template"}'
        mock_resp.json.return_value = {"code": "E000102", "description": "Invalid template"}

        mock_client = AsyncMock()
        mock_client.post.return_value = mock_resp
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client_cls.return_value = mock_client

        result = _run(send_sms("+256700123456", ["param1"]))
        self.assertEqual(result["status"], "error")
        self.assertEqual(result["code"], "E000102")

    @patch.dict(os.environ, {
        "HUAWEI_SMS_APP_KEY": "test_key",
        "HUAWEI_SMS_APP_SECRET": "test_secret",
        "HUAWEI_SMS_SENDER": "csms12345",
        "HUAWEI_SMS_TEMPLATE_ID": "tmpl_001",
    })
    @patch("agrichain.services.sms_service.httpx.AsyncClient")
    def test_send_http_error(self, mock_client_cls):
        """Should return 'error' when HTTP status is not 200."""
        mock_resp = MagicMock()
        mock_resp.status_code = 500
        mock_resp.text = "Internal Server Error"

        mock_client = AsyncMock()
        mock_client.post.return_value = mock_resp
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client_cls.return_value = mock_client

        result = _run(send_sms("+256700123456", ["param1"]))
        self.assertEqual(result["status"], "error")
        self.assertEqual(result["http_status"], "500")

    @patch.dict(os.environ, {
        "HUAWEI_SMS_APP_KEY": "test_key",
        "HUAWEI_SMS_APP_SECRET": "test_secret",
        "HUAWEI_SMS_SENDER": "csms12345",
        "HUAWEI_SMS_TEMPLATE_ID": "tmpl_001",
    })
    @patch("agrichain.services.sms_service.httpx.AsyncClient")
    def test_send_exception_handled(self, mock_client_cls):
        """Should return 'error' and never raise when network fails."""
        mock_client = AsyncMock()
        mock_client.post.side_effect = ConnectionError("Network unreachable")
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client_cls.return_value = mock_client

        # Should NOT raise
        result = _run(send_sms("+256700123456", ["param1"]))
        self.assertEqual(result["status"], "error")
        self.assertIn("Network unreachable", result["detail"])


# ─────────────────────────────────────────────────────────────────────────────
# CONVENIENCE WRAPPERS
# ─────────────────────────────────────────────────────────────────────────────

class TestConvenienceWrappers(unittest.TestCase):

    @patch("agrichain.services.sms_service.send_sms", new_callable=AsyncMock)
    def test_notify_contract_purchased_calls_send_sms(self, mock_send):
        """notify_contract_purchased should call send_sms with correct params."""
        mock_send.return_value = {"status": "sent"}
        result = _run(notify_contract_purchased(
            farmer_phone="+256700111222",
            contract_id="FH-abc123",
            buyer_name="John",
            crop="Maize",
            total=1200000,
            currency="UGX",
        ))
        mock_send.assert_called_once()
        call_args = mock_send.call_args
        self.assertEqual(call_args.kwargs["phone"], "+256700111222")
        params = call_args.kwargs["template_params"]
        self.assertIn("FH-abc123", params)
        self.assertIn("John", params)

    @patch("agrichain.services.sms_service.send_sms", new_callable=AsyncMock)
    def test_notify_token_traded_calls_send_sms(self, mock_send):
        """notify_token_traded should call send_sms with correct params."""
        mock_send.return_value = {"status": "sent"}
        result = _run(notify_token_traded(
            farmer_phone="+256700333444",
            asset_id="ASSET_XYZ",
            trade_id="TR-001",
            amount=500.0,
            trade_type="BUY",
        ))
        mock_send.assert_called_once()
        params = mock_send.call_args.kwargs["template_params"]
        self.assertIn("ASSET_XYZ", params)
        self.assertIn("TR-001", params)

    @patch("agrichain.services.sms_service.send_sms", new_callable=AsyncMock)
    def test_notify_payment_completed_calls_send_sms(self, mock_send):
        """notify_payment_completed should call send_sms with correct params."""
        mock_send.return_value = {"status": "sent"}
        result = _run(notify_payment_completed(
            farmer_phone="+256700555666",
            contract_id="FH-def456",
            amount="1200000 UGX",
            reference="REF-001",
        ))
        mock_send.assert_called_once()
        params = mock_send.call_args.kwargs["template_params"]
        self.assertIn("FH-def456", params)
        self.assertIn("1200000 UGX", params)


if __name__ == "__main__":
    unittest.main()
