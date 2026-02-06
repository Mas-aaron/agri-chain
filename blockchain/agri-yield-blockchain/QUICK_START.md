# 🚀 AgriYield - Complete Quick Start Guide

**Last Updated**: February 5, 2026  
**Status**: Full Stack Ready for Development

---

## 📋 Prerequisites

### System Requirements
- **OS**: Windows, macOS, or Linux
- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 20GB free space
- **Network**: Internet connection for package downloads

### Required Software

```bash
# Install these first:
✅ Node.js 16+ (for backend)
✅ Flutter 3.0+ (for frontend)
✅ Docker & Docker Compose (for full stack)
✅ Git
✅ Python 3.8+ (for ML services)
✅ Go 1.16+ (for chaincode)
```

**Verification:**
```bash
node --version      # Should be 16+
flutter --version   # Should be 3.0+
docker --version    # Should be 20+
git --version       # Should be 2.30+
python --version    # Should be 3.8+
```

---

## 🎯 Quick Start (5 Minutes)

### Option 1: Frontend Only (Quickest)

**Perfect for UI/UX development:**

```bash
# 1. Navigate to frontend
cd 4-frontend

# 2. Install dependencies
flutter pub get

# 3. Run on web
flutter run -d chrome

# Or run on Android emulator
flutter run
```

**✅ You'll see:**
- Splash screen loading
- Home portal selection
- Farmer dashboard with mock data

**Expected time**: 2-3 minutes

---

### Option 2: Frontend + Backend API (Recommended)

**For full-stack development with real data:**

```bash
# Terminal 1: Start Backend Services
cd 3-backend-services
docker-compose up

# Wait for services to start (1-2 minutes)
# You should see:
# ✓ api-gateway running on :3000
# ✓ ml-integration running on :5000
# ✓ oracle-service running on :5001

# Terminal 2: Start Frontend
cd 4-frontend
flutter pub get
flutter run -d chrome

# Navigate to http://localhost:4200
```

**✅ You'll have:**
- Backend API responding at http://localhost:3000
- ML service at http://localhost:5000
- Flutter app at http://localhost:4200

**Expected time**: 5-8 minutes

---

### Option 3: Full Stack (Complete System)

**All components including blockchain:**

```bash
# Terminal 1: Blockchain Network
cd 1-bcs-deployment
# Follow Huawei BCS setup in SETUP_GUIDE.md
# Or use local Hyperledger Fabric

# Terminal 2: Deploy Chaincode
cd 2-chaincode
./scripts/package-chaincode.sh

# Terminal 3: Backend Services
cd 3-backend-services
docker-compose up

# Terminal 4: Frontend
cd 4-frontend
flutter run -d chrome

# Terminal 5: Integrations (optional)
cd 5-integrations
# Set up Ethereum bridge, IoT, Banking APIs
```

**✅ Full system ready for:**
- Smart contract development
- End-to-end testing
- Production deployment

**Expected time**: 15-20 minutes

---

## 📁 Project Structure Quick Reference

```
agri-yield-blockchain/
│
├── 1-bcs-deployment/          ← Blockchain Infrastructure
│   ├── terraform/             ← Cloud provisioning
│   ├── helm-charts/           ← Kubernetes deployment
│   └── scripts/               ← Helper scripts
│
├── 2-chaincode/               ← Smart Contracts
│   ├── go/                    ← Hyperledger Fabric chaincode
│   ├── smart-contracts/       ← Solidity contracts
│   └── tests/                 ← Contract tests
│
├── 3-backend-services/        ← REST APIs & Services
│   ├── docker-compose.yml     ← Start all services
│   ├── api-gateway/           ← Main REST API (port 3000)
│   ├── ml-integration/        ← ML predictions (port 5000)
│   ├── oracle-service/        ← Data feeds (port 5001)
│   └── identity-service/      ← User management
│
├── 4-frontend/                ← Flutter App ⭐ (NEW)
│   ├── lib/                   ← Flutter source code
│   ├── pubspec.yaml           ← Dependencies
│   ├── SETUP_GUIDE.md         ← Installation steps
│   └── MIGRATION_CHECKLIST.md ← Development tasks
│
├── 5-integrations/            ← External Services
│   ├── ethereum-bridge/       ← Cross-chain bridge
│   ├── bank-api/              ← Banking integration
│   └── iot-rover/             ← Hardware sensors
│
└── 6-documentation/           ← Guides & Specs
    ├── api-docs/              ← API specification
    ├── deployment-guide/      ← Setup instructions
    └── security-audit/        ← Security docs
```

