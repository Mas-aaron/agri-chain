"""
Real Hyperledger Fabric 2.x gRPC client for Huawei BCS.
Uses compiled proto stubs to invoke/query chaincode on the peer.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

import grpc
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils
from google.protobuf.timestamp_pb2 import Timestamp

# ── Proto imports ─────────────────────────────────────────────
# Resolve the absolute path to fabric_pb so it works under nohup
# fabric_client.py is in agrichain/services/, fabric_pb is in agrichain/fabric_pb
_THIS_DIR = Path(__file__).resolve().parent  # agrichain/services/
_FABRIC_PB = str(_THIS_DIR.parent / "fabric_pb")  # agrichain/fabric_pb/
if _FABRIC_PB not in sys.path:
    sys.path.insert(0, _FABRIC_PB)

try:
    from peer import chaincode_pb2  # type: ignore
    from peer import proposal_pb2  # type: ignore
    from peer import peer_pb2_grpc  # type: ignore
    from common import common_pb2  # type: ignore
    from msp import identities_pb2  # type: ignore

    PROTOS_AVAILABLE = True
    logging.getLogger(__name__).info(f"Fabric protos loaded from {_FABRIC_PB}")
except ImportError as exc:
    PROTOS_AVAILABLE = False
    logging.getLogger(__name__).warning(
        f"Fabric proto import failed: {exc} (searched {_FABRIC_PB})"
    )


logger = logging.getLogger(__name__)


def _low_s_normalize(signature_der: bytes, private_key) -> bytes:
    """
    Fabric requires low-S ECDSA signatures.
    If S > curve_order/2, replace S with curve_order - S.
    """
    r, s = utils.decode_dss_signature(signature_der)
    # secp256r1 (P-256) curve order
    curve_order = private_key.curve.key_size
    if curve_order == 256:
        n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
    else:
        # For other curves, just return as-is
        return signature_der

    half_order = n >> 1
    if s > half_order:
        s = n - s

    return utils.encode_dss_signature(r, s)


class FabricGrpcClient:
    """
    Connects to a Fabric peer and invokes/queries chaincode
    via the Endorser gRPC service.
    """

    def __init__(
        self,
        peer_endpoint: str,
        peer_hostname: str,
        tls_cert_path: str,
        cert_path: str,
        key_path: str,
        msp_id: str,
        channel: str,
        chaincode: str,
    ):
        self.peer_endpoint = peer_endpoint
        self.peer_hostname = peer_hostname
        self.tls_cert_path = tls_cert_path
        self.cert_path = cert_path
        self.key_path = key_path
        self.msp_id = msp_id
        self.channel = channel
        self.chaincode = chaincode

        self._grpc_channel = None
        self._stub = None
        self._serialized_identity: bytes = b""
        self._private_key = None
        self._connected = False

    # ── Connection ────────────────────────────────────────────

    def connect(self) -> None:
        """Establish gRPC connection and load credentials."""
        if self._connected:
            return

        if not PROTOS_AVAILABLE:
            raise RuntimeError("Fabric proto stubs not available")

        # Load identity cert
        cert_pem = Path(self.cert_path).read_bytes()
        identity = identities_pb2.SerializedIdentity(
            mspid=self.msp_id,
            id_bytes=cert_pem,
        )
        self._serialized_identity = identity.SerializeToString()

        # Load private key
        key_pem = Path(self.key_path).read_bytes()
        self._private_key = serialization.load_pem_private_key(key_pem, password=None)

        # Create TLS channel
        tls_cert = Path(self.tls_cert_path).read_bytes()
        credentials = grpc.ssl_channel_credentials(root_certificates=tls_cert)
        options = [
            ("grpc.ssl_target_name_override", self.peer_hostname),
            ("grpc.default_authority", self.peer_hostname),
            ("grpc.keepalive_time_ms", 15000),
        ]
        self._grpc_channel = grpc.secure_channel(
            self.peer_endpoint, credentials, options=options
        )
        self._stub = peer_pb2_grpc.EndorserStub(self._grpc_channel)
        self._connected = True
        logger.info(f"Connected to Fabric peer {self.peer_endpoint}")

    # ── Signing ───────────────────────────────────────────────

    def _sign(self, message: bytes) -> bytes:
        """Sign with ECDSA and normalize to low-S."""
        digest = hashlib.sha256(message).digest()
        signature_der = self._private_key.sign(
            digest,
            ec.ECDSA(utils.Prehashed(hashes.SHA256())),
        )
        return _low_s_normalize(signature_der, self._private_key)

    # ── Proposal creation ─────────────────────────────────────

    def _build_signed_proposal(
        self, function: str, args: List[str]
    ) -> proposal_pb2.SignedProposal:
        """Build a signed proposal for chaincode invocation."""

        nonce = os.urandom(24)
        creator = self._serialized_identity

        # tx_id = SHA256(nonce + creator)
        tx_id = hashlib.sha256(nonce + creator).hexdigest()

        # ── ChaincodeInvocationSpec ──
        cc_input = chaincode_pb2.ChaincodeInput(
            args=[function.encode("utf-8")]
            + [a.encode("utf-8") for a in args],
        )
        cc_spec = chaincode_pb2.ChaincodeSpec(
            type=chaincode_pb2.ChaincodeSpec.GOLANG,
            chaincode_id=chaincode_pb2.ChaincodeID(name=self.chaincode),
            input=cc_input,
        )
        cc_invocation_spec = chaincode_pb2.ChaincodeInvocationSpec(
            chaincode_spec=cc_spec,
        )

        # ── Channel Header ──
        now = time.time()
        ts = Timestamp()
        ts.FromSeconds(int(now))

        cc_header_ext = proposal_pb2.ChaincodeHeaderExtension(
            chaincode_id=chaincode_pb2.ChaincodeID(name=self.chaincode),
        )

        channel_header = common_pb2.ChannelHeader(
            type=3,  # ENDORSER_TRANSACTION
            channel_id=self.channel,
            tx_id=tx_id,
            timestamp=ts,
            extension=cc_header_ext.SerializeToString(),
        )

        # ── Signature Header ──
        signature_header = common_pb2.SignatureHeader(
            creator=creator,
            nonce=nonce,
        )

        # ── Header ──
        header = common_pb2.Header(
            channel_header=channel_header.SerializeToString(),
            signature_header=signature_header.SerializeToString(),
        )

        # ── Proposal ──
        cc_proposal_payload = proposal_pb2.ChaincodeProposalPayload(
            input=cc_invocation_spec.SerializeToString(),
        )

        proposal = proposal_pb2.Proposal(
            header=header.SerializeToString(),
            payload=cc_proposal_payload.SerializeToString(),
        )

        proposal_bytes = proposal.SerializeToString()
        signature = self._sign(proposal_bytes)

        return proposal_pb2.SignedProposal(
            proposal_bytes=proposal_bytes,
            signature=signature,
        )

    # ── Public API ────────────────────────────────────────────

    def query(self, function: str, args: Optional[List[str]] = None) -> Any:
        """
        Query chaincode (read-only). Does NOT commit a transaction.
        Returns the parsed JSON response from the chaincode.
        """
        self.connect()
        args = args or []
        signed_proposal = self._build_signed_proposal(function, args)

        try:
            response = self._stub.ProcessProposal(
                signed_proposal, timeout=30
            )
        except grpc.RpcError as e:
            logger.error(f"gRPC query failed: {e.code()} - {e.details()}")
            raise RuntimeError(f"Fabric query error: {e.details()}")

        if response.response.status != 200:
            msg = response.response.message or "unknown"
            logger.error(f"Chaincode query error {response.response.status}: {msg}")
            raise RuntimeError(f"Chaincode error ({response.response.status}): {msg}")

        payload = response.response.payload
        if not payload:
            return None

        try:
            return json.loads(payload.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            return payload.decode("utf-8", errors="replace")

    def invoke(self, function: str, args: Optional[List[str]] = None) -> Dict:
        """
        Invoke chaincode (endorsement only for now).
        Note: For full commit, the endorsed transaction must also be
        submitted to the orderer. For demo/query-heavy use, endorsement
        is sufficient to verify the chaincode logic runs.
        """
        self.connect()
        args = args or []
        signed_proposal = self._build_signed_proposal(function, args)

        try:
            response = self._stub.ProcessProposal(
                signed_proposal, timeout=60
            )
        except grpc.RpcError as e:
            logger.error(f"gRPC invoke failed: {e.code()} - {e.details()}")
            raise RuntimeError(f"Fabric invoke error: {e.details()}")

        if response.response.status != 200:
            msg = response.response.message or "unknown"
            raise RuntimeError(f"Chaincode error ({response.response.status}): {msg}")

        logger.info(f"Chaincode {function} endorsed successfully")

        payload = response.response.payload
        result: Dict[str, Any] = {"status": "endorsed"}
        if payload:
            try:
                result["data"] = json.loads(payload.decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                result["data"] = payload.decode("utf-8", errors="replace")

        return result

    def close(self) -> None:
        if self._grpc_channel:
            self._grpc_channel.close()
            self._connected = False
