from __future__ import annotations

import uuid
from typing import List, Optional, Union

import pandas as pd
from fastapi import APIRouter, Body, HTTPException
from pydantic import BaseModel

from agrichain.services.model import get_model_name, load_artifacts
from agrichain.services.blockchain_store import STORE

router = APIRouter()


class PredictionRequest(BaseModel):
    nitrogen: float
    phosphorus: float
    potassium: float
    temperature: float
    humidity: float
    ph: float
    rainfall: float
    pesticide: float


class YieldPredictionRequestV1(BaseModel):
    region: str
    soil_type: str
    rainfall_mm: float
    temperature_celsius: float
    fertilizer_used: bool
    irrigation_used: bool
    weather_condition: str
    days_to_harvest: int


def _build_feature_row(request: PredictionRequest) -> dict:
    n = float(request.nitrogen)
    p = float(request.phosphorus)
    k = float(request.potassium)
    t = float(request.temperature)
    h = float(request.humidity)
    ph_val = float(request.ph)
    r = float(request.rainfall)
    pest = float(request.pesticide)

    eps = 0.001

    fertilizer_total = n + p + k
    ratio_np = n / (p + eps)
    ratio_nk = n / (k + eps)

    return {
        "Nitrogen": n,
        "Phosphorus": p,
        "Potassium": k,
        "Temperature": t,
        "Humidity": h,
        "pH": ph_val,
        "Rainfall": r,
        "Pesticide": pest,
        "N_P_Interaction": n * p,
        "N_K_Interaction": n * k,
        "P_K_Interaction": p * k,
        "Temp_Rain_Interaction": t * r,
        "N_squared": n**2,
        "P_squared": p**2,
        "K_squared": k**2,
        "Temp_squared": t**2,
        "Rainfall_squared": r**2,
        "Fertilizer_Total": fertilizer_total,
        "Fertilizer_Ratio_NP": ratio_np,
        "Fertilizer_Ratio_NK": ratio_nk,
    }


class PredictionResponse(BaseModel):
    predicted_yield: float
    confidence: Optional[float] = None
    message: Optional[str] = None


class BatchPredictionRequest(BaseModel):
    requests: List[PredictionRequest]


@router.get("/")
async def root():
    try:
        _, preprocessing_info = load_artifacts()
        model_name = get_model_name(preprocessing_info)
        return {
            "message": "Maize Yield Prediction API",
            "model": model_name,
            "r2_score": preprocessing_info.get("best_r2_score"),
            "endpoints": {
                "/predict": "POST - Make single prediction",
                "/batch-predict": "POST - Make batch predictions",
                "/health": "GET - Check API health",
                "/contracts": "GET/POST - List or create future harvest contracts (SQLite demo)",
                "/contracts/{id}/purchase": "POST - Purchase a contract (SQLite demo)",
                "/contracts/{id}/deliver": "POST - Mark a contract delivered (SQLite demo)",
                "/ledger": "GET - List ledger events (SQLite demo)",
            },
        }
    except Exception as e:
        return {
            "message": "Maize Yield Prediction API",
            "model_loaded": False,
            "error": str(e),
            "endpoints": {
                "/predict": "POST - Make single prediction",
                "/batch-predict": "POST - Make batch predictions",
                "/health": "GET - Check API health",
                "/contracts": "GET/POST - List or create future harvest contracts (SQLite demo)",
                "/contracts/{id}/purchase": "POST - Purchase a contract (SQLite demo)",
                "/contracts/{id}/deliver": "POST - Mark a contract delivered (SQLite demo)",
                "/ledger": "GET - List ledger events (SQLite demo)",
            },
        }


@router.get("/health")
async def health_check():
    try:
        load_artifacts()
        return {"status": "healthy", "model_loaded": True}
    except Exception as e:
        return {"status": "healthy", "model_loaded": False, "error": str(e)}


@router.post("/predict", response_model=PredictionResponse)
async def predict_yield(request: PredictionRequest):
    try:
        model, preprocessing_info = load_artifacts()
        model_name = get_model_name(preprocessing_info) or "model"

        data = pd.DataFrame([_build_feature_row(request)])

        feature_names = preprocessing_info["feature_names"]
        data = data[feature_names]

        scaler = preprocessing_info.get("scaler")
        if scaler is not None and hasattr(scaler, "transform"):
            features = scaler.transform(data)
        else:
            features = data

        prediction = model.predict(features)

        return PredictionResponse(
            predicted_yield=float(prediction[0]),
            confidence=None,
            message=f"Prediction successful using {model_name}",
        )

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


class PredictAndTokenizeRequest(BaseModel):
    """Predict yield and automatically create a blockchain token asset."""
    # Farm/Farmer info
    farmerId: str
    farmerDid: Optional[str] = None
    farmId: Optional[str] = None
    cropType: str = "Maize"
    season: int = 2026
    # ML input features
    nitrogen: float
    phosphorus: float
    potassium: float
    temperature: float
    humidity: float
    ph: float
    rainfall: float
    pesticide: float


