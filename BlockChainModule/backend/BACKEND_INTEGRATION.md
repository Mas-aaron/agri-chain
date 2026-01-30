# AgriTech Backend API - Integration Guide

Complete guide to integrating the backend API with your ML system and blockchain contracts.

## Overview

The backend API serves as the bridge between:
- **ML Prediction System** → Triggers token minting
- **Farmers** → Wallet management and loan requests
- **Harvest Oracle** → Actual yield data submission
- **Blockchain Contracts** → On-chain token and loan operations

## Quick Start

### 1. Setup Backend

```bash
cd backend
npm install --legacy-peer-deps
cp .env.example .env
# Edit .env with your configuration
npm run dev
```

### 2. Initialize Database

```bash
npm run migrate
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│           ML Prediction System                  │
│  (generates yield predictions + confidence)     │
└────────────────┬────────────────────────────────┘
                 │
                 │ POST /api/yield/mint-token
                 ▼
        ┌────────────────┐
        │  Backend API   │
        │   Port 5000    │
        └────────────────┘
        ┌────────┬───────┬────────┐
        │        │       │        │
        ▼        ▼       ▼        ▼
      Farmers  Yields  Loans   Oracle
      Wallets  Tokens  Market  Updates
        │        │       │        │
        └────────┴───────┴────────┘
                 │
        ┌────────┴──────────┐
        ▼                   ▼
   Smart Contracts    Database (SQLite)
   on Blockchain      Transaction History
```

## API Endpoints

### Farmer Management

#### Create Farmer Wallet
```http
POST /api/farmers
Content-Type: application/json

{
  "name": "Rajesh Kumar",
  "email": "rajesh@farm.com",
  "phone": "+91-9876543210",
  "farmLocation": "Karnataka, India",
  "farmSize": 5.5,
  "cropType": "Sugarcane"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "farmerId": "550e8400-e29b-41d4-a716-446655440000",
    "walletAddress": "0x742d35Cc6634C0532925a3b844Bc9e7595f42bE",
    "mnemonic": "word1 word2 word3...",
    "backupPath": "./data/wallets/550e8400-mnemonic-2024-01-27.txt",
    "message": "IMPORTANT: Save the mnemonic phrase in a secure location!"
  }
}
```

#### List All Farmers
```http
GET /api/farmers?limit=20&offset=0
```

#### Get Farmer Details
```http
GET /api/farmers/{farmerId}
```

#### Get Wallet Balance
```http
GET /api/farmers/{farmerId}/balance
```

Response:
```json
{
  "success": true,
  "data": {
    "balance": "2.5",
    "unit": "ETH"
  }
}
```

#### Fund Farmer Wallet
```http
POST /api/farmers/{farmerId}/fund
Content-Type: application/json

{
  "amountEth": "0.5"
}
```

### Yield Token Management

#### Mint Token (ML Webhook)
Called by ML prediction system when new prediction is ready.

```http
POST /api/yield/mint-token
Content-Type: application/json

{
  "farmerId": "550e8400-e29b-41d4-a716-446655440000",
  "farmId": "FARM-2024-001",
  "cropType": "Sugarcane",
  "season": "2024-Q1",
  "predictedYield": 125.5,
  "confidenceScore": 87.3,
  "ipfsHash": "QmXxxx...",
  "modelVersion": "v2.1"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "transactionHash": "0x742d35cc...",
    "yieldTokenId": "6c3d5e2a-4f8b-11e9-81b4-2a2ae2dbcce4",
    "message": "Yield token minting initiated"
  }
}
```

#### Submit Harvest Data (Oracle)
```http
POST /api/yield/oracle-update
Content-Type: application/json

{
  "tokenId": "6c3d5e2a-4f8b-11e9-81b4-2a2ae2dbcce4",
  "actualYield": 128.3,
  "farmId": "FARM-2024-001",
  "harvestDate": "2024-04-15T10:30:00Z",
  "source": "harvest_oracle"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "tokenId": "6c3d5e2a-4f8b-11e9-81b4-2a2ae2dbcce4",
    "actualYield": 128.3,
    "accuracy": "102.23%",
    "updateId": "a1b2c3d4-e5f6-47g8-h9i0-j1k2l3m4n5o6"
  }
}
```

#### Get Token Details
```http
GET /api/yield/{tokenId}
```

#### Get Prediction Accuracy
```http
GET /api/yield/{tokenId}/accuracy
```

