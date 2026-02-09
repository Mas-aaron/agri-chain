# Blockchain Backend Deployment Guide

Deploy the AgriYield blockchain backend to `http://localhost:3000/api` for local development or testing.

---

## 📋 Prerequisites

### Required Software
- **Docker** (20.10+) - Container runtime
- **Docker Compose** (2.0+) - Container orchestration
- **Git** - Version control
- **Python** 3.11+ (optional, for local development)

### Installation

#### Windows
```powershell
# Install Docker Desktop (includes Docker Compose)
# Download from: https://www.docker.com/products/docker-desktop
# Run installer and follow setup

# Verify installation
docker --version
docker-compose --version
```

#### macOS
```bash
# Install using Homebrew
brew install docker docker-compose

# Or install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Verify installation
docker --version
docker-compose --version
```

#### Linux (Ubuntu/Debian)
```bash
# Install Docker
sudo apt-get update
sudo apt-get install docker.io docker-compose

# Add user to docker group
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker-compose --version
```

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Navigate to Backend Services
```bash
cd blockchain/agri-yield-blockchain/3-backend-services
```

### Step 2: Create Environment File
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your settings (optional for local dev)
# Default values work for local development
```

### Step 3: Start Backend Services
```bash
# Build and start all services
docker-compose up -d

# Or with logs visible (don't use -d)
docker-compose up
```

### Step 4: Verify Services are Running
```bash
# Check service status
docker-compose ps

# Expected output:
# NAME                  STATUS
# postgres              Up (healthy)
# redis                 Up
# ipfs                  Up
# ml-integration        Up
# prometheus            Up
# grafana               Up
# rabbitmq              Up
```

### Step 5: Test API Endpoint
```bash
# Health check
curl http://localhost:8000/health

# Expected response:
# {"status":"healthy","service":"ml-integration","timestamp":"..."}
```

### Step 6: Configure Flutter App
Edit `lib/features/blockchain/config/blockchain_config.dart`:
```dart
static const String apiBaseUrl = 'http://localhost:8000/api';
```

### Step 7: Run Flutter App
```bash
cd agri-chain
flutter run
```

---

## 📦 Service Architecture

### Services Running on Docker

| Service | Port | Purpose | URL |
|---------|------|---------|-----|
| **ML Integration** | 8000 | Main API service | http://localhost:8000 |
| **PostgreSQL** | 5432 | Database | postgres://admin:admin123@localhost:5432/agriyield |
| **Redis** | 6379 | Cache | redis://localhost:6379 |
| **IPFS** | 5001 | Decentralized storage | /ip4/127.0.0.1/tcp/5001 |
| **Prometheus** | 9090 | Metrics | http://localhost:9090 |
| **Grafana** | 3000 | Dashboards | http://localhost:3000 |
| **RabbitMQ** | 5672 | Message queue | amqp://admin:admin@localhost:5672 |
| **RabbitMQ Admin** | 15672 | Management UI | http://localhost:15672 |

---

## ⚙️ Configuration

### Environment Variables

Create or edit `.env` file:

```bash
# Database
DB_PASSWORD=admin123
DB_NAME=agriyield

# Blockchain/Huawei Cloud
BCS_INSTANCE_ID=your-instance-id       # Replace with actual value
BCS_ACCESS_KEY=your-access-key         # Replace with actual value
BCS_SECRET_KEY=your-secret-key         # Replace with actual value

# Ethereum (optional)
ETHEREUM_RPC=http://localhost:8545
ETHEREUM_PRIVATE_KEY=your-private-key

# Monitoring
GRAFANA_PASSWORD=admin
GRAFANA_USER=admin

# Optional: Custom ML model endpoint
ML_MODEL_ENDPOINT=http://localhost:5000/predict
```

### Default Values (for development)
```env
DB_HOST=postgres
DB_USER=admin
DB_PASSWORD=admin123
DB_NAME=agriyield

API_HOST=0.0.0.0
API_PORT=8000

REDIS_HOST=redis
IPFS_HOST=ipfs

# These are optional for basic testing:
BCS_INSTANCE_ID=test-instance
BCS_ACCESS_KEY=test-key
BCS_SECRET_KEY=test-secret
```

---

## 🔨 Common Commands

### Start Services
```bash
# Start in background
docker-compose up -d

# Start with logs visible
docker-compose up

# Start specific service
docker-compose up -d postgres redis
```

### Stop Services
```bash
# Stop all services
docker-compose down

# Stop without removing volumes
docker-compose stop

