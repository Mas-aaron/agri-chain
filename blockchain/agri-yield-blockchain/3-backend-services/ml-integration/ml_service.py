import json
import asyncio
import hashlib
from datetime import datetime
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field
import aiohttp

app = FastAPI(title="AgriYield ML Integration Service")

# Configuration
class Config:
    BCS_INSTANCE_ID = "your-bcs-instance-id"
    BCS_REST_API = "https://your-bcs-rest-api"
    IPFS_ENDPOINT = "/ip4/127.0.0.1/tcp/5001"
    ETHEREUM_RPC = "https://mainnet.infura.io/v3/YOUR-PROJECT-ID"
    ML_MODEL_ENDPOINT = "http://ml-service:5000/predict"

config = Config()

# Pydantic Models
class RoverData(BaseModel):
    farm_id: str
    farmer_id: str
    coordinates: Dict[str, float]
    images: List[str] = []
    sensor_data: Dict[str, float]
    timestamp: datetime

class MLPrediction(BaseModel):
    farm_id: str
    farmer_id: str
    crop_type: str
    season: int
    predicted_yield_kg: float = Field(..., gt=0)
    confidence: float = Field(..., ge=0, le=1)
    prediction_date: datetime
    model_version: str
    features: Dict[str, float]

class TokenizationRequest(BaseModel):
    prediction: MLPrediction
    rover_data: Optional[RoverData] = None
    farmer_did: Optional[str] = None
    metadata: Optional[Dict] = None

class TokenizedAsset(BaseModel):
    asset_id: str
    token_id: str
    farmer_id: str
    token_amount: int
    transaction_hash: str
    bcs_tx_id: str
    ipfs_hash: str
    created_at: datetime

# Main Service
class AgriYieldMLService:
    async def tokenize_yield_prediction(self, 
                                       request: TokenizationRequest) -> TokenizedAsset:
        """
        Complete pipeline: ML Prediction → BCS Tokenization → Ethereum Minting
        """
        
        # Step 1: Generate unique asset ID
        asset_id = self._generate_asset_id(request.prediction)
        
        # Step 2: Create token
        token_amount = int(request.prediction.predicted_yield_kg)
        
        # Step 3: Store metadata
        metadata = {
            "prediction": request.prediction.dict(),
            "farmer_did": request.farmer_did,
            "timestamp": datetime.now().isoformat()
        }
        
        metadata_uri = f"ipfs://mock-hash-{hashlib.md5(str(metadata).encode()).hexdigest()}"
        
        # Step 4: Return tokenized asset
        return TokenizedAsset(
            asset_id=asset_id,
            token_id=f"AYW-{request.prediction.season}-{request.prediction.crop_type.upper()}-{asset_id[-6:]}",
            farmer_id=request.prediction.farmer_id,
            token_amount=token_amount,
            transaction_hash="0x" + hashlib.sha256(str(metadata).encode()).hexdigest(),
            bcs_tx_id=f"tx-{asset_id}",
            ipfs_hash=metadata_uri,
            created_at=datetime.now()
        )
    
    def _generate_asset_id(self, prediction: MLPrediction) -> str:
        """Generate unique asset ID"""
        base = f"{prediction.farm_id}_{prediction.crop_type}_{prediction.season}"
        timestamp = int(datetime.now().timestamp())
        unique_hash = hashlib.sha256(
            f"{base}_{timestamp}".encode()
        ).hexdigest()[:16]
        
        return f"ASSET_{unique_hash.upper()}"

# FastAPI Endpoints
service = AgriYieldMLService()

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ml-integration",
        "timestamp": datetime.now().isoformat()
    }

@app.post("/api/v1/tokenize-yield", response_model=TokenizedAsset)
async def tokenize_yield(request: TokenizationRequest):
    """
    Endpoint for ML service to tokenize yield predictions
    """
    try:
        asset = await service.tokenize_yield_prediction(request)
        return asset
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/assets/{asset_id}")
async def get_asset(asset_id: str):
    """
    Retrieve tokenized asset information
    """
    try:
        return {
            "asset_id": asset_id,
            "status": "active",
            "message": "Asset found"
        }
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))

@app.post("/api/v1/batch-tokenize")
async def batch_tokenize(requests: List[TokenizationRequest], background_tasks: BackgroundTasks):
    """
    Batch tokenization for multiple predictions
    """
    task_id = hashlib.md5(str(datetime.now()).encode()).hexdigest()[:8]
    
    async def process_batch(batch_requests: List[TokenizationRequest]):
        results = []
        for req in batch_requests:
            try:
                asset = await service.tokenize_yield_prediction(req)
                results.append({
                    "success": True,
                    "asset": asset.dict()
                })
            except Exception as e:
                results.append({
                    "success": False,
                    "error": str(e)
                })
    
    background_tasks.add_task(process_batch, requests)
    
    return {
        "task_id": task_id,
        "status": "processing",
        "count": len(requests),
        "message": f"Processing {len(requests)} predictions"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
