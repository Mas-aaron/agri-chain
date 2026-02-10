# AgriChain Deployment Guide

This guide covers the deployment of the AgriChain platform with all the recent improvements for production readiness.

## 🚀 Quick Start

### Prerequisites
- Python 3.8+
- Flutter 3.0+
- Node.js 16+ (for some tools)
- PostgreSQL (for production) or SQLite (for development)

### Backend Deployment

1. **Environment Setup**
   ```bash
   cd backend/backend
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Database Setup**
   
   For Development (SQLite):
   ```bash
   # SQLite is configured by default
   python -c "from database import init_database; init_database()"
   ```
   
   For Production (PostgreSQL):
   ```bash
   # Set DB_TYPE=postgres in .env
   # Configure PostgreSQL connection details
   python -c "from database import init_database; init_database()"
   ```

4. **Start the API Server**
   ```bash
   # Development
   uvicorn app:app --reload --host 0.0.0.0 --port 8000
   
   # Production
   uvicorn app:app --host 0.0.0.0 --port 8000 --workers 4
   ```

### Frontend Deployment

1. **Environment Setup**
   ```bash
   cd agri-chain
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the App**
   ```bash
   # Development
   flutter run --dart-define=FLUTTER_ENV=development
   
   # Build for production
   flutter build web --release --dart-define=FLUTLER_ENV=production
   ```

## 🔐 Authentication Setup

### Default Users
The system comes with demo users for testing:

- **Farmer**: `farmer@agrichain.com` / `demo123`
- **Buyer**: `buyer@agrichain.com` / `demo123`
- **Admin**: `admin@agrichain.com` / `admin123`

### API Authentication

1. **JWT Token Authentication**
   ```bash
   curl -X POST "http://localhost:8000/auth/login" \
     -H "Content-Type: application/json" \
     -d '{"email": "farmer@agrichain.com", "password": "demo123"}'
   ```

2. **API Key Authentication**
   ```bash
   # Create API key (requires JWT token)
   curl -X POST "http://localhost:8000/auth/api-key" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json"
   ```

## 🗄️ Database Configuration

### SQLite (Development)
- File location: `agrichain.db`
- Automatic migrations on startup
- No additional configuration needed

### PostgreSQL (Production)
```env
DB_TYPE=postgres
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=agrichain_prod
POSTGRES_USER=agrichain_user
POSTGRES_PASSWORD=your_secure_password
```

### Migration Features
- Automatic table creation
- Index creation for performance
- Blockchain-related columns support
- PostgreSQL triggers and JSONB support

## 🔗 Blockchain Integration

### Web3 Service
The Web3 service now supports:
- Wallet creation and management
- Transaction signing and sending
- Smart contract interactions
- Gas price estimation

### Configuration
```env
BLOCKCHAIN_RPC_URL=https://mainnet.infura.io/v3/YOUR-PROJECT-ID
CONTRACT_ADDRESS=0x1234567890123456789012345678901234567890
CHAIN_ID=1
```

### Smart Contract Features
- Yield token creation
- Token transfers
- Token information queries
- Transaction status tracking

## 🌍 Environment Configuration

### Development Environment
```env
FLUTTER_ENV=development
API_BASE_URL=http://10.0.2.2:8000
ENABLE_DEBUG_LOGS=true
```

### Production Environment
```env
FLUTTER_ENV=production
API_BASE_URL=https://api.agrichain.com
ENABLE_DEBUG_LOGS=false
```

## 🐳 Docker Deployment

### Backend Dockerfile
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Docker Compose
```yaml
version: '3.8'
services:
  backend:
    build: ./backend/backend
    ports:
      - "8000:8000"
    environment:
      - DB_TYPE=postgres
      - POSTGRES_HOST=postgres
    depends_on:
      - postgres

  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: agrichain
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin123
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## 🔧 Huawei Cloud Integration

### Required Environment Variables
```env
# Object Storage Service
HUAWEI_OBS_ACCESS_KEY=your-access-key
HUAWEI_OBS_SECRET_KEY=your-secret-key
HUAWEI_OBS_ENDPOINT=https://obs.region.myhuaweicloud.com
HUAWEI_OBS_BUCKET=agrichain-data

# Blockchain Service
HUAWEI_BCS_RPC_URL=https://bcs.region.myhuaweicloud.com
HUAWEI_BCS_CHAIN_ID=your-chain-id

# ModelArts
MODElARTS_ENDPOINT_URL=https://modelarts.region.myhuaweicloud.com
```

## 📊 Monitoring and Logging

### Health Checks
- API Health: `GET /health`
- Database Health: `GET /health/db`
- Blockchain Health: `GET /health/blockchain`

### Logging
- Structured JSON logging
- Environment-specific log levels
- Request/response logging in debug mode

## 🚨 Security Considerations

1. **Change Default Secrets**
   - JWT secret key
   - Database passwords
   - API keys

2. **CORS Configuration**
   - Restrict origins in production
   - Use HTTPS in production

3. **Database Security**
   - Use PostgreSQL in production
   - Enable SSL connections
   - Regular backups

4. **API Security**
   - Rate limiting
   - Input validation
   - SQL injection protection

## 🔄 CI/CD Pipeline

### GitHub Actions Example
```yaml
name: Deploy AgriChain
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.9'
      - name: Install dependencies
        run: pip install -r backend/backend/requirements.txt
      - name: Run tests
        run: python -m pytest

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: |
          # Deployment commands here
```

## 📱 Mobile App Deployment

### Android
```bash
flutter build apk --release --dart-define=FLUTTER_ENV=production
```

### iOS
```bash
flutter build ios --release --dart-define=FLUTTER_ENV=production
```

### Web
```bash
flutter build web --release --dart-define=FLUTTER_ENV=production
```

## 🛠️ Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check connection string
   - Verify database is running
   - Check credentials

2. **Authentication Failed**
   - Verify JWT secret key
   - Check token expiration
   - Validate user credentials

3. **Blockchain Connection Issues**
   - Verify RPC URL
   - Check network connectivity
   - Validate contract address

4. **Environment Variables Not Loading**
   - Check .env file location
   - Verify variable names
   - Restart application

### Debug Mode
Enable debug logging:
```env
ENABLE_DEBUG_LOGS=true
FLUTTER_ENV=development
```

## 📞 Support

For deployment issues:
1. Check the logs
2. Verify environment configuration
3. Test with development environment first
4. Review this guide for common solutions

---

## 🎯 Next Steps

After successful deployment:

1. **Monitor Performance**
   - Set up monitoring dashboards
   - Configure alerts
   - Track key metrics

2. **Scale Infrastructure**
   - Load balancing
   - Database optimization
   - Caching strategies

3. **Security Hardening**
   - Security audit
   - Penetration testing
   - Compliance checks

4. **Feature Enhancement**
   - User feedback collection
   - Performance optimization
   - New feature development
