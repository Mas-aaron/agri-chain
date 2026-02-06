# AgriYield - Get Started in 3 Steps

## Choose Your Path

### 🎯 Path 1: Just See It Work (2 minutes)
**Perfect if you want a quick demo**

```bash
cd 4-frontend
flutter pub get
flutter run -d chrome
```

**What you'll see:**
- ✅ AgriYield Farmer Portal loading
- ✅ Mock data with yield assets
- ✅ Charts and portfolio metrics
- ✅ Beautiful Material Design 3 UI

---

### 💻 Path 2: Full Development Setup (8 minutes)
**Best for actual development work**

**Terminal 1 - Backend:**
```bash
cd 3-backend-services
docker-compose up
```

**Terminal 2 - Frontend:**
```bash
cd 4-frontend
flutter pub get
flutter run -d chrome
```

**Now you have:**
- ✅ Frontend at http://localhost:4200
- ✅ Backend API at http://localhost:3000
- ✅ ML Service at http://localhost:5000
- ✅ Oracle Service at http://localhost:5001

---

### 🚀 Path 3: Complete Production Setup (20 minutes)
**For testing entire system with blockchain**

**Step 1:** Deploy Infrastructure
```bash
cd 1-bcs-deployment/terraform
terraform init && terraform apply
```

**Step 2:** Deploy Chaincode
```bash
cd 2-chaincode
bash scripts/package-chaincode.sh
```

**Step 3:** Start Backend
```bash
cd 3-backend-services
docker-compose up
```

**Step 4:** Run Frontend
```bash
cd 4-frontend
flutter run -d chrome
```

---

## 🎯 What to Do Next

### Check the Frontend
```
http://localhost:4200
- Home screen → Select Farmer Portal
- Dashboard → See yield assets
- Charts → View data visualization
- Buttons → Trade and details (ready to implement)
```

### Test the Backend (in another terminal)
```bash
# Check API health
curl http://localhost:3000/health

# Get assets
curl http://localhost:3000/api/assets

# Get ML predictions
curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d '{"crop": "wheat", "data": {}}'
```

### Explore the Code

**Frontend Structure:**
```
4-frontend/lib/
├── main.dart              ← App entry point
├── screens/               ← All UI screens
├── services/              ← API & blockchain calls
├── models/                ← Data structures
└── utils/                 ← Helpers & constants
```

**Backend Structure:**
```
3-backend-services/
├── api-gateway/           ← REST API (Node.js)
├── ml-integration/        ← ML predictions (Python)
├── oracle-service/        ← Data feeds
└── docker-compose.yml     ← Start everything
```

---

## 📱 Common Tasks

### Change where API calls go
**File:** `4-frontend/lib/utils/constants.dart`
```dart
// Change this line:
static const String apiBaseUrl = 'http://YOUR_API:3000/api';
```

### See Flutter code changes instantly
```bash
cd 4-frontend
flutter run     # Press 'r' to reload, 'R' to restart
```

### View backend logs
```bash
docker-compose logs -f api-gateway    # API logs
docker-compose logs -f ml-integration # ML logs
```

### Run on Android emulator
```bash
cd 4-frontend
flutter devices                # List devices
flutter run -d emulator-5554   # Run on emulator
```

### Build for production
```bash
# Web
cd 4-frontend
flutter build web --release
# Outputs to: build/web/

# Android APK
flutter build apk --release
# Outputs to: build/app/outputs/flutter-apk/

# iOS (macOS only)
flutter build ios --release
```

---

## ✅ Verify Everything Works

### Frontend
- [ ] Open http://localhost:4200
- [ ] See splash screen → home screen
- [ ] Click "Farmer Portal"
- [ ] See dashboard with mock data
- [ ] Charts load and display

### Backend
- [ ] Run: `curl http://localhost:3000/health`
- [ ] Get response: `{"status":"ok"}`
- [ ] Run: `curl http://localhost:3000/api/assets`
- [ ] Get asset list (or empty array)

### Docker Services
- [ ] Run: `docker ps`
- [ ] See 3+ containers running
- [ ] No containers with "Exited" status

---

## 🆘 Quick Troubleshooting

### "Flutter not found"
```bash
# Add Flutter to your PATH:
export PATH="$PATH:~/flutter/bin"
```

### "Port already in use"
```bash
# Kill the process using the port
# Windows: netstat -ano | findstr :4200
# Mac/Linux: lsof -i :4200 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### "Docker daemon not running"
```bash
# Mac/Windows: Open Docker Desktop
# Linux: sudo systemctl start docker
```

### "Cannot get docker images"
```bash
# Make sure Docker is running, then:
docker-compose down
docker-compose up
```

### "Dependencies not installing"
```bash
cd 4-frontend
flutter clean
flutter pub get
```

---

## 📚 Full Documentation

For detailed setup and guides:

| Want to... | Read this |
|-----------|-----------|
| Set up Flutter | [4-frontend/SETUP_GUIDE.md](4-frontend/SETUP_GUIDE.md) |
| Understand architecture | [4-frontend/ARCHITECTURE.md](4-frontend/ARCHITECTURE.md) |
| Learn best practices | [4-frontend/DEVELOPMENT_PATTERNS.md](4-frontend/DEVELOPMENT_PATTERNS.md) |
| Deploy everything | [6-documentation/deployment-guide/DEPLOYMENT.md](6-documentation/deployment-guide/DEPLOYMENT.md) |
| Understand migration | [REACT_TO_FLUTTER_MIGRATION.md](REACT_TO_FLUTTER_MIGRATION.md) |
| Full checklist | [4-frontend/MIGRATION_CHECKLIST.md](4-frontend/MIGRATION_CHECKLIST.md) |

---

## 🎓 Learning Path

1. **Day 1: Run the App**
   - Get frontend working with `flutter run`
   - Explore the UI
   - Review the code

2. **Day 2: Connect Backend**
   - Start Docker services
   - Update API endpoints
   - Test API calls

3. **Day 3-4: Implement Features**
   - User authentication
   - Real API integration
   - Blockchain wallet connection

4. **Day 5+: Deploy**
   - Build for production
   - Deploy backend
   - Release to app stores

---

## 🚀 Ready? Start Here:

```bash
# Fastest start (right now)
cd 4-frontend && flutter pub get && flutter run -d chrome

# Or read the detailed guide
open QUICK_START.md
```

**Questions?** See [QUICK_START.md](QUICK_START.md) for comprehensive guide.

Happy coding! 🎉
