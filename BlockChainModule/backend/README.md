# AgriTech Backend API

Complete backend API service for connecting ML yield predictions to Ethereum blockchain smart contracts with farmer wallet management and collateralized lending.

## Quick Start

```bash
# 1. Install dependencies
npm install --legacy-peer-deps

# 2. Setup environment
cp .env.example .env
# Edit .env with your contract addresses and RPC URL

# 3. Start server
npm run dev

# 4. Test API
curl http://localhost:5000/health
```

Server will run on `http://localhost:5000`

## Overview

The backend API bridges three core components:

### 1. **Farmer Wallet Management** (`/api/farmers`)
- Create Ethereum wallets for farmers
- Securely encrypt and store private keys
- Fund wallets with gas tokens
- Track farmer KYC status

### 2. **Yield Token Minting** (`/api/yield`)
- Receive ML yield predictions via webhook
- Mint ERC-1155 semi-fungible tokens on blockchain
- Track prediction accuracy after harvest
- Store prediction data on IPFS

### 3. **Collateralized Lending** (`/api/loans`)
- Create loans using yield tokens as collateral
- Calculate dynamic interest rates based on ML confidence
- Track loan repayment and defaults
- Auto-liquidate on expiry

### 4. **Oracle Integration** (`/api/oracle`)
- Receive actual harvest data from oracle
- Update prediction accuracy
- Reconcile predicted vs actual yields
- Track oracle performance

## Architecture

```
ML System                    Backend API                  Blockchain
     │
     ├─ Prediction ─→ /api/yield/mint-token ─→ ERC-1155 Token
     │
Harvest Oracle
     │
     ├─ Actual Yield ─→ /api/yield/oracle-update ─→ Update Accuracy
     │
Farmer Dashboard
     │
     ├─ Wallet Request ─→ /api/farmers ─→ Create Wallet
     │
     ├─ Loan Request ─→ /api/loans ─→ Smart Contract
     │
     └─ Repayment ─→ /api/loans/:id/repay ─→ Release Collateral
```

## Key Features

✅ **Secure Wallet Management**
- Generate random Ethereum wallets
- Encrypt private keys in database
- Backup mnemonics securely
- Fund wallets for gas

✅ **ML Integration**
- Webhook endpoint for predictions
- Automatic token minting
- Confidence-based interest rates
- Prediction accuracy tracking

✅ **Smart Contract Interaction**
- Call mintYieldToken() automatically
- Handle collateral locking
- Process loan repayment
- Liquidate on default

✅ **Oracle System**
- Receive harvest data
- Calculate prediction accuracy
- Track oracle performance
- Validate data integrity

✅ **Database & Logging**
- SQLite for development
- Transaction history tracking
- Comprehensive error logging
- Audit trail for compliance

## Project Structure

```
backend/
├── src/
│   ├── index.js                    # Main server
│   ├── services/
│   │   ├── database.js             # SQLite service
│   │   ├── wallet.js               # Wallet management
│   │   ├── contract.js             # Contract calls
│   │   └── oracle.js               # Oracle integration
│   ├── routes/
│   │   ├── farmers.js              # Farmer endpoints
│   │   ├── yield.js                # Token endpoints
│   │   ├── loans.js                # Loan endpoints
│   │   └── oracle.js               # Oracle endpoints
│   └── middleware/
│       ├── validators.js           # Input validation
│       └── logger.js               # Logging
├── data/
│   ├── agritech.db                 # Database
│   ├── wallets/                    # Wallet backups
│   └── backups/                    # DB backups
├── logs/
│   ├── error.log
│   └── combined.log
├── package.json
├── .env.example
├── SETUP.md                        # Quick start
├── BACKEND_INTEGRATION.md          # Full API docs
├── ML_INTEGRATION.md               # ML system guide
└── README.md
```

## Database Schema

### farmers
- `id` (UUID) - Primary key
- `wallet_address` - Ethereum address
- `private_key_encrypted` - Encrypted private key
- `name`, `email`, `phone` - Contact info
- `kyc_status` - Verification status
- `farm_location`, `farm_size_hectares`, `crop_type` - Farm details

### yield_tokens
- `id` (UUID) - Primary key
- `token_id` - ERC-1155 token ID
- `farmer_id` - Reference to farmer
- `predicted_yield`, `confidence_score` - ML prediction
- `actual_yield` - After harvest
- `ipfs_hash` - Metadata hash
- `token_status` - minted/harvested/reconciled

