# ML to Blockchain Integration Guide

Complete guide to connect your ML yield prediction system with the blockchain backend.

## Architecture

```
Your ML System                Backend API                Blockchain
┌──────────────┐           ┌───────────────┐          ┌──────────────┐
│   Model      │           │  Express API  │          │  Smart       │
│ Prediction   │──POST─→   │  /api/yield/  │──TX──→   │  Contracts   │
│   Output     │ mint-token │  mint-token   │          │  (ERC-1155)  │
└──────────────┘           └───────────────┘          └──────────────┘
                                  │
                                  │
                           ┌──────▼───────┐
                           │   SQLite DB  │
                           │   + Logs     │
                           └──────────────┘
```

## Step 1: Setup Webhook Endpoint

Your ML system needs to call the backend API when a prediction is ready.

### ML System Code (Python Example)

```python
import requests
import json
from datetime import datetime

class BlockchainMinter:
    def __init__(self, api_url="http://localhost:5000"):
        self.api_url = api_url
    
    def mint_yield_token(self, prediction_data):
        """
        Call backend API to mint yield token
        
        Args:
            prediction_data: {
                'farmerId': str,
                'farmId': str,
                'cropType': str,
                'season': str,
                'predictedYield': float,
                'confidenceScore': float (0-100),
                'ipfsHash': str (optional)
            }
        """
        endpoint = f"{self.api_url}/api/yield/mint-token"
        
        payload = {
            "farmerId": prediction_data['farmerId'],
            "farmId": prediction_data['farmId'],
            "cropType": prediction_data['cropType'],
            "season": prediction_data['season'],
            "predictedYield": float(prediction_data['predictedYield']),
            "confidenceScore": float(prediction_data['confidenceScore']),
            "ipfsHash": prediction_data.get('ipfsHash', ''),
            "modelVersion": "v2.1"  # Your model version
        }
        
        try:
            response = requests.post(
                endpoint,
                json=payload,
                timeout=30,
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            
            result = response.json()
            if result['success']:
                print(f"✓ Token minted: {result['data']['yieldTokenId']}")
                print(f"  TX: {result['data']['transactionHash']}")
                return result['data']
            else:
                print(f"✗ Minting failed: {result['error']}")
                return None
                
        except requests.exceptions.RequestException as e:
            print(f"✗ API Error: {e}")
            return None

# Usage in your prediction pipeline
def predict_yield(farm_data):
    # ... Your ML prediction code ...
    
    prediction = {
        'farmerId': farm_data['farmer_id'],
        'farmId': farm_data['farm_id'],
        'cropType': farm_data['crop'],
        'season': f"2024-Q{(datetime.now().month - 1) // 3 + 1}",
        'predictedYield': ml_model.predict(farm_data),
        'confidenceScore': ml_model.confidence(),
        'ipfsHash': upload_to_ipfs(farm_data)
    }
    
    # Mint token immediately after prediction
    minter = BlockchainMinter()
    token_result = minter.mint_yield_token(prediction)
    
    return {
        'prediction': prediction,
        'tokenId': token_result['yieldTokenId'] if token_result else None
    }
```

### ML System Code (Node.js Example)

```javascript
const axios = require('axios');

class BlockchainMinter {
  constructor(apiUrl = 'http://localhost:5000') {
    this.apiUrl = apiUrl;
  }

  async mintYieldToken(predictionData) {
    /**
     * Call backend API to mint yield token
     * @param {Object} predictionData - Prediction from ML model
     */
    const endpoint = `${this.apiUrl}/api/yield/mint-token`;

    const payload = {
      farmerId: predictionData.farmerId,
      farmId: predictionData.farmId,
      cropType: predictionData.cropType,
      season: predictionData.season,
      predictedYield: parseFloat(predictionData.predictedYield),
      confidenceScore: parseFloat(predictionData.confidenceScore),
      ipfsHash: predictionData.ipfsHash || '',
      modelVersion: 'v2.1'
    };

    try {
      const response = await axios.post(endpoint, payload, {
        timeout: 30000,
        headers: { 'Content-Type': 'application/json' }
      });

      if (response.data.success) {
        console.log(`✓ Token minted: ${response.data.data.yieldTokenId}`);
        console.log(`  TX: ${response.data.data.transactionHash}`);
        return response.data.data;
      } else {
        console.log(`✗ Minting failed: ${response.data.error}`);
        return null;
      }
    } catch (error) {
      console.error(`✗ API Error: ${error.message}`);
      return null;
    }
  }
}

// Usage in prediction pipeline
async function predictYield(farmData) {
  // ... Your ML prediction code ...
  
  const prediction = {
    farmerId: farmData.farmer_id,
    farmId: farmData.farm_id,
    cropType: farmData.crop,
    season: `2024-Q${Math.ceil(new Date().getMonth() / 3)}`,
    predictedYield: mlModel.predict(farmData),
    confidenceScore: mlModel.confidence(),
    ipfsHash: await uploadToIPFS(farmData)
  };

  // Mint token after prediction
  const minter = new BlockchainMinter();
  const tokenResult = await minter.mintYieldToken(prediction);

  return {
    prediction,
    tokenId: tokenResult?.yieldTokenId
  };
}
```