---

## 🔧 Component-by-Component Setup

### 1️⃣ Frontend (Flutter) - START HERE ⭐

**Setup Time: 3-5 minutes**

```bash
cd 4-frontend

# Install dependencies
flutter pub get

# Check Flutter installation
flutter doctor

# Run on desired platform
flutter run -d chrome          # Web
flutter run -d android-emulator # Android
flutter run -d iphone-simulator # iOS (macOS only)
```

**Configuration:**
- Update API URL in `lib/utils/constants.dart`
- Line: `static const String apiBaseUrl = 'http://localhost:3000/api'`

**Troubleshooting:**
```bash
flutter clean                  # Clear cache
flutter pub get               # Reinstall packages
dart format lib/              # Format code
flutter analyze               # Check for issues
```

---

### 2️⃣ Backend Services - Docker Compose

**Setup Time: 2-3 minutes**

```bash
cd 3-backend-services

# Start all services
docker-compose up

# In another terminal, verify services
curl http://localhost:3000/health          # API Gateway
curl http://localhost:5000/health          # ML Service
curl http://localhost:5001/health          # Oracle Service
```

**Services Running:**
- **API Gateway**: http://localhost:3000
  - REST endpoints for assets, users, etc.
  - Connects to Hyperledger Fabric
  
- **ML Integration**: http://localhost:5000
  - Yield prediction models
  - Processes farmer data
  
- **Oracle Service**: http://localhost:5001
  - Real-world data feeds
  - Weather, market prices

**Environment Variables** (.env):
```env
NODE_ENV=development
DATABASE_URL=postgres://localhost:5432/agriyield
BLOCKCHAIN_RPC=http://localhost:8545
CONTRACT_ADDRESS=0x...
SECRET_KEY=your-secret-key
```

**Troubleshooting:**
```bash
# View logs
docker-compose logs -f

# Restart specific service
docker-compose restart api-gateway

# Stop all
docker-compose down

# Clean and restart
docker-compose down -v
docker-compose up
```

---

### 3️⃣ Smart Contracts (Chaincode)

**Setup Time: 5-10 minutes**

```bash
cd 2-chaincode

# Go Chaincode (Hyperledger Fabric)
cd go
go mod download
go test ./...

# Package chaincode
cd ../scripts
./package-chaincode.sh

# Solidity Contracts (Ethereum)
cd ../smart-contracts
npm install
npm run compile
npm run test
```

**Key Files:**
- `go/agri_yield.go` - Main chaincode for yield tokenization
- `smart-contracts/EthereumBridge.sol` - Cross-chain bridge
- `tests/` - Test files

---

### 4️⃣ Blockchain Infrastructure (Optional)

**Setup Time: 15+ minutes (Complex)**

```bash
cd 1-bcs-deployment

# Option A: Using Terraform
cd terraform
terraform init
terraform plan
terraform apply

# Option B: Using Helm Charts
cd ../helm-charts
helm install agriyield ./agri-yield-chart

# Option C: Local Hyperledger Fabric
# Install Fabric and CouchDB locally
# See 6-documentation/deployment-guide/DEPLOYMENT.md
```

---

