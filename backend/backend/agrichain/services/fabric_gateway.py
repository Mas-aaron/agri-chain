from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Optional Fabric SDK imports — the backend starts in mock mode if any of
# these packages are missing (e.g. Python 3.12 where fabric-gateway cannot
# be installed via pip).  When FABRIC_MODE=gateway AND all certs are present
# AND the SDK is installed, real Fabric transactions are used instead.
# ---------------------------------------------------------------------------
_FABRIC_IMPORT_ERROR: Optional[Exception] = None
try:
    import grpc  # type: ignore[import]
    from cryptography.hazmat.primitives import serialization  # type: ignore[import]
    from fabric_gateway import Gateway, Identity, Network, Signer, signers  # type: ignore[import]
except Exception as _e:
    grpc = None  # type: ignore[assignment]
    serialization = None  # type: ignore[assignment]
    Gateway = None  # type: ignore[assignment]
    Identity = None  # type: ignore[assignment]
    Network = None  # type: ignore[assignment]
    Signer = None  # type: ignore[assignment]
    signers = None  # type: ignore[assignment]
    _FABRIC_IMPORT_ERROR = _e


@dataclass(frozen=True)
class FabricSettings:
    enabled: bool
    peer_endpoint: str
    tls_cert_path: Path
    msp_id: str
    cert_path: Path
    key_path: Path
    channel_name: str
    chaincode_name: str


def load_fabric_settings() -> FabricSettings:
    mode = os.getenv("FABRIC_MODE", "mock").strip().lower()
    enabled = mode in {"gateway", "fabric", "real"}

    peer_endpoint = os.getenv("FABRIC_PEER_ENDPOINT", "").strip()
    tls_cert_path = Path(os.getenv("FABRIC_TLS_CERT_PATH", "")).expanduser()
    msp_id = os.getenv("FABRIC_MSP_ID", "").strip()
    cert_path = Path(os.getenv("FABRIC_CERT_PATH", "")).expanduser()
    key_path = Path(os.getenv("FABRIC_KEY_PATH", "")).expanduser()

    channel_name = os.getenv("FABRIC_CHANNEL", "yield-channel").strip() or "yield-channel"
    chaincode_name = os.getenv("FABRIC_CHAINCODE", "agri_yield").strip() or "agri_yield"

    return FabricSettings(
        enabled=enabled,
        peer_endpoint=peer_endpoint,
        tls_cert_path=tls_cert_path,
        msp_id=msp_id,
        cert_path=cert_path,
        key_path=key_path,
        channel_name=channel_name,
        chaincode_name=chaincode_name,
    )


class FabricGatewayClient:
    def __init__(self, settings: FabricSettings) -> None:
        self._settings = settings
        self._gateway = None  # type: Optional[Any]
        self._network = None  # type: Optional[Any]

    @property
    def settings(self) -> FabricSettings:
        return self._settings

    def is_configured(self) -> bool:
        if _FABRIC_IMPORT_ERROR is not None:
            return False
        s = self._settings
        if not s.enabled:
            return False
        if not s.peer_endpoint:
            return False
        if not s.msp_id:
            return False
        if not s.tls_cert_path or not s.tls_cert_path.exists():
            return False
        if not s.cert_path or not s.cert_path.exists():
            return False
        if not s.key_path or not s.key_path.exists():
            return False
        return True

    def _new_grpc_channel(self):
        if _FABRIC_IMPORT_ERROR is not None or grpc is None:
            raise RuntimeError(f"Fabric SDK not installed: {_FABRIC_IMPORT_ERROR}")
        tls_cert = self._settings.tls_cert_path.read_bytes()
        credentials = grpc.ssl_channel_credentials(tls_cert)
        return grpc.secure_channel(self._settings.peer_endpoint, credentials)

    def _new_identity(self):
        if _FABRIC_IMPORT_ERROR is not None or Identity is None:
            raise RuntimeError(f"Fabric SDK not installed: {_FABRIC_IMPORT_ERROR}")
        certificate = self._settings.cert_path.read_bytes()
        return Identity(self._settings.msp_id, certificate)

    def _new_signer(self):
        if _FABRIC_IMPORT_ERROR is not None or signers is None or serialization is None:
            raise RuntimeError(f"Fabric SDK not installed: {_FABRIC_IMPORT_ERROR}")
        private_key_pem = self._settings.key_path.read_bytes()
        private_key = serialization.load_pem_private_key(private_key_pem, password=None)
        return signers.new_private_key_signer(private_key)

    def connect(self) -> None:
        if self._gateway is not None and self._network is not None:
            return
        if not self.is_configured():
            raise RuntimeError("Fabric gateway is not configured. Set FABRIC_* environment variables.")

        channel = self._new_grpc_channel()
        identity = self._new_identity()
        signer = self._new_signer()

        self._gateway = Gateway()
        self._gateway.connect(identity, signer, channel)
        self._network = self._gateway.get_network(self._settings.channel_name)

    def close(self) -> None:
        if self._gateway is not None:
            try:
                self._gateway.close()
            finally:
                self._gateway = None
                self._network = None

    def _contract(self):
        self.connect()
        assert self._network is not None
        return self._network.get_contract(self._settings.chaincode_name)

    def evaluate(self, transaction_name: str, *args: str) -> bytes:
        contract = self._contract()
        return contract.evaluate_transaction(transaction_name, *args)

    def submit(self, transaction_name: str, *args: str) -> bytes:
        contract = self._contract()
        return contract.submit_transaction(transaction_name, *args)


_client: Optional[FabricGatewayClient] = None


def get_fabric_client() -> FabricGatewayClient:
    global _client
    if _client is None:
        _client = FabricGatewayClient(load_fabric_settings())
    return _client