# Stop specific service
docker-compose stop ml-integration
```

### View Logs
```bash
# View all logs
docker-compose logs

# Follow logs (live)
docker-compose logs -f

# View specific service logs
docker-compose logs ml-integration

# Last 100 lines
docker-compose logs --tail=100
```

### Check Status
```bash
# List running containers
docker-compose ps

# Container details
docker-compose exec ml-integration ps aux

# Resource usage
docker stats
```

### Database Operations
```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U admin -d agriyield

# Useful SQL commands:
# \dt                    # List tables
# \q                     # Quit
```

### Rebuild Services
```bash
# Rebuild without cache
docker-compose build --no-cache

# Rebuild and restart
docker-compose up -d --build
```

---

## 🔌 API Endpoints

### Base URL
```
http://localhost:8000
```

### Available Endpoints

#### Health Check
```
GET /health
Response: {"status":"healthy","service":"ml-integration"}
```

#### Tokenize Yield
```
POST /api/v1/tokenize-yield
Body: {
  "prediction": {
    "farm_id": "FARM_001",
    "farmer_id": "FARMER_001",
    "crop_type": "Wheat",
    "season": 2024,
    "predicted_yield_kg": 5000,
    "confidence": 0.85,
    "prediction_date": "2024-02-06T10:00:00Z",
    "model_version": "v2.1.0",
    "features": {}
  }
}
Response: {
  "asset_id": "ASSET_...",
  "token_id": "AYW-2024-WHEAT-...",
  "farmer_id": "FARMER_001",
  "token_amount": 5000,
  "transaction_hash": "0x...",
  "bcs_tx_id": "tx-...",
  "ipfs_hash": "ipfs://...",
  "created_at": "2024-02-06T10:00:00Z"
}
```

#### Get Asset
```
GET /api/v1/assets/{asset_id}
Response: {
  "asset_id": "ASSET_...",
  "status": "active"
}
```

#### Batch Tokenize
```
POST /api/v1/batch-tokenize
Body: [{ prediction }, { prediction }, ...]
Response: { "task_id": "...", "status": "processing" }
```

---

## 🧪 Testing the Deployment

### 1. Test Health Check
```bash
curl http://localhost:8000/health
```

### 2. Test Tokenization API
```bash
curl -X POST http://localhost:8000/api/v1/tokenize-yield \
  -H "Content-Type: application/json" \
  -d '{
    "prediction": {
      "farm_id": "FARM_001",
      "farmer_id": "FARMER_001",
      "crop_type": "Wheat",
      "season": 2024,
      "predicted_yield_kg": 5000.0,
      "confidence": 0.85,
      "prediction_date": "2024-02-06T10:00:00Z",
      "model_version": "v2.1.0",
      "features": {}
    }
  }'
```

### 3. Test Database Connection
```bash
docker-compose exec postgres psql -U admin -d agriyield -c "SELECT 1"
```

### 4. Test Redis Connection
```bash
docker-compose exec redis redis-cli ping
# Expected: PONG
```

### 5. View Monitoring Dashboards
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **RabbitMQ Admin**: http://localhost:15672 (admin/admin)

---

## 🔗 Connect Flutter App

### Update Configuration
Edit `lib/features/blockchain/config/blockchain_config.dart`:

```dart
class BlockchainConfig {
  // For local development
  static const String apiBaseUrl = 'http://localhost:8000/api';
  
  // Or for Docker on Windows (VM bridge)
  // static const String apiBaseUrl = 'http://host.docker.internal:8000/api';
  
  // Or for production
  // static const String apiBaseUrl = 'https://api.agriyield.com/api';
  
  static const Duration apiTimeout = Duration(seconds: 30);
  // ... rest of config
}
```

### Run Flutter App
```bash
cd agri-chain
flutter clean
flutter pub get
flutter run
```

### Expected Result
The "Yield" tab should populate with assets from your backend.

---

## 🐛 Troubleshooting

### Issue: "Connection refused"
**Cause**: Backend not running
```bash
# Check if services are running
docker-compose ps

# Start services
docker-compose up -d

# Check logs
docker-compose logs ml-integration
```

### Issue: "port already in use"
**Cause**: Another service using the port
```bash
# Find process using port 8000
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Kill process
kill -9 <PID>  # macOS/Linux
taskkill /PID <PID> /F  # Windows

# Or use different port in docker-compose.yml
```

### Issue: "Database connection failed"
**Cause**: PostgreSQL not healthy
```bash
# Check database status
docker-compose logs postgres