@router.post("/predict-and-tokenize")
async def predict_and_tokenize(request: PredictAndTokenizeRequest):
    """
    1. Runs the ML model to predict yield
    2. Creates a tokenized blockchain asset from the prediction
    3. Returns both the prediction and the new asset
    """
    try:
        # --- Step 1: Predict ---
        model, preprocessing_info = load_artifacts()
        model_name = get_model_name(preprocessing_info) or "model"

        pred_request = PredictionRequest(
            nitrogen=request.nitrogen,
            phosphorus=request.phosphorus,
            potassium=request.potassium,
            temperature=request.temperature,
            humidity=request.humidity,
            ph=request.ph,
            rainfall=request.rainfall,
            pesticide=request.pesticide,
        )
        data = pd.DataFrame([_build_feature_row(pred_request)])
        feature_names = preprocessing_info["feature_names"]
        data = data[feature_names]

        scaler = preprocessing_info.get("scaler")
        if scaler is not None and hasattr(scaler, "transform"):
            features = scaler.transform(data)
        else:
            features = data

        prediction = model.predict(features)
        predicted_yield = float(prediction[0])

        # --- Step 2: Tokenize ---
        asset_id = f"ASSET_{uuid.uuid4().hex[:12].upper()}"
        crop3 = (request.cropType or "CROP").upper()[:3]
        token_id = f"AYW-{request.season}-{crop3}-{asset_id[-3:]}"
        token_amount = predicted_yield
        current_value = predicted_yield * 5.0

        asset = STORE.create_asset(
            asset_id=asset_id,
            token_id=token_id,
            farmer_id=request.farmerId,
            crop_type=request.cropType,
            season=request.season,
            predicted_yield=predicted_yield,
            confidence=0.85,
            token_amount=token_amount,
            current_value=current_value,
            status="PREDICTED",
        )

        return {
            "prediction": {
                "predicted_yield": predicted_yield,
                "model": model_name,
                "confidence": 0.85,
            },
            "token": {
                "assetId": asset_id,
                "tokenId": token_id,
                "tokenAmount": token_amount,
                "currentValue": current_value,
                "status": "PREDICTED",
            },
            "asset": asset,
            "message": f"Yield predicted ({predicted_yield:.1f} kg) and tokenized as {token_id}",
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/v1/predict", response_model=PredictionResponse)
async def predict_yield_v1(payload: YieldPredictionRequestV1):
    try:
        rainfall = float(payload.rainfall_mm)
        temp = float(payload.temperature_celsius)
        days = int(payload.days_to_harvest)

        base = 2400.0

        rain_delta = (rainfall - 700.0) / 50.0
        base += (max(-6.0, min(6.0, rain_delta))) * 120.0

        t_delta = (temp - 26.0)
        base -= (min(8.0, abs(t_delta))) * 90.0

        if bool(payload.fertilizer_used):
            base += 420.0
        if bool(payload.irrigation_used):
            base += 260.0

        weather = str(payload.weather_condition or "").strip().lower()
        if weather == "dry":
            base -= 380.0
        elif weather == "wet":
            base -= 220.0
        elif weather == "stormy":
            base -= 520.0

        if days < 70:
            base -= (70 - days) * 35.0
        if days > 120:
            base -= (days - 120) * 20.0

        predicted = max(300.0, min(6500.0, base))

        return PredictionResponse(
            predicted_yield=float(predicted),
            confidence=None,
            message="Prediction generated by server (v1 heuristic).",
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/batch-predict")
async def batch_predict_yield(payload: Union[List[PredictionRequest], BatchPredictionRequest] = Body(...)):
    try:
        model, preprocessing_info = load_artifacts()
        model_name = get_model_name(preprocessing_info)

        requests = payload.requests if isinstance(payload, BatchPredictionRequest) else payload

        rows = [_build_feature_row(r) for r in requests]

        data = pd.DataFrame(rows)
        feature_names = preprocessing_info["feature_names"]
        data = data[feature_names]

        scaler = preprocessing_info.get("scaler")
        if scaler is not None and hasattr(scaler, "transform"):
            features = scaler.transform(data)
        else:
            features = data

        preds = model.predict(features)

        predictions = []
        for i, r in enumerate(requests):
            predictions.append(
                {
                    "nitrogen": r.nitrogen,
                    "phosphorus": r.phosphorus,
                    "potassium": r.potassium,
                    "temperature": r.temperature,
                    "humidity": r.humidity,
                    "ph": r.ph,
                    "rainfall": r.rainfall,
                    "pesticide": r.pesticide,
                    "predicted_yield": float(preds[i]),
                }
            )

        return {
            "predictions": predictions,
            "count": len(predictions),
            "model": model_name,
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