## 📊 Full Stack Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND (Flutter)                       │
│                  http://localhost:4200                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Farmer Dashboard | Admin Portal | Mobile App       │   │
│  └────────────────┬──────────────────────────────────┘    │
└───────────────────┼──────────────────────────────────────────┘
                    │ REST API Calls
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                BACKEND SERVICES (Docker)                    │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ API Gateway (Node.js) - :3000                        │  │
│  │  • User management                                   │  │
│  │  • Asset CRUD operations                            │  │
│  │  • Blockchain interaction layer                     │  │
│  └──────────────┬──────────────────────────────────────┘  │
│                 │                                          │
│  ┌──────────────▼──────────────┐  ┌──────────────────┐   │
│  │ ML Integration (Python)     │  │ Oracle Service   │   │
│  │ :5000                       │  │ :5001            │   │
│  │ • Yield predictions         │  │ • Weather data   │   │
│  │ • Model inference           │  │ • Market prices  │   │
│  └─────────────────────────────┘  └──────────────────┘   │
│                 │                         │                │
└─────────────────┼─────────────────────────┼────────────────┘
                  │                         │
                  └────────────┬────────────┘
                               ↓
                ┌──────────────────────────────┐
                │   BLOCKCHAIN LAYER           │
                │                              │
                │ ┌──────────────────────────┐ │
                │ │ Hyperledger Fabric       │ │
                │ │ • Yield tokenization     │ │
                │ │ • Asset management       │ │
                │ │ • Loan collateral        │ │
                │ └──────────────────────────┘ │
                │                              │
                │ ┌──────────────────────────┐ │
                │ │ Ethereum (Cross-chain)   │ │
                │ │ • ERC-1155 Tokens        │ │
                │ │ • Bridge contracts       │ │
                │ └──────────────────────────┘ │
                │                              │
                └──────────────────────────────┘
```

---

## ✅ Verification Checklist

After setup, verify everything works:

### Frontend
```bash
# Test at http://localhost:4200
# ✓ Splash screen loads
# ✓ Home screen shows portals
# ✓ Farmer dashboard displays
# ✓ Mock data loads
# ✓ Charts render
```

### Backend
```bash
# Test each endpoint
curl http://localhost:3000/health              # Should return 200
curl http://localhost:3000/api/assets          # Should return data
curl http://localhost:5000/predict -X POST    # Should return predictions
curl http://localhost:5001/weather             # Should return weather
```

### Docker Services
```bash
docker ps        # Should show 3+ running containers
docker logs -f   # Check service logs for errors
```

---

## 🎯 Common Development Tasks

### Task 1: Change API Endpoint

**File**: `4-frontend/lib/utils/constants.dart`

```dart
// Before
static const String apiBaseUrl = 'http://localhost:3000/api';

// After
static const String apiBaseUrl = 'https://production-api.com/api';
```

### Task 2: Update Blockchain Configuration

**File**: `4-frontend/lib/utils/constants.dart`

```dart
static const String rpcUrl = 'http://localhost:8545';
static const String chainId = '1337';
static const String yieldTokenContractAddress = '0x...';
```

### Task 3: Run Tests

```bash
# Frontend tests
cd 4-frontend
flutter test

# Backend tests
cd 3-backend-services/api-gateway
npm test

# Smart contract tests
cd 2-chaincode
go test ./...
```

### Task 4: Build for Production

```bash
# Frontend - Web
cd 4-frontend
flutter build web --release
# Output: build/web/

# Frontend - Android
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Frontend - iOS
flutter build ios --release
# Output: build/ios/iphoneos/

