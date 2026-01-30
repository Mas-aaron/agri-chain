# Agri-Blockchain: ERC-1155 Agricultural Asset System

## Overview

A blockchain-based system for tokenizing agricultural yields using **ERC-1155 semi-fungible tokens**. Farmers receive yield prediction tokens that can be used as collateral for loans or traded on secondary markets.

## Project Structure

```
agri-blockchain/
├── contracts/               # Smart contracts
│   ├── AgriYieldToken.sol          # ERC-1155 token with yield metadata
│   ├── AgriAssetRegistry.sol         # Registry for real-world asset data
│   └── AgriLoanMarket.sol            # Collateralized lending market
├── scripts/
│   └── deploy.js            # Deployment script
├── test/
│   ├── AgriYieldToken.test.js
│   └── AgriLoanMarket.test.js
├── hardhat.config.js        # Hardhat configuration
├── package.json             # Dependencies
└── .env.example             # Environment variables template
```

## Smart Contracts

### 1. **AgriYieldToken.sol** (ERC-1155)
- **Purpose**: Create semi-fungible tokens representing predicted yields
- **Key Features**:
  - Mint tokens tied to farm + season + crop
  - Store ML prediction data and confidence scores
  - IPFS-based metadata
  - Batch transfer capabilities
  - Pause mechanism for emergency
  - Role-based access control

**Key Methods**:
```solidity
mintYieldToken(farmer, farmId, geoHash, cropType, season, predictedYield, confidence, dataHash)
  → Returns tokenId with 1 token = 1 unit yield

updateActualYield(tokenId, actualYield)
  → Records real harvest data (Oracle-callable)

getPredictionAccuracy(tokenId)
  → Calculates prediction accuracy after harvest

batchTransfer(from, to, ids, amounts)
  → Efficiently transfer multiple token types
```

### 2. **AgriAssetRegistry.sol**
- **Purpose**: Register and track real-world agricultural assets
- **Key Features**:
  - Map token IDs to physical farm details
  - Oracle data reconciliation
  - Farmer-to-tokens mapping
  - Asset lifecycle management

**Key Methods**:
```solidity
registerAsset(tokenId, tokenContract, farmer, farmId, season, geoLocation, cropVariety, farmSizeHectares)
  → Register yield token as tracked asset

updateOracleData(tokenId, dataHash)
  → Update real-world data from oracle

getAssetRegistry(tokenId)
  → Retrieve full asset details
```

### 3. **AgriLoanMarket.sol**
- **Purpose**: Collateralized lending using yield tokens
- **Key Features**:
  - Dynamic interest rates based on prediction confidence
  - LTV (Loan-to-Value) ratios
  - Loan repayment with interest
  - Automatic liquidation on default
  - Platform fees to treasury

**Key Methods**:
```solidity
createLoan(tokenContract, tokenId, tokenAmount, loanDurationDays, predictionConfidence)
  → Create collateralized loan
  → Returns loanId

repayLoan(loanId)
  → Repay loan with interest + platform fee
  → Returns locked tokens to farmer

liquidateLoan(loanId)
  → Liquidate overdue loan
  → Transfers collateral to treasury

calculateRepayment(loanId)
  → View function to get total repayment amount
```

## Setup & Installation

### Prerequisites
- Node.js 16+
- npm or yarn

### Installation

```bash
# Clone repository
cd BlockChainModule

# Install dependencies
npm install

# Create .env file (copy from .env.example)
cp .env.example .env
```

### Environment Variables (.env)
```env
# Sepolia Testnet (optional)
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
PRIVATE_KEY=your_private_key_here

# Etherscan (for contract verification)
ETHERSCAN_API_KEY=your_etherscan_key
```

## Development

### Compile Contracts
```bash
npm run compile
```

### Run Tests
```bash
npm test
```

### Run Local Node
```bash
npm run node
```

### Deploy to Local Network
```bash
# Terminal 1: Start local node
npm run node

# Terminal 2: Deploy
npm run deploy
```

### Deploy to Sepolia Testnet
```bash
npm run deploy:sepolia
```

## Contract Interactions

### Example: Mint a Yield Token