### loans
- `id` (UUID) - Primary key
- `farmer_id`, `token_id` - Collateral reference
- `principal_amount`, `interest_rate`, `total_repayment`
- `ltv_ratio` - Loan-to-value (default 70%)
- `status` - active/repaid/liquidated
- `due_date`, `repaid_at`

### oracle_updates
- `id` (UUID) - Primary key
- `token_id` - Reference to token
- `actual_yield`, `accuracy_percentage`
- `source` - Data source
- `processed_at` - Timestamp

## API Endpoints

### Farmers
```
POST   /api/farmers                 - Create wallet
GET    /api/farmers                 - List all farmers
GET    /api/farmers/:id             - Get details
GET    /api/farmers/:id/balance     - Get balance
POST   /api/farmers/:id/fund        - Fund wallet
```

### Yield Tokens
```
POST   /api/yield/mint-token        - Mint token (ML webhook)
POST   /api/yield/oracle-update     - Submit harvest data
GET    /api/yield/:id               - Get token details
GET    /api/yield/:id/accuracy      - Get accuracy
GET    /api/yield/farmer/:id        - Get farmer's tokens
```

### Loans
```
POST   /api/loans                   - Create loan
GET    /api/loans                   - List loans
GET    /api/loans/:id               - Get loan details
GET    /api/loans/:id/repayment-schedule
POST   /api/loans/:id/repay         - Repay loan
GET    /api/loans/farmer/:id        - Get farmer's loans
GET    /api/loans/stats             - Loan statistics
```

### Oracle
```
POST   /api/oracle/harvest-update   - Submit harvest data
GET    /api/oracle/harvest/:farmId  - Get history
GET    /api/oracle/stats            - Oracle stats
GET    /api/oracle/query/:farmId    - Query oracle
```

## Configuration

Create `.env` file from `.env.example`:

```env
# Ethereum Network
ETHEREUM_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
ETHEREUM_NETWORK=sepolia
CHAIN_ID=11155111

# Smart Contract Addresses (after deployment)
AGRI_YIELD_TOKEN_ADDRESS=0x...
AGRI_ASSET_REGISTRY_ADDRESS=0x...
AGRI_LOAN_MARKET_ADDRESS=0x...

# Backend Signer Wallet
BACKEND_PRIVATE_KEY=0x...
BACKEND_WALLET_ADDRESS=0x...

# Database
DATABASE_URL=./data/agritech.db

# Server
PORT=5000
NODE_ENV=development

# External Services
ML_PREDICTION_WEBHOOK_URL=http://ml-server:8000/api/predictions
HARVEST_ORACLE_URL=http://oracle-server:3001
```

## Installation

### Prerequisites
- Node.js 16+
- Ethereum RPC endpoint (Infura, Alchemy)
- Deployed smart contracts

### Setup
```bash
# Install dependencies
npm install --legacy-peer-deps

# Create environment file
cp .env.example .env

# Edit with your values
nano .env

# Start server
npm run dev
```

## Usage Examples

### Create Farmer Wallet
```bash
curl -X POST http://localhost:5000/api/farmers \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Rajesh Kumar",
    "email": "rajesh@farm.com",
    "farmLocation": "Karnataka, India",
    "farmSize": 5.5,
    "cropType": "Sugarcane"
  }'
```

### Mint Yield Token (from ML system)
```bash
curl -X POST http://localhost:5000/api/yield/mint-token \
  -H "Content-Type: application/json" \
  -d '{
    "farmerId": "550e8400-e29b-41d4-a716-446655440000",
    "farmId": "FARM-2024-001",
    "cropType": "Sugarcane",
    "season": "2024-Q1",
    "predictedYield": 125.5,
    "confidenceScore": 87.3
  }'
```

### Create Loan
```bash
curl -X POST http://localhost:5000/api/loans \
  -H "Content-Type: application/json" \
  -d '{
    "farmerId": "550e8400-e29b-41d4-a716-446655440000",
    "tokenId": "6c3d5e2a-4f8b-11e9-81b4-2a2ae2dbcce4",
    "loanAmountEth": 5.0
  }'
```

