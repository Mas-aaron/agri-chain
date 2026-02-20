import json
import asyncio
import hashlib
import os
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
    ML_MODEL_ENDPOINT = os.getenv("ML_MODEL_ENDPOINT", "http://yield-engine:8000/predict")
    MODEL_VERSION = os.getenv("MODEL_VERSION", "agrichain-maize-v1")

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
    confidence: Optional[float] = Field(None, ge=0, le=1)
    prediction_date: datetime
    model_version: str
    features: Dict[str, float]


class AgronomyInputs(BaseModel):
    nitrogen: float
    phosphorus: float
    potassium: float
    temperature: float
    humidity: float
    ph: float
    rainfall: float
    pesticide: float


class PredictAndTokenizeRequest(BaseModel):
    farm_id: str
    farmer_id: str
    crop_type: str = "Maize"
    season: int
    inputs: AgronomyInputs
    farmer_did: Optional[str] = None
    metadata: Optional[Dict] = None

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
    async def fetch_yield_prediction(self, *, inputs: AgronomyInputs) -> float:
        payload = inputs.dict()
        timeout = aiohttp.ClientTimeout(total=20)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(config.ML_MODEL_ENDPOINT, json=payload) as resp:
                text = await resp.text()
                if resp.status >= 400:
                    raise HTTPException(status_code=502, detail=f"Yield engine error ({resp.status}): {text}")
                try:
                    data = json.loads(text)
                except Exception:
                    raise HTTPException(status_code=502, detail=f"Invalid yield engine response: {text}")

        predicted = data.get("predicted_yield")
        if predicted is None:
            raise HTTPException(status_code=502, detail=f"Yield engine response missing predicted_yield: {data}")
        try:
            return float(predicted)
        except Exception:
            raise HTTPException(status_code=502, detail=f"Invalid predicted_yield value: {predicted}")

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


@app.post("/api/v1/predict-and-tokenize", response_model=TokenizedAsset)
async def predict_and_tokenize(request: PredictAndTokenizeRequest):
    try:
        predicted_yield = await service.fetch_yield_prediction(inputs=request.inputs)
        if predicted_yield <= 0:
            raise HTTPException(status_code=400, detail=f"Predicted yield must be > 0, got {predicted_yield}")

        prediction = MLPrediction(
            farm_id=request.farm_id,
            farmer_id=request.farmer_id,
            crop_type=request.crop_type,
            season=request.season,
            predicted_yield_kg=predicted_yield,
            confidence=None,
            prediction_date=datetime.utcnow(),
            model_version=config.MODEL_VERSION,
            features=request.inputs.dict(),
        )

        token_req = TokenizationRequest(
            prediction=prediction,
            rover_data=None,
            farmer_did=request.farmer_did,
            metadata=request.metadata,
        )

        asset = await service.tokenize_yield_prediction(token_req)
        return asset
    except HTTPException:
        raise
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
