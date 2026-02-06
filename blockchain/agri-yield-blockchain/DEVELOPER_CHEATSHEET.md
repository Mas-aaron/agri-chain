# 🎯 Developer Cheat Sheet

Quick reference for common tasks in AgriYield development.

---

## ⚡ Start Development Immediately

### Option A: Frontend Only
```bash
cd 4-frontend && flutter run -d chrome
```
**Time**: 2 minutes | **Running at**: http://localhost:4200

### Option B: Frontend + Backend
```bash
# Terminal 1:
cd 3-backend-services && docker-compose up

# Terminal 2:
cd 4-frontend && flutter run -d chrome
```
**Time**: 5 minutes | **Frontend**: http://localhost:4200 | **API**: http://localhost:3000

### Option C: Everything
```bash
# Follow all 3 paths from GETTING_STARTED_QUICK.md
```
**Time**: 20 minutes | **Full stack ready**

---

## 🔧 Frontend Commands

### Running
```bash
flutter run -d chrome           # Web
flutter run                     # Android/iOS (auto-select)
flutter run -d iphone-simulator # iOS (macOS only)
flutter run --profile           # Performance mode
flutter run --release           # Release mode
```

### Development
```bash
flutter pub get                 # Install dependencies
flutter pub upgrade             # Update packages
flutter clean                   # Clear cache
flutter analyze                 # Check code quality
dart format lib/               # Format code
flutter test                   # Run tests
flutter pub run build_runner build  # Generate code
```

### Building
```bash
flutter build web --release     # Web → build/web/
flutter build apk --release     # Android APK
flutter build appbundle --release  # Android App Bundle
flutter build ios --release     # iOS (macOS only)
flutter build windows --release # Windows
flutter build macos --release   # macOS
flutter build linux --release   # Linux
```

### Debugging
```bash
flutter run -v                  # Verbose output
flutter logs                    # View device logs
flutter attach                  # Attach to running app
flutter devices                 # List connected devices
```

---

## 🐳 Backend Commands

### Docker Services
```bash
docker-compose up               # Start all services
docker-compose up -d            # Start in background
docker-compose down             # Stop all services
docker-compose down -v          # Stop & remove volumes
docker-compose logs -f          # View logs
docker-compose logs -f api-gateway  # View specific service
docker-compose restart api-gateway  # Restart service
docker-compose build            # Rebuild images
```

### Checking Services
```bash
curl http://localhost:3000/health      # API Gateway
curl http://localhost:5000/health      # ML Integration
curl http://localhost:5001/health      # Oracle Service
```

### Database
```bash
docker-compose exec postgres psql -U admin  # Connect to DB
docker-compose exec postgres pg_dump -U admin > backup.sql  # Backup
```

---

## 📂 Key File Locations

### Frontend Configuration
```
4-frontend/lib/utils/constants.dart     # API endpoints, blockchain config
4-frontend/lib/config/theme.dart        # Colors, fonts, styles
4-frontend/lib/routes/app_router.dart   # Navigation routes
4-frontend/pubspec.yaml                 # Dependencies
```

### Backend Configuration
```
3-backend-services/.env                 # Environment variables
3-backend-services/docker-compose.yml   # Service definitions
3-backend-services/api-gateway/config   # API configuration
```

### Smart Contracts
```
2-chaincode/go/agri_yield.go           # Main chaincode
2-chaincode/smart-contracts/EthereumBridge.sol  # Bridge contract
```

---

## 🔄 Common Development Workflows

### Adding a New Screen
```bash
# 1. Create the file
touch 4-frontend/lib/screens/new_feature/new_screen.dart

# 2. Add route
# Edit: 4-frontend/lib/routes/app_router.dart
GoRoute(
  path: '/new-feature',
  builder: (context, state) => const NewScreen(),
),

# 3. Add navigation
context.go('/new-feature');

# 4. Test
flutter run -d chrome
```

### Adding an API Call
```bash
# 1. Create method in ApiService
# Edit: 4-frontend/lib/services/api_service.dart
static Future<List<Data>> getData() async {
  final response = await http.get(Uri.parse('$baseUrl/data'));
  if (response.statusCode == 200) {
    return parseData(response.body);
  } else {
    throw Exception('Failed to load data');
  }
}

# 2. Call from widget
final data = await ApiService().getData();

# 3. Test with curl
curl http://localhost:3000/api/data
```

### Connecting to Blockchain
```bash
# 1. Update constants
# Edit: 4-frontend/lib/utils/constants.dart
static const String rpcUrl = 'http://your-rpc:8545';
static const String contractAddress = '0x...';

# 2. Use Web3Service
final web3 = Web3Service();
await web3.initialize(contractAddress, userAddress);
final balance = await web3.getBalance();

# 3. Call contracts
await web3.callContractFunction('functionName', [params]);
```

---

## 📊 API Endpoints Reference

### Assets
```bash
GET    /api/assets                 # Get all assets
GET    /api/assets/:id             # Get specific asset
POST   /api/assets                 # Create asset
PUT    /api/assets/:id             # Update asset
DELETE /api/assets/:id             # Delete asset
```

### Predictions
```bash
POST   /api/predict                # Get ML prediction
GET    /api/models                 # List available models
POST   /api/predict/batch          # Batch predictions
```

