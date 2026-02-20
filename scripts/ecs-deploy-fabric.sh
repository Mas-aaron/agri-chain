#!/usr/bin/env bash
# ============================================================
#  AgriChain — Full ECS Deploy with BCS Fabric Gateway
#  Run this ON the ECS (101.44.10.153) as root.
#
#  Pre-requisites:
#    1. bcs-certs/ directory already uploaded to /root/bcs-certs/
#    2. Docker image already pushed to SWR
#
#  Usage:
#    bash ecs-deploy-fabric.sh <SWR_IMAGE> [SWR_USER] [SWR_KEY] [SWR_HOST]
# ============================================================
set -euo pipefail

# ─── Config (from BCS SDK config) ────────────────────────────
IMAGE="${1:-swr.la-south-2.myhuaweicloud.com/agrichain/agrichain-backend:latest}"
SWR_USER="${2:-}"
SWR_KEY="${3:-}"
SWR_HOST="${4:-swr.la-south-2.myhuaweicloud.com}"

CERTS_DIR="/root/bcs-certs"

# Farmer-org peer (primary org)
FABRIC_PEER_ENDPOINT="176.52.136.255:30605"
FABRIC_MSP_ID="4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8MSP"
FABRIC_TLS_CERT_PATH="/certs/4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.peer/msp/tlscacerts/tlsca.4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8-cert.pem"
FABRIC_CERT_PATH="/certs/4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.peer/msp/signcerts/User1@4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.peer-4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.default.svc.cluster.local-cert.pem"
FABRIC_KEY_PATH="/certs/4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.peer/msp/keystore/6782ff17-f6d8-c826-0f61-62b04f3a56e4_sk"

FABRIC_CHANNEL="yieldchannel"
FABRIC_CHAINCODE="agriyeild"

echo "========================================"
echo "  AgriChain ECS — BCS Gateway Deploy"
echo "  Peer:      $FABRIC_PEER_ENDPOINT"
echo "  MSP:       $FABRIC_MSP_ID"
echo "  Channel:   $FABRIC_CHANNEL"
echo "  Chaincode: $FABRIC_CHAINCODE"
echo "========================================"

# ─── 1. Install Docker ───────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "[1/6] Installing Docker..."
    apt-get update -qq && apt-get install -y docker.io
    systemctl enable --now docker
else
    echo "[1/6] Docker already installed ✓"
fi

# ─── 2. Login to SWR ─────────────────────────────────────────
if [ -n "$SWR_USER" ] && [ -n "$SWR_KEY" ]; then
    echo "[2/6] Logging in to SWR..."
    docker login -u "$SWR_USER" -p "$SWR_KEY" "$SWR_HOST"
else
    echo "[2/6] Skipping SWR login (already logged in or using local image)"
fi

# ─── 3. Pull image ───────────────────────────────────────────
echo "[3/6] Pulling image: $IMAGE"
docker pull "$IMAGE"

# ─── 4. Stop old container ───────────────────────────────────
echo "[4/6] Stopping old container..."
docker stop agrichain-api 2>/dev/null || true
docker rm   agrichain-api 2>/dev/null || true

# ─── 5. Run with real BCS config ─────────────────────────────
echo "[5/6] Starting container with FABRIC_MODE=gateway..."
docker run -d \
  --name agrichain-api \
  --restart unless-stopped \
  -p 8000:8000 \
  -e FABRIC_MODE=gateway \
  -e FABRIC_PEER_ENDPOINT="$FABRIC_PEER_ENDPOINT" \
  -e FABRIC_MSP_ID="$FABRIC_MSP_ID" \
  -e FABRIC_TLS_CERT_PATH="$FABRIC_TLS_CERT_PATH" \
  -e FABRIC_CERT_PATH="$FABRIC_CERT_PATH" \
  -e FABRIC_KEY_PATH="$FABRIC_KEY_PATH" \
  -e FABRIC_CHANNEL="$FABRIC_CHANNEL" \
  -e FABRIC_CHAINCODE="$FABRIC_CHAINCODE" \
  -v "$CERTS_DIR:/certs:ro" \
  "$IMAGE"

# ─── 6. Health check ─────────────────────────────────────────
echo "[6/6] Waiting for backend..."
sleep 6

HEALTH=$(curl -sf http://localhost:8000/health || echo "FAIL")
echo "Health response: $HEALTH"

if echo "$HEALTH" | grep -q '"ok"'; then
    echo ""
    echo "✓ Backend running!"
    echo "  http://101.44.10.153:8000/health"
    echo "  http://101.44.10.153:8000/docs"
    echo "  http://101.44.10.153:8000/blockchain/assets"
else
    echo "✗ Health check failed. Logs:"
    docker logs agrichain-api --tail 40
    exit 1
fi