# Restart database
docker-compose restart postgres

# Wait for health check
docker-compose ps  # Check STATUS
```

### Issue: "Flutter app can't reach backend"
**Cause**: Network configuration
```bash
# On Windows with Docker Desktop:
# Use 'host.docker.internal' instead of 'localhost'
static const String apiBaseUrl = 'http://host.docker.internal:8000/api';

# On macOS with Docker Desktop:
# Same as Windows

# On Linux:
# Use 'localhost' or container IP
docker inspect <container-id> | grep IPAddress
```

### Issue: "Out of disk space"
**Cause**: Docker volumes getting too large
```bash
# Clean up unused volumes
docker volume prune

# Remove all volumes (careful!)
docker-compose down -v

# Restart services
docker-compose up -d
```

### View Detailed Logs
```bash
# Full logs for debugging
docker-compose logs --tail=50 ml-integration

# Follow logs in real-time
docker-compose logs -f ml-integration

# Check system logs
docker logs <container-id>
```

---

## 📊 Monitoring

### Grafana Dashboards
Access: http://localhost:3000
- Default: admin / admin
- View metrics and logs
- Create custom dashboards

### Prometheus Metrics
Access: http://localhost:9090
- Query system metrics
- View alerts
- Check data retention

### RabbitMQ Management
Access: http://localhost:15672
- Default: admin / admin
- Monitor message queues
- Manage connections

---

## 🔒 Security Considerations

### Development Only
❌ Default passwords (admin123)  
❌ No SSL/TLS  
❌ Debug mode enabled  
✅ Good for local testing

### Production Deployment
✅ Use strong passwords  
✅ Enable SSL/TLS  
✅ Set DEBUG=false  
✅ Use environment variables for secrets  
✅ Enable authentication  
✅ Use firewall rules  
✅ Regular backups  

### Update Environment
```bash
# Production .env
DB_PASSWORD=<strong-random-password>
BCS_ACCESS_KEY=<from-huawei-cloud>
BCS_SECRET_KEY=<from-huawei-cloud>
ETHEREUM_PRIVATE_KEY=<from-ethereum-wallet>

API_DEBUG=false
LOG_LEVEL=WARNING
```

---

## 📈 Scaling

### Increase Resources
Edit `docker-compose.yml`:
```yaml
services:
  ml-integration:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

### Database Optimization
```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U admin -d agriyield

# Create indexes
CREATE INDEX idx_farmer_id ON yield_assets(farmer_id);
CREATE INDEX idx_status ON yield_assets(status);

# Vacuum for optimization
VACUUM ANALYZE;
```

### Cache Strategy
Update redis memory policy and persistence in docker-compose.yml.

---

## 📚 Next Steps

1. **Test Local Deployment**
   - Run services with `docker-compose up -d`
   - Verify health at http://localhost:8000/health
   - Test API endpoints with curl

2. **Connect Flutter App**
   - Update BlockchainConfig
   - Run `flutter run`
   - Navigate to Yield tab

3. **Explore Monitoring**
   - Access Grafana at http://localhost:3000
   - Create custom dashboards
   - Monitor performance metrics

4. **Production Deployment**
   - Deploy to cloud (AWS, Azure, GCP, Huawei)
   - Configure domain and SSL
   - Set up CI/CD pipeline
   - Enable monitoring and alerts

---

## 🆘 Support

### Verify Deployment
```bash
# Check all services running
docker-compose ps

# Check health status
curl http://localhost:8000/health

# Check logs for errors
docker-compose logs --tail=20
```

### Debug Information
```bash
# Container IP
docker inspect <container-id>

# Network connectivity
docker-compose exec ml-integration ping postgres

# Port availability
netstat -tulpn | grep LISTEN
```

### Common Fixes
1. `docker-compose down` - Stop all services
2. `docker-compose up -d --build` - Rebuild and restart
3. `docker volume prune` - Clean volumes
4. `docker system prune` - Clean everything

---

## 🔄 Advanced: Custom ML Model Integration

To use your own ML model:

1. **Update ML Service**
   - Modify `ml-integration/ml_service.py`
   - Add your model inference code
   - Update `/api/v1/predict` endpoint

2. **Rebuild Service**
   ```bash
   docker-compose build --no-cache ml-integration
   docker-compose up -d
   ```

3. **Test New Endpoint**
   ```bash
   curl -X POST http://localhost:8000/api/v1/tokenize-yield ...
   ```

---

**Version**: 1.0  
**Last Updated**: February 6, 2026  
**Status**: Production-Ready
