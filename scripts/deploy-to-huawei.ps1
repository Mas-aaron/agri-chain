# ============================================================
#  AgriChain — Huawei Cloud Deployment Script (Windows)
#  Run from:  agri-chain\  (the repo root)
# ============================================================

param(
    [string]$Region    = "la-south-2",
    [string]$Namespace = "agrichain",
    [string]$Account   = "la-south-2@HST3USJ7ZJCYRQJ20YM3",
    [string]$LoginKey  = "86ac0e55a6bfeef59320d0696fa0217284f2cc361baf4232d33f8c268d99debe",
    [string]$EcsIp     = "101.44.10.153"
)

$SWR_HOST  = "swr.$Region.myhuaweicloud.com"
$IMAGE_TAG = "$SWR_HOST/$Namespace/agrichain-backend:latest"

Write-Host "============================" -ForegroundColor Cyan
Write-Host " AgriChain Deployment Tool " -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host "SWR Host : $SWR_HOST"
Write-Host "Image    : $IMAGE_TAG"
Write-Host ""

# 1. Build
Write-Host "STEP 1: Building Docker image..." -ForegroundColor Yellow
docker build -t agrichain-backend:latest .\backend\backend\
if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }
Write-Host "Done." -ForegroundColor Green

# 2. SWR Login
Write-Host "STEP 2: Logging in to SWR..." -ForegroundColor Yellow
docker login -u "$Account" -p "$LoginKey" $SWR_HOST
if ($LASTEXITCODE -ne 0) { throw "SWR login failed" }
Write-Host "Done." -ForegroundColor Green

# 3. Push
Write-Host "STEP 3: Pushing to SWR..." -ForegroundColor Yellow
docker tag agrichain-backend:latest $IMAGE_TAG
docker push $IMAGE_TAG
if ($LASTEXITCODE -ne 0) { throw "Push failed" }
Write-Host "Done." -ForegroundColor Green

# 4. Instructions
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "FINAL STEP: Run these commands on ECS:" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "ssh root@$EcsIp"
Write-Host "docker stop agrichain-api"
Write-Host "docker rm agrichain-api"
Write-Host "docker pull $IMAGE_TAG"
Write-Host "docker run -d --name agrichain-api -p 8000:8000 \`
  -e FABRIC_MODE=gateway \`
  -e FABRIC_PEER_ENDPOINT=176.52.136.255:30605 \`
  -e FABRIC_MSP_ID=4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8MSP \`
  -e FABRIC_TLS_CERT_PATH='/certs/4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.peer/msp/tlscacerts/tlsca.4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8-cert.pem' \`
  -e FABRIC_CERT_PATH='/certs/4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.peer/msp/signcerts/User1@4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.peer-4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.default.svc.cluster.local-cert.pem' \`
  -e FABRIC_KEY_PATH='/certs/4fb93bc25f09757ebce82ba0f602c11c5d1cfcf8.peer/msp/keystore/6782ff17-f6d8-c826-0f61-62b04f3a56e4_sk' \`
  -e FABRIC_CHANNEL=yieldchannel \`
  -e FABRIC_CHAINCODE=agriyeild \`
  -v /root/bcs-certs:/certs:ro $IMAGE_TAG"
Write-Host ""
Write-Host "Check health: http://$EcsIp:8000/health"