## Step 2: Store Farmer IDs

Before predictions can be minted as tokens, farmers need wallets.

### Create Farmer and Get ID

```python
import requests

def create_farmer(farmer_info):
    """Create farmer wallet and get farmerId"""
    response = requests.post(
        'http://localhost:5000/api/farmers',
        json={
            'name': farmer_info['name'],
            'email': farmer_info['email'],
            'phone': farmer_info['phone'],
            'farmLocation': farmer_info['location'],
            'farmSize': farmer_info['hectares'],
            'cropType': farmer_info['crop']
        }
    )
    
    if response.status_code == 201:
        data = response.json()['data']
        farmer_id = data['farmerId']
        wallet = data['walletAddress']
        
        print(f"✓ Farmer created: {farmer_id}")
        print(f"✓ Wallet: {wallet}")
        print(f"✓ Save mnemonic safely!")
        
        # IMPORTANT: Store farmerId in your database
        # You'll need it for every prediction from this farmer
        return farmer_id
    else:
        print(f"✗ Failed: {response.json()['error']}")
        return None
```

### Map Farms to Farmer IDs

```python
# In your ML system database/config
FARM_BLOCKCHAIN_MAPPING = {
    'FARM-2024-001': {
        'farmer_id': '550e8400-e29b-41d4-a716-446655440000',
        'wallet': '0x742d35Cc6634C0532925a3b844Bc9e7595f42bE'
    },
    'FARM-2024-002': {
        'farmer_id': '660e8400-e29b-41d4-a716-446655440001',
        'wallet': '0x852d35Cc6634C0532925a3b844Bc9e7595f42bF'
    },
    # ... more farms
}

# Use in prediction
def get_farmer_id(farm_id):
    return FARM_BLOCKCHAIN_MAPPING[farm_id]['farmer_id']
```

## Step 3: Upload to IPFS (Optional)

Store prediction metadata on IPFS for permanent record.

### Python Example

```python
import requests
import json
from pinata import PinataAPI

def upload_prediction_metadata(prediction_data):
    """Upload prediction data to IPFS"""
    
    metadata = {
        'type': 'agri_yield_prediction',
        'version': '1.0',
        'farm_id': prediction_data['farmId'],
        'crop_type': prediction_data['cropType'],
        'season': prediction_data['season'],
        'predicted_yield': prediction_data['predictedYield'],
        'confidence_score': prediction_data['confidenceScore'],
        'model_version': 'v2.1',
        'timestamp': datetime.utcnow().isoformat()
    }
    
    # Upload to Pinata (IPFS pinning service)
    pinata = PinataAPI(
        api_key='YOUR_PINATA_KEY',
        api_secret='YOUR_PINATA_SECRET'
    )
    
    response = pinata.pin_json_to_ipfs(metadata)
    
    if response['success']:
        ipfs_hash = response['IpfsHash']
        print(f"✓ Metadata pinned to IPFS: {ipfs_hash}")
        return ipfs_hash
    else:
        print(f"✗ IPFS upload failed")
        return None
```

## Step 4: Handle Responses

Track minting transactions and token IDs.

```python
def handle_minting_response(mint_result, prediction_data):
    """Process successful minting response"""
    
    if not mint_result:
        print("✗ Minting failed - handle error")
        # Log error, send alert, etc.
        return False
    
    # Extract token ID for future loan requests
    yield_token_id = mint_result['yieldTokenId']
    tx_hash = mint_result['transactionHash']
    
    # Store in your database
    store_token_mapping({
        'farm_id': prediction_data['farmId'],
        'farmer_id': prediction_data['farmerId'],
        'token_id': yield_token_id,
        'tx_hash': tx_hash,
        'predicted_yield': prediction_data['predictedYield'],
        'confidence': prediction_data['confidenceScore'],
        'minted_at': datetime.utcnow()
    })
    
    print(f"✓ Token {yield_token_id} minted successfully")
    print(f"✓ TX: {tx_hash}")
    
    # Token is now available for:
    # 1. Farmer to view in dashboard
    # 2. Farmer to use as collateral for loans
    # 3. Oracle to update with actual yield
    
    return True
```

## Step 5: Implement Error Handling

```python
import time
from functools import wraps

def retry_on_failure(max_retries=3, backoff=2):
    """Decorator to retry API calls"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_retries - 1:
                        raise
                    wait_time = backoff ** attempt
                    print(f"⚠️  Retry {attempt + 1}/{max_retries} in {wait_time}s")
                    time.sleep(wait_time)
        return wrapper
    return decorator

@retry_on_failure(max_retries=3)
def mint_with_retry(prediction_data):
    minter = BlockchainMinter()
    return minter.mintYieldToken(prediction_data)

# Usage
try:
    result = mint_with_retry(prediction)
except Exception as e:
    print(f"✗ Failed after retries: {e}")
    # Send alert, log error, etc.
```

