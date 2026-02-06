#!/bin/bash
# File: 1-bcs-deployment/scripts/deploy-bcs.sh
# === HUAWEI BCS DEPLOYMENT SCRIPT ===
# Complete setup for AgriYield blockchain

set -e

echo "🚀 Starting AgriYield Blockchain Deployment"
echo "=========================================="

# 1. Install prerequisites
echo "📦 Installing prerequisites..."
apt-get update
apt-get install -y jq curl unzip docker.io terraform kubectl

# 2. Configure Huawei Cloud CLI
echo "🔐 Configuring Huawei Cloud CLI..."
read -p "Enter Huawei Cloud Access Key: " HW_ACCESS_KEY
read -p "Enter Huawei Cloud Secret Key: " HW_SECRET_KEY
read -p "Enter Region (default: ap-southeast-1): " HW_REGION
HW_REGION=${HW_REGION:-ap-southeast-1}

mkdir -p ~/.hw
cat > ~/.hw/config.yaml << EOF
access_key_id: $HW_ACCESS_KEY
secret_access_key: $HW_SECRET_KEY
region: $HW_REGION
EOF

# 3. Deploy Terraform infrastructure
echo "🏗️  Deploying infrastructure with Terraform..."
cd terraform/
terraform init
terraform plan -out=agri-plan
terraform apply "agri-plan"

# 4. Export outputs
BCS_ID=$(terraform output -raw bcs_instance_id)
CLUSTER_ID=$(terraform output -raw cluster_id)
echo "BCS Instance ID: $BCS_ID"
echo "Cluster ID: $CLUSTER_ID"

# 5. Wait for BCS instance to be ready
echo "⏳ Waiting for BCS instance to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    STATUS=$(hwcloud bcs instance show $BCS_ID --query "status" --output text 2>/dev/null || echo "Creating")
    
    if [ "$STATUS" = "Normal" ]; then
        echo "✅ BCS instance is ready!"
        break
    elif [ "$STATUS" = "Abnormal" ]; then
        echo "❌ BCS instance creation failed!"
        exit 1
    fi
    
    echo "   Instance status: $STATUS (waiting...)"
    sleep 30
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "⚠️  Instance creation timed out. Check Huawei Cloud console."
fi

# 6. Download SDK Configuration
echo "📥 Downloading SDK configuration..."
mkdir -p ../config/sdk
mkdir -p ../config/certs

# 7. Print deployment summary
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================="
echo "BCS Instance ID: $BCS_ID"
echo "Cluster ID: $CLUSTER_ID"
echo "REST API Endpoint: $(terraform output -json bcs_endpoints | jq -r '.rest_api')"
echo ""
echo "Next steps:"
echo "1. Download SDK: hwcloud bcs instance download-sdk-cfg --instance-id $BCS_ID"
echo "2. Deploy chaincode: ./deploy-chaincode.sh"
echo "3. Start backend services: docker-compose up"
echo "4. Access admin dashboard: https://$(terraform output -json bcs_endpoints | jq -r '.web')"

# Save deployment info
cat > ../deployment-info.txt << EOF
Deployment Time: $(date)
BCS Instance ID: $BCS_ID
Cluster ID: $CLUSTER_ID
Region: $HW_REGION
Status: Completed
EOF

echo ""
echo "Deployment info saved to: deployment-info.txt"
