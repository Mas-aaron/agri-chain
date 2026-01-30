# Backend Setup & Deployment Guide

Quick start guide to get the backend API running.

## Prerequisites

- Node.js 16+ ([download](https://nodejs.org/))
- Git
- Ethereum RPC endpoint (Infura, Alchemy, or local node)
- Deployed smart contracts (from blockchain module)

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
cd backend
npm install --legacy-peer-deps
```

Expected output:
```
added 219 packages, and found 13 vulnerabilities
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your values
```

Key settings:
```env
ETHEREUM_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
ETHEREUM_NETWORK=sepolia
AGRI_YIELD_TOKEN_ADDRESS=0x...     # From deployment
AGRI_ASSET_REGISTRY_ADDRESS=0x...  # From deployment
AGRI_LOAN_MARKET_ADDRESS=0x...     # From deployment
BACKEND_PRIVATE_KEY=0x...          # Backend signer key
PORT=5000
```

### 3. Start Server

```bash
npm run dev
```

Expected output:
```
============================================================
🚀 AgriTech Backend API
============================================================
✓ Server running on http://localhost:5000
✓ Environment: development
✓ Network: sepolia
============================================================

Endpoints:
  POST   /api/farmers                    - Create farmer wallet
  GET    /api/farmers                    - List all farmers
  ...
============================================================
```

### 4. Test API

```bash
# Check health
curl http://localhost:5000/health

# Create farmer
curl -X POST http://localhost:5000/api/farmers \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Rajesh Kumar",
    "email": "rajesh@farm.com",
    "phone": "+91-9876543210",
    "farmLocation": "Karnataka, India",
    "farmSize": 5.5,
    "cropType": "Sugarcane"
  }'
```

## Project Structure

```
backend/
├── src/
│   ├── index.js                 # Main server entry
│   ├── services/
│   │   ├── database.js          # SQLite management
│   │   ├── wallet.js            # Farmer wallet creation
│   │   ├── contract.js          # Smart contract interaction
│   │   └── oracle.js            # Harvest data oracle
│   ├── routes/
│   │   ├── farmers.js           # Farmer API endpoints
│   │   ├── yield.js             # Yield token endpoints
│   │   ├── loans.js             # Loan management endpoints
│   │   └── oracle.js            # Oracle endpoints
│   └── middleware/
│       ├── validators.js         # Input validation
│       └── logger.js             # Logging service
├── data/
│   ├── agritech.db              # SQLite database
│   ├── wallets/                 # Farmer wallet backups
│   └── backups/                 # Database backups
├── logs/
│   ├── error.log                # Error log
│   └── combined.log             # All logs
├── package.json
├── .env.example
├── BACKEND_INTEGRATION.md       # Full API documentation
├── ML_INTEGRATION.md            # ML system integration
└── README.md
```

## API Quick Reference

### Farmers
```bash
# Create wallet
POST /api/farmers

# List farmers
GET /api/farmers

# Get farmer details
GET /api/farmers/{farmerId}

# Get balance
GET /api/farmers/{farmerId}/balance

# Fund wallet (for testing)
POST /api/farmers/{farmerId}/fund
```

### Yield Tokens
```bash
# Mint token (from ML prediction)
POST /api/yield/mint-token

# Submit harvest data (oracle)
POST /api/yield/oracle-update

# Get token details
GET /api/yield/{tokenId}

# Get prediction accuracy
GET /api/yield/{tokenId}/accuracy
```

### Loans
```bash
# Create loan
POST /api/loans

# Get loan details
GET /api/loans/{loanId}

# Get repayment schedule
GET /api/loans/{loanId}/repayment-schedule

# Repay loan
POST /api/loans/{loanId}/repay
```

### Oracle
```bash
# Submit harvest data
POST /api/oracle/harvest-update

# Get harvest history
GET /api/oracle/harvest/{farmId}

# Get oracle statistics
GET /api/oracle/stats
```

## Configuration Details

### Database (`database.js`)

Automatically creates tables:
- `farmers` - Farmer profiles and wallets
- `yield_tokens` - ML predictions and tokens
- `loans` - Loan records
- `oracle_updates` - Harvest data
- `transactions` - Transaction history
- `wallet_backups` - Mnemonic backups

Location: `./data/agritech.db`

### Wallet Management (`wallet.js`)

Features:
- Generate random wallets for farmers
- Encrypt private keys in database
- Backup mnemonic phrases
- Fund wallets for gas
- Query balances

Encryption: Simple XOR (upgrade for production)

### Contract Interaction (`contract.js`)

Handles:
- `mintYieldToken()` - Create ERC-1155 tokens
- `registerAsset()` - Link blockchain tokens to farms
- `createLoan()` - Collateralized lending
- `repayLoan()` - Loan repayment
- `processOracleUpdate()` - Harvest reconciliation

### Oracle Service (`oracle.js`)

Handles:
- Receiving ML predictions
- Querying harvest data
- Submitting actual yield
- Calculating accuracy
- Tracking oracle performance

## Deployment

### Local Development
```bash
npm run dev
```

### Production Deployment

#### Option 1: Direct Server
```bash
# Install globally
npm install -g pm2

# Start with PM2
pm2 start src/index.js --name "agritech-backend"
pm2 save

# Monitor
pm2 logs agritech-backend
```

#### Option 2: Docker
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --legacy-peer-deps

COPY . .

ENV NODE_ENV=production
EXPOSE 5000

CMD ["node", "src/index.js"]
```

Build and run:
```bash
docker build -t agritech-backend .
docker run -p 5000:5000 --env-file .env agritech-backend
```

#### Option 3: Cloud Deployment (Heroku)
```bash
# Create Procfile
echo "web: node src/index.js" > Procfile

# Deploy
heroku create agritech-backend
heroku config:set ETHEREUM_RPC_URL=https://...
git push heroku main
```

## Database Backup & Recovery

### Backup
```bash
# Automatic backup on startup
cp ./data/agritech.db ./data/backups/agritech-$(date +%Y%m%d-%H%M%S).db

# Manual backup
sqlite3 ./data/agritech.db ".backup './data/backups/backup.db'"
```

### Restore
```bash
sqlite3 ./data/agritech.db ".restore './data/backups/backup.db'"
```

## Monitoring & Logs

### Check Logs
```bash
# View logs
tail -f logs/combined.log
tail -f logs/error.log

# Find specific errors
grep "ERROR" logs/error.log
grep "farmer_id" logs/combined.log
```

### Health Check
```bash
# Simple health endpoint
curl http://localhost:5000/health

# Expected response
{
  "status": "healthy",
  "timestamp": "2024-01-27T...",
  "environment": "development"
}
```

### Monitor Key Metrics
```bash
# Database size
ls -lh data/agritech.db

# Farmer count
sqlite3 data/agritech.db "SELECT COUNT(*) FROM farmers;"

# Active loans
sqlite3 data/agritech.db "SELECT COUNT(*) FROM loans WHERE status='active';"

# Minted tokens
sqlite3 data/agritech.db "SELECT COUNT(*) FROM yield_tokens;"
```

## Troubleshooting

### Issue: "Cannot find module"
```bash
# Reinstall dependencies
rm -rf node_modules
npm install --legacy-peer-deps
```

### Issue: "Port 5000 already in use"
```bash
# Find process using port
netstat -tulpn | grep 5000

# Kill process
kill -9 <PID>

# Or use different port
PORT=5001 npm run dev
```

### Issue: "Database is locked"
```bash
# Close all connections
lsof | grep agritech.db

# Delete lock file
rm data/agritech.db-wal
```

### Issue: "Invalid contract address"
```bash
# Check .env
grep AGRI_YIELD_TOKEN_ADDRESS .env

# Deploy contracts first if not done
cd ..
npm run deploy:sepolia
```

### Issue: "Insufficient balance"
```bash
# Fund backend wallet
# Send ETH to BACKEND_WALLET_ADDRESS first

# Or use test faucet
# https://sepolia-faucet.pk910.de/
```

## Performance Optimization

### For Production

1. **Use PostgreSQL instead of SQLite**
```bash
npm install pg
# Update database.js to use PostgreSQL
```

2. **Add Redis caching**
```bash
npm install redis
# Cache farmer details, token metadata
```

3. **Implement database indexing**
```sql
CREATE INDEX idx_farmer_id ON yield_tokens(farmer_id);
CREATE INDEX idx_farm_id ON yield_tokens(farm_id);
CREATE INDEX idx_token_status ON yield_tokens(token_status);
```

4. **Load balance with nginx**
```nginx
upstream backend {
    server localhost:5000;
    server localhost:5001;
    server localhost:5002;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
    }
}
```

## Security Hardening

### For Production

1. **Add API authentication**
```javascript
// In middleware
const authenticate = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    if (apiKey !== process.env.API_KEY) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
};
app.use(authenticate);
```

2. **Add rate limiting**
```bash
npm install express-rate-limit
```

3. **Use environment secrets**
```bash
# Never commit .env file
echo ".env" >> .gitignore

# Use secret manager
aws secretsmanager get-secret-value --secret-id agritech
```

4. **Enable HTTPS**
```javascript
const https = require('https');
const fs = require('fs');

const options = {
  key: fs.readFileSync('private-key.pem'),
  cert: fs.readFileSync('certificate.pem')
};

https.createServer(options, app).listen(443);
```

## Testing

### Unit Tests
```bash
npm test
```

### Integration Tests
```bash
# Start backend in test mode
NODE_ENV=test npm run dev

# Run test suite in another terminal
npm test -- --integration
```

### Load Testing
```bash
npm install -g artillery

# Create test scenario
artillery run load-test.yml

# View results
artillery report results.json
```

## Getting Help

1. **Check logs**: `tail -f logs/combined.log`
2. **Read docs**: See `BACKEND_INTEGRATION.md` for full API reference
3. **Test endpoints**: Use curl or Postman to test
4. **Debug database**: Use `sqlite3 data/agritech.db`

## Next Steps

1. ✅ Backend API running
2. 🔗 Connect ML system webhook to `/api/yield/mint-token`
3. 🌾 Setup harvest oracle for actual yield updates
4. 👨‍🌾 Create farmer dashboard to view tokens and loans
5. 🔐 Implement KYC verification for farmers
6. 📊 Build analytics dashboard for lender
7. 🚀 Deploy to production environment

## Support

For issues or questions:
1. Check `/logs` directory
2. Review `BACKEND_INTEGRATION.md`
3. Test endpoints with provided curl commands
4. Verify `.env` configuration