Response:
```json
{
  "success": true,
  "data": {
    "accuracy": "102.23%",
    "actualYield": 128.3
  }
}
```

### Loan Management

#### Create Loan
```http
POST /api/loans
Content-Type: application/json

{
  "farmerId": "550e8400-e29b-41d4-a716-446655440000",
  "tokenId": "6c3d5e2a-4f8b-11e9-81b4-2a2ae2dbcce4",
  "loanAmountEth": "5.0"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "loanId": "loan-550e8400-001",
    "transactionHash": "0x742d35cc...",
    "principalAmount": 5.0,
    "interestRate": "5%",
    "totalRepayment": 5.1875,
    "dueDate": "2024-04-27T12:30:45.123Z"
  }
}
```

#### Get Loan Details
```http
GET /api/loans/{loanId}
```

#### Get Repayment Schedule
```http
GET /api/loans/{loanId}/repayment-schedule
```

Response:
```json
{
  "success": true,
  "data": {
    "loanId": "loan-550e8400-001",
    "principal": 5.0,
    "interestRate": "5%",
    "totalRepayment": 5.1875,
    "repaidAmount": 2.0,
    "remaining": "3.1875",
    "dueDate": "2024-04-27T12:30:45.123Z",
    "daysRemaining": 45,
    "isOverdue": false
  }
}
```

#### Repay Loan
```http
POST /api/loans/{loanId}/repay
Content-Type: application/json

{
  "repaymentAmount": 2.0
}
```

Response:
```json
{
  "success": true,
  "data": {
    "loanId": "loan-550e8400-001",
    "transactionHash": "0x742d35cc...",
    "repaidAmount": 4.0,
    "totalRepayment": 5.1875,
    "remaining": "1.1875",
    "fullyRepaid": false
  }
}
```

### Oracle Integration

#### Submit Harvest Data
```http
POST /api/oracle/harvest-update
Content-Type: application/json

{
  "farmId": "FARM-2024-001",
  "season": "2024-Q1",
  "actualYield": 128.3,
  "harvestDate": "2024-04-15T10:30:00Z",
  "source": "field_inspection",
  "quality": "premium"
}
```

#### Get Harvest History
```http
GET /api/oracle/harvest/{farmId}
```

#### Query Oracle for Data
```http
GET /api/oracle/query/{farmId}?season=2024-Q1
```

#### Get Oracle Statistics
```http
GET /api/oracle/stats
```

Response:
```json
{
  "success": true,
  "data": {
    "totalUpdates": 45,
    "averageAccuracy": "98.34%",
    "minAccuracy": "85.22%",
    "maxAccuracy": "105.67%"
  }
}
```

## Integration Workflows

### Workflow 1: ML Prediction → Token Minting

```javascript
// 1. ML System generates prediction
const prediction = {
  farmerId: "550e8400-e29b-41d4-a716-446655440000",
  farmId: "FARM-2024-001",
  cropType: "Sugarcane",
  season: "2024-Q1",
  predictedYield: 125.5,
  confidenceScore: 87.3,
  ipfsHash: "QmXxxx...",
  modelVersion: "v2.1"
};

// 2. Send to backend API
const response = await fetch('http://localhost:5000/api/yield/mint-token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(prediction)
});

const { data } = await response.json();
console.log('Token minted:', data.yieldTokenId);
console.log('TX Hash:', data.transactionHash);
```

### Workflow 2: Harvest Data → Accuracy Update

```javascript
// 1. Oracle receives actual harvest data
const harvestData = {
  farmId: "FARM-2024-001",
  season: "2024-Q1",
  actualYield: 128.3,
  harvestDate: "2024-04-15T10:30:00Z",
  source: "harvest_oracle"
};

// 2. Submit to backend
const response = await fetch(
  'http://localhost:5000/api/yield/oracle-update',
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(harvestData)
  }
);

const { data } = await response.json();
console.log('Accuracy:', data.accuracy);
console.log('Model Performance:', data.accuracy > 100 ? 'Underestimated' : 'Overestimated');
```

### Workflow 3: Loan Creation & Repayment

