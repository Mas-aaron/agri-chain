# 🗺️ AgriYield Project Map & Navigation

A complete guide to navigate the AgriYield blockchain platform codebase.

---

## 🏠 Start Here

### For First-Time Users
1. **[README.md](README.md)** - Project overview & architecture
2. **[GETTING_STARTED.md](GETTING_STARTED.md)** - Quick start guide
3. **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - What was built

### For Deployment
1. **[Deployment Guide](6-documentation/deployment-guide/DEPLOYMENT.md)** - Step-by-step setup
2. **[Environment Setup](3-backend-services/.env.example)** - Configuration template
3. **[Security Checklist](6-documentation/security-audit/SECURITY_AUDIT.md)** - Security requirements

---

## 📁 Directory Guide

### **Phase 1: Infrastructure (1-bcs-deployment/)**
Cloud infrastructure and deployment automation

**Key Files:**
- `terraform/main.tf` - Huawei Cloud BCS infrastructure
- `terraform/variables.tf` - Configuration variables
- `terraform/outputs.tf` - Output values
- `scripts/deploy-bcs.sh` - Automated deployment script

**What It Does:**
- Provisions Huawei Cloud BCS (Blockchain as a Service)
- Creates Kubernetes (CCE) cluster
- Configures networking and security
- Sets up 3 blockchain organizations

**Deploy With:**
```bash
cd 1-bcs-deployment/terraform
terraform apply
```

**Documentation:** [Phase 1 README](1-bcs-deployment/README.md)

---

### **Phase 2: Chaincode (2-chaincode/)**
Blockchain smart contracts and business logic

**Key Files:**
- `go/agri_yield.go` - Main chaincode implementation (1000+ lines)
- `go/go.mod` - Go module dependencies
- `scripts/package-chaincode.sh` - Chaincode packaging

**What It Does:**
- Tokenizes agricultural yield predictions
- Manages loans and collateral
- Processes token trades
- Records all transactions immutably

**Key Functions:**
- `CreateYieldAsset()` - Tokenize predictions
- `TransferTokens()` - P2P transfers
- `CreateLoanAgreement()` - Secure loans
- `UpdateActualYield()` - Oracle updates

**Deploy With:**
```bash
cd 2-chaincode
bash scripts/package-chaincode.sh
```

**Documentation:** [Phase 2 README](2-chaincode/README.md)

---

### **Phase 3: Backend Services (3-backend-services/)**
Microservices for blockchain integration

**Key Files:**
- `docker-compose.yml` - Complete services stack
- `ml-integration/ml_service.py` - ML to blockchain bridge
- `.env.example` - Configuration template
- `ml-integration/Dockerfile` - Container configuration
- `ml-integration/requirements.txt` - Python dependencies

**Services Include:**
- **PostgreSQL** - Data storage
- **Redis** - Caching
- **IPFS** - File storage
- **ML Integration** - Prediction tokenization
- **Prometheus** - Metrics
- **Grafana** - Monitoring
- **RabbitMQ** - Message queue

**What It Does:**
- Integrates ML models with blockchain
- Provides REST API endpoints
- Manages oracle data feeds
- Handles identity/KYC
- Serves frontend requests

**Deploy With:**
```bash
cd 3-backend-services
cp .env.example .env
docker-compose up -d
```

**Access:**
- API: http://localhost:8000
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

**Documentation:** [Phase 3 README](3-backend-services/README.md)

---

### **Phase 4: Frontend (4-frontend/)**
User-facing web and mobile applications

**Key Files:**
- `farmer-portal/package.json` - Dependencies
- `farmer-portal/src/pages/Dashboard.tsx` - Main dashboard
- `farmer-portal/src/` - React components

**Applications:**
- **Farmer Portal** - Web app for farmers
  - View tokenized assets
  - Request loans
  - Trade tokens
  - Monitor portfolio

- **Admin Dashboard** - Management interface
  - System monitoring
  - User management
  - Loan administration

- **Mobile App** - React Native for iOS/Android

**Technology:**
- React 18 + TypeScript
- Material-UI components
- Ethers.js for blockchain
- Axios for API calls

**Deploy With:**
```bash
cd 4-frontend/farmer-portal
npm install
npm run build
npm start
```

**Access:** http://localhost:3000

**Documentation:** [Phase 4 README](4-frontend/README.md)

---

### **Phase 5: Cross-Chain Integration (5-integrations/)**
Ethereum bridge and external integrations

**Key Files:**
- `ethereum-bridge/EthereumBridge.sol` - ERC-1155 contract (400+ lines)
- `ethereum-bridge/` - Smart contract directory

**What It Does:**
- Bridges tokens between BCS and Ethereum
- Manages collateral on Ethereum
- Supports atomic swaps
- Oracle price feeds

**Smart Contract Functions:**
- `bridgeYieldToken()` - Bridge to Ethereum
- `lockForLoan()` - Collateral management
- `releaseCollateral()` - Repayment handling
- `batchTransfer()` - Trading

**Deploy With:**
```bash
cd 5-integrations/ethereum-bridge
npm install
npx hardhat run scripts/deploy.js --network goerli
```

