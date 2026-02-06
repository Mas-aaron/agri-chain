# 🚀 AgriYield Platform - Complete Deployment Guide

## 📋 Prerequisites

### 1. Accounts & Access
- [ ] Huawei Cloud Account with billing enabled
- [ ] Ethereum Wallet (MetaMask) with test ETH
- [ ] IPFS Node (or use Pinata/Infura)
- [ ] Domain name for production

### 2. Software Requirements
- [ ] Docker & Docker Compose
- [ ] Node.js 16+ & npm/yarn
- [ ] Go 1.18+
- [ ] Python 3.9+
- [ ] Terraform 1.3+
- [ ] Huawei Cloud CLI
- [ ] Kubernetes CLI (kubectl)

## 🏗️ Phase 1: Infrastructure Setup

### Step 1.1: Deploy Huawei BCS

```bash
# 1. Clone repository
git clone https://github.com/agriyield/blockchain-platform.git
cd blockchain-platform

# 2. Configure Huawei Cloud credentials
export HW_ACCESS_KEY="your-access-key"
export HW_SECRET_KEY="your-secret-key"
export HW_REGION="ap-southeast-1"

# 3. Initialize Terraform
cd 1-bcs-deployment/terraform
terraform init

# 4. Deploy infrastructure
terraform apply -auto-approve

# 5. Save outputs
terraform output -json > ../outputs.json
```

### Step 1.2: Configure IAM & Permissions

1. Login to Huawei Cloud Console
2. Navigate to **IAM → Users**
3. Create user: `agriyield-admin`
4. Assign policies:
   - BCS Administrator
   - CCE Administrator
   - VPC Administrator
   - EVS Administrator

## 🔗 Phase 2: Chaincode Deployment

### Step 2.1: Package Chaincode

```bash
cd 2-chaincode
bash scripts/package-chaincode.sh
```

### Step 2.2: Install on BCS

1. Login to BCS Console
2. Navigate to **Chaincode Management**
3. Click **Install Chaincode**
4. Upload: `agri-yield-chaincode-v1.0.zip`
5. Configure:
   - Name: `agri_yield`
   - Version: `1.0`
   - Language: `Go`

## 🚀 Phase 3: Backend Services

### Step 3.1: Configure Environment

```bash
cd 3-backend-services
cp .env.example .env

# Edit .env with your values
nano .env
```

### Step 3.2: Start Services

```bash
# Start all services
docker-compose up -d

# Verify services
docker-compose ps

# View logs
docker-compose logs -f ml-integration
```

## 🌐 Phase 4: Frontend Deployment

### Step 4.1: Build React App

```bash
cd 4-frontend/farmer-portal

# Install dependencies
npm install

# Configure environment
cp .env.example .env.local

# Build for production
npm run build
```

## 🔐 Security Checklist

### [ ] Network Security
- [ ] Configure VPC security groups
- [ ] Enable DDoS protection
- [ ] Set up WAF for API gateway
- [ ] Configure SSL/TLS certificates

### [ ] Access Control
- [ ] Implement JWT authentication
- [ ] Set up API rate limiting
- [ ] Configure CORS policies
- [ ] Enable audit logging

### [ ] Data Protection
- [ ] Encrypt data at rest (AES-256)
- [ ] Encrypt data in transit (TLS 1.3)
- [ ] Implement key rotation
- [ ] Regular security audits

## 📈 Production Scaling

### Auto-scaling Configuration

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ml-integration-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ml-integration
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## 🆘 Troubleshooting

### Common Issues & Solutions

#### Issue 1: BCS Instance Creation Fails
**Solution:** Check IAM permissions and resource quotas
```bash
hwcloud iam list-permissions --user-name agriyield-admin
hwcloud bcs quota list
```

#### Issue 2: Chaincode Instantiation Fails
**Solution:** Check channel configuration and endorsements
```bash
hwcloud bcs channel list --instance-id <instance-id>
hwcloud bcs chaincode list --instance-id <instance-id>
```

#### Issue 3: High Latency in Transactions
**Solution:** Optimize block generation parameters
```yaml
block_generation:
  transaction_quantity: 500
  generate_block_time: 1
```

## 📞 Support

### Contact Information
- **Technical Support**: support@agriyield.io
- **Documentation**: https://docs.agriyield.io

### Maintenance Windows
- **Weekly**: Sunday 02:00-04:00 UTC
- **Monthly**: First Saturday of each month

## 🎉 Congratulations!

Your AgriYield platform is now deployed and ready for production!

**Next Steps:**
1. Onboard first farmers
2. Connect ML model endpoints
3. Integrate with banking partners
4. Launch mobile app
5. Scale to new regions