```javascript
// 1. Farmer requests loan using yield token as collateral
const loanRequest = {
  farmerId: "550e8400-e29b-41d4-a716-446655440000",
  tokenId: "6c3d5e2a-4f8b-11e9-81b4-2a2ae2dbcce4",
  loanAmountEth: 5.0
};

// 2. Create loan
const loanResponse = await fetch('http://localhost:5000/api/loans', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(loanRequest)
});

const { data: loan } = await loanResponse.json();
console.log('Loan created:', loan.loanId);
console.log('Interest rate:', loan.interestRate);
console.log('Total repayment:', loan.totalRepayment);

// 3. Check repayment schedule
const scheduleResponse = await fetch(
  `http://localhost:5000/api/loans/${loan.loanId}/repayment-schedule`
);
const { data: schedule } = await scheduleResponse.json();
console.log('Days remaining:', schedule.daysRemaining);

// 4. Make repayment
const repaymentResponse = await fetch(
  `http://localhost:5000/api/loans/${loan.loanId}/repay`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ repaymentAmount: 2.5 })
  }
);

const { data: repayment } = await repaymentResponse.json();
console.log('Repaid:', repayment.repaidAmount);
console.log('Remaining:', repayment.remaining);
```

## Environment Configuration

Create `.env` file:

```env
# Ethereum
ETHEREUM_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
ETHEREUM_NETWORK=sepolia
CHAIN_ID=11155111

# Contracts (after deployment)
AGRI_YIELD_TOKEN_ADDRESS=0x...
AGRI_ASSET_REGISTRY_ADDRESS=0x...
AGRI_LOAN_MARKET_ADDRESS=0x...

# Backend Wallet
BACKEND_PRIVATE_KEY=0x...
BACKEND_WALLET_ADDRESS=0x...

# Database
DATABASE_URL=./data/agritech.db

# Server
PORT=5000
NODE_ENV=development

# Integrations
ML_PREDICTION_WEBHOOK_URL=http://ml-server:8000/api/predictions
HARVEST_ORACLE_URL=http://oracle-server:3001
```

## Database Schema

### farmers
```sql
id (UUID) - Primary key
wallet_address (TEXT) - Ethereum address
private_key_encrypted (TEXT) - Encrypted private key
name, email, phone
kyc_status (pending/verified/rejected)
farm_location, farm_size_hectares, crop_type
created_at, updated_at
```

### yield_tokens
```sql
id (UUID) - Primary key
token_id (INTEGER) - Smart contract token ID
farmer_id (FK) - References farmers.id
farm_id, crop_type, season
predicted_yield, confidence_score, actual_yield
ipfs_hash, transaction_hash
token_status (minted/harvested/reconciled)
```

### loans
```sql
id (UUID) - Primary key
farmer_id (FK), token_id
principal_amount, interest_rate, total_repayment
ltv_ratio (default 70%)
due_date, repaid_amount
status (active/repaid/liquidated)
created_at, repaid_at, liquidated_at
```

### oracle_updates
```sql
id (UUID) - Primary key
token_id, actual_yield
oracle_signature, source
accuracy_percentage
processed_at
```

## Error Handling

All errors follow standard format:

```json
{
  "success": false,
  "error": "Description of the error"
}
```

Common status codes:
- 200: Success
- 201: Created
- 400: Bad request (validation error)
- 404: Not found
- 500: Server error

## Security Considerations

### Private Key Management
- Private keys are encrypted in database
- Never expose in logs or responses
- Use environment variables for backend key
- Consider using HSM for production

### API Authentication
- Add JWT/API key authentication for production
- Implement rate limiting
- Use HTTPS only

### Database
- SQLite for development only
- Use PostgreSQL for production
- Enable WAL mode for consistency
- Regular backups

## Performance Tips

1. **Batch Operations**
   - Use batch transfers for multiple farmers
   - Combine oracle updates

2. **Caching**
   - Cache farmer details
   - Cache token metadata from IPFS

3. **Async Processing**
   - Use background jobs for blockchain transactions
   - Queue oracle updates

## Testing

```bash
# Run test suite
npm test

# Test specific endpoint
curl -X POST http://localhost:5000/api/health

# Test farmer creation
curl -X POST http://localhost:5000/api/farmers \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@farm.com","farmLocation":"India","farmSize":5,"cropType":"Rice"}'
```

## Monitoring

Logs are stored in `./logs/`:
- `error.log` - Error messages
- `combined.log` - All messages

Monitor:
- API response times
- Database query performance
- Blockchain transaction status
- Oracle data accuracy
- Loan liquidation events

## Next Steps

1. Deploy to production environment
2. Configure actual contract addresses
3. Setup ML system webhooks
4. Connect harvest oracle
5. Test end-to-end workflows
6. Monitor system performance
7. Implement dashboard for farmers
