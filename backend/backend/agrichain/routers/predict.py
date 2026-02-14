from __future__ import annotations

from typing import List, Optional, Union

import pandas as pd
from fastapi import APIRouter, Body, HTTPException
from pydantic import BaseModel

from agrichain.services.model import get_model_name, load_artifacts

router = APIRouter()


class PredictionRequest(BaseModel):
    region: str
    soil_type: str
    rainfall_mm: float
    temperature_celsius: float
    fertilizer_used: bool
    irrigation_used: bool
    weather_condition: str
    days_to_harvest: int


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

        data = pd.DataFrame(
            [
                {
                    "Region": request.region,
                    "Soil_Type": request.soil_type,
                    "Crop": "Maize",
                    "Rainfall_mm": request.rainfall_mm,
                    "Temperature_Celsius": request.temperature_celsius,
                    "Fertilizer_Used": request.fertilizer_used,
                    "Irrigation_Used": request.irrigation_used,
                    "Weather_Condition": request.weather_condition,
                    "Days_to_Harvest": request.days_to_harvest,
                }
            ]
        )

        feature_names = preprocessing_info["feature_names"]
        data = data[feature_names]

        prediction = model.predict(data)

        return PredictionResponse(
            predicted_yield=float(prediction[0]),
            confidence=None,
            message=f"Prediction successful using {model_name}",
        )

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/batch-predict")
async def batch_predict_yield(payload: Union[List[PredictionRequest], BatchPredictionRequest] = Body(...)):
    try:
        model, preprocessing_info = load_artifacts()
        model_name = get_model_name(preprocessing_info)

        requests = payload.requests if isinstance(payload, BatchPredictionRequest) else payload

        rows = []
        for r in requests:
            rows.append(
                {
                    "Region": r.region,
                    "Soil_Type": r.soil_type,
                    "Crop": "Maize",
                    "Rainfall_mm": r.rainfall_mm,
                    "Temperature_Celsius": r.temperature_celsius,
                    "Fertilizer_Used": r.fertilizer_used,
                    "Irrigation_Used": r.irrigation_used,
                    "Weather_Condition": r.weather_condition,
                    "Days_to_Harvest": r.days_to_harvest,
                }
            )

        data = pd.DataFrame(rows)
        feature_names = preprocessing_info["feature_names"]
        data = data[feature_names]

        preds = model.predict(data)

        predictions = []
        for i, r in enumerate(requests):
            predictions.append(
                {
                    "region": r.region,
                    "soil_type": r.soil_type,
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
