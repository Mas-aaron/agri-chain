#!/usr/bin/env bash
# ============================================================
#  AgriChain — ECS-side deploy script
#  Run this ON the Ubuntu ECS (101.44.10.153) after SSH-ing in.
#
#  Usage:
#    chmod +x ecs-deploy.sh
#    ./ecs-deploy.sh <SWR_IMAGE> <SWR_HOST> <SWR_USER> <SWR_KEY>
#
#  Example:
#    ./ecs-deploy.sh \
#      swr.ap-southeast-3.myhuaweicloud.com/agrichain/agrichain-backend:latest \
#      swr.ap-southeast-3.myhuaweicloud.com \
#      myaccount@myproject \
#      myloginkey
# ============================================================
set -euo pipefail

IMAGE="${1:-swr.ap-southeast-3.myhuaweicloud.com/agrichain/agrichain-backend:latest}"
SWR_HOST="${2:-swr.ap-southeast-3.myhuaweicloud.com}"
SWR_USER="${3:-}"
SWR_KEY="${4:-}"

echo ""
echo "========================================"
echo "  AgriChain ECS Deploy"
echo "  Image: $IMAGE"
echo "========================================"

# ─── 1. Install Docker if missing ────────────────────────
if ! command -v docker &>/dev/null; then
    echo "[1/5] Installing Docker..."
    apt-get update -qq
    apt-get install -y docker.io
    systemctl enable --now docker
else
    echo "[1/5] Docker already installed ✓"
fi

# ─── 2. Log in to SWR ────────────────────────────────────
if [ -n "$SWR_USER" ] && [ -n "$SWR_KEY" ]; then
    echo "[2/5] Logging in to SWR ($SWR_HOST)..."
    docker login -u "$SWR_USER" -p "$SWR_KEY" "$SWR_HOST"
else
    echo "[2/5] Skipping SWR login (credentials not provided)"
fi

# ─── 3. Pull the image ───────────────────────────────────
echo "[3/5] Pulling image..."
docker pull "$IMAGE"

# ─── 4. Restart container ────────────────────────────────
echo "[4/5] Starting container..."
docker stop agrichain-api 2>/dev/null || true
docker rm   agrichain-api 2>/dev/null || true

docker run -d \
  --name agrichain-api \
  --restart unless-stopped \
  -p 8000:8000 \
  -e FABRIC_MODE=mock \
  "$IMAGE"

# ─── 5. Health check ─────────────────────────────────────
echo "[5/5] Waiting for backend to start..."
sleep 5

if curl -sf http://localhost:8000/health | grep -q '"ok"'; then
    echo ""
    echo "✓ Backend is healthy!"
    curl -s http://localhost:8000/health
    echo ""
    echo "Endpoints:"
    echo "  http://$(curl -s ifconfig.me):8000/health"
    echo "  http://$(curl -s ifconfig.me):8000/docs"
    echo "  http://$(curl -s ifconfig.me):8000/blockchain/market/crop/Maize"
else
    echo "✗ Health check failed — check logs:"
    docker logs agrichain-api --tail 30
    exit 1
fi