# Backend - Docker image
cd 3-backend-services
docker build -t agriyield-api .
docker push your-registry/agriyield-api
```

---

## 📚 Next Steps

### Step 1: Get Familiar (Today)
- [ ] Run frontend with `flutter run -d chrome`
- [ ] Explore the app screens
- [ ] Review code in `4-frontend/lib/`

### Step 2: Connect to Backend (Tomorrow)
- [ ] Start services with `docker-compose up`
- [ ] Update API endpoints
- [ ] Test API calls

### Step 3: Implement Features (This Week)
- [ ] User authentication
- [ ] Blockchain wallet connection
- [ ] Asset tokenization flow
- [ ] Trading functionality

### Step 4: Deploy (Next Week)
- [ ] Set up CI/CD pipeline
- [ ] Deploy backend to cloud
- [ ] Release to app stores
- [ ] Monitor production

---

## 📖 Detailed Guides

For deeper dives, see these comprehensive guides:

| Document | Purpose |
|----------|---------|
| [4-frontend/README.md](4-frontend/README.md) | Flutter app overview |
| [4-frontend/SETUP_GUIDE.md](4-frontend/SETUP_GUIDE.md) | Detailed Flutter setup |
| [3-backend-services/README.md](3-backend-services/README.md) | Backend architecture |
| [6-documentation/deployment-guide/DEPLOYMENT.md](6-documentation/deployment-guide/DEPLOYMENT.md) | Full stack deployment |
| [6-documentation/api-docs/](6-documentation/api-docs/) | API specifications |
| [REACT_TO_FLUTTER_MIGRATION.md](REACT_TO_FLUTTER_MIGRATION.md) | Frontend migration details |

---

## 🆘 Troubleshooting

### Flutter Issues

**Problem**: Flutter not found
```bash
# Solution: Add Flutter to PATH
export PATH="$PATH:~/flutter/bin"
```

**Problem**: Port 4200 already in use
```bash
# Solution: Kill the process or use different port
lsof -i :4200
kill -9 <PID>
```

**Problem**: Dependencies not installing
```bash
# Solution: Clean and reinstall
flutter clean
flutter pub get
```

### Docker Issues

**Problem**: Docker daemon not running
```bash
# Solution: Start Docker daemon
# Windows/macOS: Open Docker Desktop
# Linux: systemctl start docker
```

**Problem**: Port conflicts
```bash
# Solution: Check and free ports
docker ps              # See running containers
docker-compose down    # Stop all services
```

### Backend Issues

**Problem**: API returning 500 errors
```bash
# Solution: Check logs
docker-compose logs -f api-gateway
docker-compose logs -f ml-integration
```

**Problem**: Database connection failed
```bash
# Solution: Reset database
docker-compose down -v
docker-compose up
```

---

## 🚀 Performance Tips

### Development
- Use hot reload: `flutter run` (auto-saves code changes)
- Use DevTools: `flutter pub global activate devtools`
- Profile app: `flutter run --profile`

### Backend
- Use caching: Redis for frequently accessed data
- Database indexes: On user_id, asset_id, created_at
- Load balancing: Multiple API instances with nginx

### Production
- Minify code: `flutter build web --release`
- Compress assets: Use gzip for API responses
- CDN: Serve static files from CloudFront/Cloudflare

---

## 📞 Support

**Getting Help:**

1. **Documentation**: Check [6-documentation/](6-documentation/)
2. **Code Examples**: See [4-frontend/DEVELOPMENT_PATTERNS.md](4-frontend/DEVELOPMENT_PATTERNS.md)
3. **Issues**: Create GitHub issue with:
   - Steps to reproduce
   - Expected vs actual behavior
   - Error messages/logs
   - System info (OS, versions)

---

## ✨ You're Ready!

**Choose your starting point:**

```bash
# Just want to see it work? (2 minutes)
cd 4-frontend && flutter run -d chrome

# Want full backend? (8 minutes)
# Terminal 1:
cd 3-backend-services && docker-compose up
# Terminal 2:
cd 4-frontend && flutter run -d chrome

# Want everything? (20 minutes)
# Follow "Full Stack" section above
```

**Then explore, modify, and build!** 🎉

---

**Happy coding! Questions? Check the documentation files or create an issue.**