### Submit Harvest Data
```bash
curl -X POST http://localhost:5000/api/yield/oracle-update \
  -H "Content-Type: application/json" \
  -d '{
    "tokenId": "6c3d5e2a-4f8b-11e9-81b4-2a2ae2dbcce4",
    "actualYield": 128.3,
    "harvestDate": "2024-04-15T10:30:00Z"
  }'
```

See [BACKEND_INTEGRATION.md](./BACKEND_INTEGRATION.md) for complete API documentation.

## Integration with ML System

Your ML prediction system should call the webhook endpoint when a prediction is ready:

```python
import requests

def mint_yield_token(prediction_data):
    response = requests.post(
        'http://localhost:5000/api/yield/mint-token',
        json={
            'farmerId': prediction_data['farmer_id'],
            'farmId': prediction_data['farm_id'],
            'cropType': prediction_data['crop'],
            'season': '2024-Q1',
            'predictedYield': prediction_data['predicted_yield'],
            'confidenceScore': prediction_data['confidence_score']
        }
    )
    return response.json()
```

See [ML_INTEGRATION.md](./ML_INTEGRATION.md) for detailed integration guide.

## Interest Rate Model

Interest rates are based on ML confidence scores:

| Confidence | Interest Rate | Use Case |
|-----------|---------------|----------|
| ≥80%      | 3%            | High confidence predictions |
| 60-79%    | 5%            | Medium confidence |
| 40-59%    | 8%            | Lower confidence |
| <40%      | 12%           | High risk |

3-month loan term, calculated quarterly.

## Security

### Private Keys
- Encrypted in database
- Never exposed in logs
- Backup mnemonics stored securely
- Use environment variables for backend key

### API Security (Production)
- Add JWT authentication
- Implement rate limiting
- Use HTTPS only
- Enable CORS selectively

### Database
- SQLite for development only
- Use PostgreSQL for production
- Enable WAL mode
- Regular backups

## Monitoring

### Logs
```bash
# View all logs
tail -f logs/combined.log

# View errors only
tail -f logs/error.log

# Search for specific entries
grep "farmer_id" logs/combined.log
```

### Health Check
```bash
curl http://localhost:5000/health
```

### Database Inspection
```bash
sqlite3 data/agritech.db

# View tables
.tables

# Count records
SELECT COUNT(*) FROM farmers;
SELECT COUNT(*) FROM yield_tokens;
SELECT COUNT(*) FROM loans;
```

## Troubleshooting

### Port Already in Use
```bash
PORT=5001 npm run dev
```

### Database Issues
```bash
# Reset database
rm data/agritech.db

# Restart server (will recreate)
npm run dev
```

### Invalid Contract Address
```bash
# Check .env
cat .env | grep AGRI_

# Deploy contracts first
cd ../
npm run deploy:sepolia
```

### Insufficient Balance
```bash
# Fund backend wallet first
# Send ETH to BACKEND_WALLET_ADDRESS

# Or use testnet faucet
# https://sepolia-faucet.pk910.de/
```

## Performance

### Development
- Single Node.js instance
- SQLite database
- 1000+ requests/minute

### Production
- Use PostgreSQL (faster queries)
- Add Redis caching layer
- Load balance with nginx
- Database indexing on key fields
- Monitor with APM tools

## Deployment

### Local
```bash
npm run dev
```

### Docker
```bash
docker build -t agritech-backend .
docker run -p 5000:5000 --env-file .env agritech-backend
```

### PM2 (Production)
```bash
pm2 start src/index.js --name "agritech"
pm2 save
pm2 startup
```

### Cloud (Heroku)
```bash
heroku create agritech-backend
heroku config:set ETHEREUM_RPC_URL=...
git push heroku main
```

## Testing

```bash
# Run tests
npm test

# Integration tests
npm test -- --integration

# Load testing
artillery run load-test.yml
```

## Contributing

1. Create feature branch
2. Make changes
3. Write tests
4. Submit pull request

## License

MIT

## Support

- 📖 [API Documentation](./BACKEND_INTEGRATION.md)
- 🔗 [ML Integration Guide](./ML_INTEGRATION.md)
- 🚀 [Setup & Deployment](./SETUP.md)
- 🐛 [Troubleshooting](./SETUP.md#troubleshooting)

## Related

- [Smart Contracts](../) - Blockchain module
- [Smart Contract Tests](../test/) - Contract test suite
- [Architecture Guide](../ARCHITECTURE.md) - System design

---

Built with ❤️ for AgriTech Innovation