```javascript
const tx = await yieldToken.mintYieldToken(
  farmerAddress,           // Farmer who owns this token
  "FARM-001",              // Unique farm ID
  "u2f23x",                // GeoHash (Bangalore region)
  "Rice",                  // Crop type
  2024,                    // Season
  5000,                    // Predicted yield (kg)
  85,                      // Confidence (85%)
  "QmAbcd123..."          // IPFS hash of ML data
);
```

### Example: Create a Loan

```javascript
const loanAmount = ethers.utils.parseEther("10"); // 10 ETH
const tx = await loanMarket.createLoan(
  yieldToken.address,      // Token contract
  1,                        // Token ID (from mint)
  500,                      // Collateral amount (500 kg)
  30,                       // Duration (30 days)
  85,                       // Confidence from token
  { value: loanAmount }     // Loan amount in ETH
);
```

### Example: Update Harvest Data

```javascript
// After harvest, oracle updates actual yield
const tx = await yieldToken
  .connect(oracleAddress)
  .updateActualYield(1, 4800); // Actual yield: 4800 kg
```

## Token Economics

### Interest Rate Model
Rates based on prediction confidence:
- **80%+ confidence**: 3% per annum
- **60-79% confidence**: 5% per annum
- **40-59% confidence**: 8% per annum
- **<40% confidence**: 12% per annum

### LTV (Loan-to-Value)
- Default LTV: 70%
- Calculated as: `max_loan = (collateral_amount * LTV) / 100`
- Adjustable by contract admin

### Platform Fees
- 1% of interest charged to treasury
- Covers platform operations and insurance buffer

## Metadata Format (IPFS)

Token metadata structure (stored on IPFS):
```json
{
  "name": "Rice Yield Token - Farm FARM-001 - Season 2024",
  "description": "ERC-1155 semi-fungible token representing predicted rice yield",
  "image": "ipfs://QmYieldTokenImage",
  "properties": {
    "farmId": "FARM-001",
    "cropType": "Rice",
    "season": 2024,
    "predictedYield": 5000,
    "predictionConfidence": 85,
    "geoLocation": "u2f23x",
    "dataHash": "QmAbcd123..."
  }
}
```

## Testing

### Test Coverage
- ✅ Token minting and metadata
- ✅ Yield updates and accuracy calculation
- ✅ Batch transfers
- ✅ Pause/unpause mechanism
- ✅ Loan creation and repayment
- ✅ Loan liquidation
- ✅ Interest rate calculations
- ✅ Access control and role management

### Run Tests with Coverage
```bash
npm run coverage
```

## Security Considerations

1. **Reentrancy Protection**: `ReentrancyGuard` on loan repayment
2. **Pausable Mechanism**: Emergency pause for token transfers
3. **Role-Based Access**: MINTER, ORACLE, ADMIN, PAUSER roles
4. **Confidence-Based LTV**: Higher confidence = better loan terms
5. **Liquidation Logic**: Automatic collateral seizure on default

## Deployment Checklist

- [ ] Set appropriate base URI (IPFS gateway)
- [ ] Configure interest rate tiers for your region
- [ ] Set LTV ratios based on risk appetite
- [ ] Deploy and verify on block explorer
- [ ] Grant MINTER_ROLE to your backend service
- [ ] Grant ORACLE_ROLE to data provider
- [ ] Test end-to-end flow on testnet
- [ ] Deploy to mainnet

## Next Phases

### Phase 2: Oracle Integration
- Chainlink automation for real yield data
- Automated accuracy scoring
- Historical ML model performance tracking

### Phase 3: Marketplace
- Secondary trading platform
- Order book or AMM-style trading
- Price discovery mechanisms

### Phase 4: DeFi Integrations
- Yield farming integration
- Cross-chain bridging
- Governance token (DAO)

## Resources

- [ERC-1155 Specification](https://eips.ethereum.org/EIPS/eip-1155)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Hardhat Documentation](https://hardhat.org/docs)
- [Chainlink VRF & Automation](https://docs.chain.link/)

## Support & Issues

For issues or questions:
1. Check existing tests for usage examples
2. Review contract comments for detailed logic
3. Test on Hardhat local network first
4. Verify environment variables are set

---

**Built for Agricultural Transformation | Farm-to-Finance Blockchain**