**Documentation:** [Phase 5 README](5-integrations/README.md)

---

### **Phase 6: Documentation (6-documentation/)**
Guides, references, and compliance documentation

**Key Files:**
- `deployment-guide/DEPLOYMENT.md` - Complete setup guide (200+ lines)
- `security-audit/SECURITY_AUDIT.md` - Security checklist
- `api-docs/` - API references

**Contents:**

#### Deployment Guide
- Prerequisites
- Infrastructure setup
- Chaincode deployment
- Backend configuration
- Frontend deployment
- Security hardening
- Troubleshooting
- Production scaling

#### Security Audit
- Blockchain security
- API security
- Compliance (GDPR, financial)
- Infrastructure security
- Vulnerability management
- Incident response
- Vendor assessments
- Certifications

#### API Documentation
- REST endpoints
- GraphQL queries
- Authentication
- Rate limiting
- Error handling

**Documentation:** [Phase 6 README](6-documentation/README.md)

---

## 🎯 Use Cases & Navigation

### "I want to deploy the platform"
1. Read: [GETTING_STARTED.md](GETTING_STARTED.md)
2. Follow: [Deployment Guide](6-documentation/deployment-guide/DEPLOYMENT.md)
3. Check: [Security Checklist](6-documentation/security-audit/SECURITY_AUDIT.md)