## Step 6: Monitor Minting Pipeline

```python
class MintingMonitor:
    def __init__(self, api_url='http://localhost:5000'):
        self.api_url = api_url
    
    def get_farmer_tokens(self, farmer_id):
        """Get all tokens minted for a farmer"""
        response = requests.get(
            f'{self.api_url}/api/yield/farmer/{farmer_id}'
        )
        if response.ok:
            tokens = response.json()['data']
            return tokens
        return []
    
    def get_token_status(self, token_id):
        """Check token status"""
        response = requests.get(
            f'{self.api_url}/api/yield/{token_id}'
        )
        if response.ok:
            return response.json()['data']
        return None
    
    def get_prediction_accuracy(self, token_id):
        """Get prediction accuracy after harvest"""
        response = requests.get(
            f'{self.api_url}/api/yield/{token_id}/accuracy'
        )
        if response.ok:
            return response.json()['data']
        return None

# Monitor your model performance
monitor = MintingMonitor()

# After harvest data arrives
tokens = monitor.get_farmer_tokens(farmer_id)
for token in tokens:
    accuracy = monitor.get_prediction_accuracy(token['token_id'])
    if accuracy:
        print(f"Token {token['id']}: {accuracy['accuracy']} accuracy")
```

## Step 7: Testing

### Local Testing

```bash
# Start backend
cd backend
npm run dev

# Test endpoint
curl -X POST http://localhost:5000/api/yield/mint-token \
  -H "Content-Type: application/json" \
  -d '{
    "farmerId": "test-farmer-123",
    "farmId": "FARM-2024-001",
    "cropType": "Sugarcane",
    "season": "2024-Q1",
    "predictedYield": 125.5,
    "confidenceScore": 87.3
  }'
```

### Integration Test

```python
import unittest
import requests
from time import sleep

class TestBlockchainIntegration(unittest.TestCase):
    def setUp(self):
        self.api_url = 'http://localhost:5000'
    
    def test_end_to_end_minting(self):
        """Test: Create farmer → Predict → Mint token"""
        
        # 1. Create farmer
        farmer_response = requests.post(
            f'{self.api_url}/api/farmers',
            json={
                'name': 'Test Farmer',
                'email': 'test@farm.com',
                'farmLocation': 'Test Farm',
                'farmSize': 5,
                'cropType': 'Rice'
            }
        )
        self.assertEqual(farmer_response.status_code, 201)
        farmer_id = farmer_response.json()['data']['farmerId']
        
        # 2. Mint token
        mint_response = requests.post(
            f'{self.api_url}/api/yield/mint-token',
            json={
                'farmerId': farmer_id,
                'farmId': 'FARM-TEST-001',
                'cropType': 'Rice',
                'season': '2024-Q1',
                'predictedYield': 120.5,
                'confidenceScore': 85.0
            }
        )
        self.assertEqual(mint_response.status_code, 201)
        token_id = mint_response.json()['data']['yieldTokenId']
        
        # 3. Verify token created
        sleep(2)  # Wait for DB write
        token_response = requests.get(
            f'{self.api_url}/api/yield/{token_id}'
        )
        self.assertEqual(token_response.status_code, 200)
        token = token_response.json()['data']
        self.assertEqual(token['predicted_yield'], 120.5)
        self.assertEqual(token['confidence_score'], 85.0)

if __name__ == '__main__':
    unittest.main()
```

## Production Checklist

- [ ] Setup `.env` with real contract addresses
- [ ] Configure ETHEREUM_RPC_URL (Infura, Alchemy, etc.)
- [ ] Setup IPFS pinning (Pinata, NFT.storage, etc.)
- [ ] Implement API key authentication
- [ ] Add rate limiting (max predictions/day per farmer)
- [ ] Setup monitoring and alerting
- [ ] Implement database backups
- [ ] Test with real farmersand data
- [ ] Deploy backend to production server
- [ ] Configure domain and SSL
- [ ] Document API in postman/swagger
- [ ] Train team on API usage

## Troubleshooting

### Issue: "Farmer not found"
**Solution**: Make sure farmerId is registered before minting
```python
farmer_id = create_farmer(farmer_data)  # Get ID first
# Then use this ID for all predictions
```

### Issue: Backend API returns 500
**Solution**: Check backend logs
```bash
tail -f backend/logs/error.log
tail -f backend/logs/combined.log
```

### Issue: Tokens not appearing on blockchain
**Solution**: Verify contract address in `.env`
```bash
# Check config
cat backend/.env | grep AGRI_YIELD_TOKEN_ADDRESS
```

### Issue: Slow transaction confirmation
**Solution**: Check gas settings and network
```javascript
// In contract service
GAS_PRICE_MULTIPLIER=1.5  // Increase in .env
```

## Support

For issues:
1. Check logs: `backend/logs/`
2. Verify `.env` configuration
3. Test API endpoints with curl
4. Check blockchain explorer for transaction status
5. Review database: `backend/data/agritech.db`