### User
```bash
POST   /api/auth/login             # Login
POST   /api/auth/signup            # Register
POST   /api/auth/logout            # Logout
GET    /api/user/profile           # Get profile
PUT    /api/user/profile           # Update profile
```

---

## 🐛 Debugging Tips

### Frontend Issues
```bash
# Check logs
flutter logs

# Check code
flutter analyze

# Run tests
flutter test

# Debug in IDE
# Set breakpoints and use:
flutter run -d chrome --verbose
```

### Backend Issues
```bash
# Check service logs
docker-compose logs -f service-name

# Check database
docker-compose exec postgres psql -U admin

# Restart service
docker-compose restart service-name

# Test endpoint
curl -X GET http://localhost:3000/api/endpoint \
  -H "Content-Type: application/json"
```

### Docker Issues
```bash
# List all containers
docker ps -a

# View image layers
docker inspect image-name

# Clean up unused images
docker image prune

# Check disk usage
docker system df
```

---

## 🔐 Security Reminders

### Before Committing
- [ ] Remove `.env` files (add to `.gitignore`)
- [ ] Remove hardcoded API keys
- [ ] Remove test/debug code
- [ ] Run `flutter analyze`
- [ ] Check for secrets in git history

### Before Deploying
- [ ] Use HTTPS for all APIs
- [ ] Set strong environment variables
- [ ] Enable rate limiting
- [ ] Set up monitoring/alerts
- [ ] Review security audit report

### Local Development
```bash
# Create .env file (not in git)
API_KEY=your_key_here
SECRET=your_secret_here

# Use it in code
final apiKey = dotenv.env['API_KEY'];
```

---

## 📈 Performance Optimization

### Frontend
```bash
# Profile app
flutter run --profile

# Check bundle size
flutter build web --release
du -sh build/web

# Optimize images
# Use Image.asset() with const
# Use Image.network() with caching
```

### Backend
```bash
# Monitor performance
docker stats

# Check slow queries
docker-compose logs api-gateway | grep SLOW

# Optimize database
docker-compose exec postgres psql -U admin
\d  # List tables
SELECT * FROM pg_stat_statements;
```

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All tests passing: `flutter test`
- [ ] Code analysis clean: `flutter analyze`
- [ ] No console errors in app
- [ ] API endpoints verified
- [ ] Blockchain network set correctly
- [ ] Environment variables configured
- [ ] Security audit passed

### Backend Deployment
```bash
# Build Docker images
docker-compose build --no-cache

# Push to registry
docker tag agriyield-api:latest registry.com/agriyield-api:v1.0
docker push registry.com/agriyield-api:v1.0

# Deploy
kubectl apply -f deployment.yaml
```

### Frontend Deployment
```bash
# Build for web
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy

# Or to other services
aws s3 sync build/web s3://bucket-name
netlify deploy --prod --dir=build/web
```

---

## 🆘 Emergency Commands

### Restore Everything
```bash
# Clean complete state
cd 4-frontend && flutter clean && flutter pub get
cd 3-backend-services && docker-compose down -v && docker-compose up

# Rebuild from scratch
docker system prune -a
docker-compose build --no-cache
docker-compose up
```

### Emergency Rollback
```bash
# If update broke something
git revert HEAD
docker-compose down -v
docker-compose up

# Or restore from backup
git reset --hard HEAD~1
```

### Debug Database Issues
```bash
# Backup before making changes
docker-compose exec postgres pg_dump -U admin > backup.sql

# List databases
docker-compose exec postgres psql -U admin -l

# Drop and recreate
docker-compose exec postgres dropdb -U admin agriyield
docker-compose exec postgres createdb -U admin agriyield

# Restore from backup
docker-compose exec -T postgres psql -U admin < backup.sql
```

---

## 📖 Quick Reference Links

| Item | Link |
|------|------|
| Flutter Docs | https://flutter.dev/docs |
| Dart Docs | https://dart.dev |
| Flutter Packages | https://pub.dev |
| Material Design 3 | https://m3.material.io |
| Docker Docs | https://docs.docker.com |
| Node.js Docs | https://nodejs.org/docs |

---

## 💡 Pro Tips

1. **Use VS Code Extensions**
   - Flutter
   - Dart
   - Docker
   - REST Client

2. **Hot Reload for Speed**
   - Press `r` in terminal to hot reload
   - Press `R` to hot restart

3. **Test as You Code**
   - Write tests alongside features
   - Run `flutter test` before committing

4. **Use Version Control**
   - Commit frequently
   - Write meaningful commit messages
   - Use branches for features

5. **Monitor Production**
   - Set up error tracking (Sentry)
   - Set up analytics (Firebase)
   - Set up performance monitoring

---

## 📝 Common Git Commands

```bash
# Create feature branch
git checkout -b feature/new-feature

# View changes
git diff

# Stage changes
git add .

# Commit
git commit -m "feat: add new feature"

# Push
git push origin feature/new-feature

# Create pull request
# (On GitHub/GitLab)

# Update branch
git rebase main

# Merge to main
git merge feature/new-feature
```

---

**Save this file for quick reference during development!**

For more details, see the comprehensive guides in the documentation folder.