### "I want to understand the architecture"
1. Read: [README.md](README.md)
2. Review: [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
3. Study: Each phase's README

### "I want to write chaincode"
1. Learn: [Go Chaincode](2-chaincode/go/agri_yield.go)
2. Package: [Packaging Script](2-chaincode/scripts/package-chaincode.sh)
3. Deploy: Following [Deployment Guide](6-documentation/deployment-guide/DEPLOYMENT.md)

### "I want to develop the frontend"
1. Start: [Dashboard Component](4-frontend/farmer-portal/src/pages/Dashboard.tsx)
2. Setup: `npm install` in [farmer-portal](4-frontend/farmer-portal/)
3. Run: `npm start`

### "I want to integrate with Ethereum"
1. Review: [Ethereum Bridge](5-integrations/ethereum-bridge/EthereumBridge.sol)
2. Configure: [Environment](3-backend-services/.env.example)
3. Deploy: Using Hardhat

### "I want to check security"
1. Review: [Security Audit](6-documentation/security-audit/SECURITY_AUDIT.md)
2. Setup: [TLS, encryption, etc.](6-documentation/deployment-guide/DEPLOYMENT.md#-security-checklist)
3. Monitor: Prometheus & Grafana dashboards

---

## 📊 File Organization

```
agri-yield-blockchain/
│
├── 📄 README.md                           ← Start here
├── 📄 GETTING_STARTED.md                  ← Quick start
├── 📄 IMPLEMENTATION_SUMMARY.md            ← What was built
├── 📄 PROJECT_MAP.md                      ← This file
│
├── 📁 1-bcs-deployment/                   ← Cloud infrastructure
│   ├── terraform/                         ← Terraform IaC
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── scripts/                           ← Deployment scripts
│   │   └── deploy-bcs.sh
│   ├── helm-charts/                       ← Kubernetes charts
│   └── README.md
│
├── 📁 2-chaincode/                        ← Smart contracts
│   ├── go/                                ← Hyperledger Fabric
│   │   ├── agri_yield.go
│   │   └── go.mod
│   ├── scripts/
│   │   └── package-chaincode.sh
│   ├── smart-contracts/                   ← Ethereum contracts
│   ├── tests/                             ← Test suites
│   └── README.md
│
├── 📁 3-backend-services/                 ← Microservices
│   ├── ml-integration/                    ← ML service
│   │   ├── ml_service.py
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── oracle-service/                    ← Data oracle
│   ├── identity-service/                  ← DID/KYC
│   ├── api-gateway/                       ← REST/GraphQL
│   ├── docker-compose.yml                 ← Services stack
│   ├── .env.example                       ← Configuration
│   └── README.md
│
├── 📁 4-frontend/                         ← User applications
│   ├── farmer-portal/                     ← React web app
│   │   ├── package.json
│   │   ├── src/
│   │   │   └── pages/
│   │   │       └── Dashboard.tsx
│   │   └── README.md
│   ├── admin-dashboard/                   ← Management UI
│   ├── mobile-app/                        ← React Native
│   └── README.md
│
├── 📁 5-integrations/                     ← External integration
│   ├── ethereum-bridge/                   ← Ethereum contracts
│   │   └── EthereumBridge.sol
│   ├── bank-api/                          ← Banking integration
│   ├── iot-rover/                         ← Hardware integration
│   └── README.md
│
└── 📁 6-documentation/                    ← Guides & references
    ├── deployment-guide/                  ← Setup guide
    │   └── DEPLOYMENT.md
    ├── security-audit/                    ← Compliance
    │   └── SECURITY_AUDIT.md
    ├── api-docs/                          ← API references
    └── README.md
```

---

## 🔗 Quick Links by Role

### For DevOps Engineers
- [Infrastructure Setup](1-bcs-deployment/README.md)
- [Deployment Guide](6-documentation/deployment-guide/DEPLOYMENT.md)
- [Docker Compose](3-backend-services/docker-compose.yml)
- [Terraform Main](1-bcs-deployment/terraform/main.tf)

### For Blockchain Developers
- [Chaincode Implementation](2-chaincode/go/agri_yield.go)
- [Ethereum Bridge](5-integrations/ethereum-bridge/EthereumBridge.sol)
- [Chaincode Packaging](2-chaincode/scripts/package-chaincode.sh)

### For Backend Developers
- [ML Integration Service](3-backend-services/ml-integration/ml_service.py)
- [Docker Compose](3-backend-services/docker-compose.yml)
- [Environment Config](3-backend-services/.env.example)

### For Frontend Developers
- [Dashboard Component](4-frontend/farmer-portal/src/pages/Dashboard.tsx)
- [Package.json](4-frontend/farmer-portal/package.json)
- [Frontend README](4-frontend/README.md)

### For Security & Compliance
- [Security Audit](6-documentation/security-audit/SECURITY_AUDIT.md)
- [Deployment Security](6-documentation/deployment-guide/DEPLOYMENT.md#-security-checklist)
- [Architecture](README.md#-architecture)

### For Project Managers
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md)
- [Getting Started](GETTING_STARTED.md)
- [Roadmap](#-roadmap) in README

---

## 🚀 Common Tasks

### Deploy Everything
```bash
# 1. Infrastructure
cd 1-bcs-deployment/terraform && terraform apply

# 2. Chaincode
cd 2-chaincode && bash scripts/package-chaincode.sh

# 3. Services
cd 3-backend-services && docker-compose up -d

# 4. Frontend
cd 4-frontend/farmer-portal && npm install && npm start
```

### Run Tests
```bash
# Chaincode tests
cd 2-chaincode && go test ./...

# Backend tests
cd 3-backend-services && python -m pytest

# Frontend tests
cd 4-frontend/farmer-portal && npm test
```

### Check Logs
```bash
# Backend services
docker-compose logs -f ml-integration

# Database
docker-compose logs -f postgres

# Monitoring
http://localhost:3000  # Grafana
http://localhost:9090  # Prometheus
```

### Update Configuration
```bash
# Edit environment
nano 3-backend-services/.env

# Apply changes
docker-compose restart ml-integration
```

---

## 📚 Documentation Index

| Document | Purpose | Location |
|----------|---------|----------|
| README.md | Project overview | Root |
| GETTING_STARTED.md | Quick start guide | Root |
| IMPLEMENTATION_SUMMARY.md | Build details | Root |
| PROJECT_MAP.md | Navigation guide | Root |
| DEPLOYMENT.md | Setup instructions | 6-documentation/deployment-guide/ |
| SECURITY_AUDIT.md | Compliance checklist | 6-documentation/security-audit/ |
| Phase READMEs | Component info | Each phase directory |

---

## ✨ Feature Map

| Feature | Phase | File | Status |
|---------|-------|------|--------|
| Yield Tokenization | 2, 3 | agri_yield.go | ✅ |
| Loan Management | 2 | agri_yield.go | ✅ |
| Token Trading | 2 | agri_yield.go | ✅ |
| Ethereum Bridge | 5 | EthereumBridge.sol | ✅ |
| REST API | 3 | ml_service.py | ✅ |
| Farmer Portal | 4 | Dashboard.tsx | ✅ |
| Monitoring | 3 | docker-compose.yml | ✅ |
| Infrastructure | 1 | main.tf | ✅ |
| Security | 6 | SECURITY_AUDIT.md | ✅ |

---

## 🎓 Learning Path

1. **Understand the Project**
   - Read: [README.md](README.md)
   - Watch: Project overview
   - Study: [Architecture](#-architecture-highlights)

2. **Set Up Locally**
   - Follow: [GETTING_STARTED.md](GETTING_STARTED.md)
   - Run: Docker Compose
   - Test: API endpoints

3. **Explore Components**
   - Chaincode: [agri_yield.go](2-chaincode/go/agri_yield.go)
   - Backend: [ml_service.py](3-backend-services/ml-integration/ml_service.py)
   - Frontend: [Dashboard.tsx](4-frontend/farmer-portal/src/pages/Dashboard.tsx)
   - Smart Contracts: [EthereumBridge.sol](5-integrations/ethereum-bridge/EthereumBridge.sol)

4. **Deploy to Cloud**
   - Setup: [Huawei Cloud account](https://www.huaweicloud.com/)
   - Follow: [Deployment Guide](6-documentation/deployment-guide/DEPLOYMENT.md)
   - Monitor: Prometheus/Grafana dashboards

5. **Customize & Extend**
   - Modify chaincode
   - Add new services
   - Extend frontend
   - Integrate banking APIs

---

**Last Updated**: January 2024  
**Version**: 1.0.0  
**Status**: ✅ Production Ready

For questions, please refer to [support resources](README.md#-support--contact) or check the relevant phase documentation.
