from __future__ import annotations

import os
import pickle
from pathlib import Path
from typing import List, Optional, Union

import joblib
import pandas as pd
from fastapi import Body, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Maize Yield Prediction API")

BASE_DIR = Path(__file__).resolve().parent
_DEFAULT_MODEL_PATH = BASE_DIR / "maize_yield_linear_regression_20250113_141237.joblib"
_DEFAULT_PREPROCESSING_PATH = BASE_DIR / "maize_yield_preprocessing_info_20250113_141237.pkl"
MODEL_PATH = Path(os.getenv("MAIZE_MODEL_PATH", str(_DEFAULT_MODEL_PATH)))
PREPROCESSING_PATH = Path(os.getenv("MAIZE_PREPROCESSING_PATH", str(_DEFAULT_PREPROCESSING_PATH)))

ALLOWED_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS if ALLOWED_ORIGINS else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_model = None
_preprocessing_info = None


def _get_model_name(preprocessing_info: dict) -> Optional[str]:
    return preprocessing_info.get("best_model_name") or preprocessing_info.get("model_type")


def _pick_first(pattern: str) -> Optional[Path]:
    matches = sorted(BASE_DIR.glob(pattern))
    return matches[0] if matches else None


def _resolve_paths() -> tuple[Path, Path]:
    model_path = MODEL_PATH
    preprocessing_path = PREPROCESSING_PATH

    if not model_path.exists():
        detected = _pick_first("*.joblib")
        if detected is not None:
            model_path = detected

    if not preprocessing_path.exists():
        detected = _pick_first("preprocessing_info*.pkl")
        if detected is None:
            detected = _pick_first("*.pkl")
        if detected is not None:
            preprocessing_path = detected

    return model_path, preprocessing_path


def _load_artifacts() -> tuple[object, dict]:
    global _model, _preprocessing_info

    if _model is not None and _preprocessing_info is not None:
        return _model, _preprocessing_info

    model_path, preprocessing_path = _resolve_paths()

    if not model_path.exists():
        raise FileNotFoundError(
            f"Model file not found at '{MODEL_PATH}'. Set MAIZE_MODEL_PATH or place a .joblib file in backend/."
        )

    if not preprocessing_path.exists():
        raise FileNotFoundError(
            f"Preprocessing info file not found at '{PREPROCESSING_PATH}'. Set MAIZE_PREPROCESSING_PATH or place a .pkl file in backend/."
        )

    _model = joblib.load(str(model_path))

    with open(preprocessing_path, "rb") as f:
        _preprocessing_info = pickle.load(f)

    if not isinstance(_preprocessing_info, dict):
        raise ValueError("Invalid preprocessing info: expected a dict.")

    if "feature_names" not in _preprocessing_info:
        raise ValueError("Invalid preprocessing info: missing 'feature_names'.")

    return _model, _preprocessing_info


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


@app.get("/")
async def root():
    try:
        _, preprocessing_info = _load_artifacts()
        model_name = _get_model_name(preprocessing_info)
        return {
            "message": "Maize Yield Prediction API",
            "model": model_name,
            "r2_score": preprocessing_info.get("best_r2_score"),
            "endpoints": {
                "/predict": "POST - Make single prediction",
                "/batch-predict": "POST - Make batch predictions",
                "/health": "GET - Check API health",
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
            },
        }


@app.get("/health")
async def health_check():
    try:
        _load_artifacts()
        return {"status": "healthy", "model_loaded": True}
    except Exception as e:
        return {"status": "healthy", "model_loaded": False, "error": str(e)}


@app.post("/predict", response_model=PredictionResponse)
async def predict_yield(request: PredictionRequest):
    try:
        model, preprocessing_info = _load_artifacts()
        model_name = _get_model_name(preprocessing_info) or "model"

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


@app.post("/batch-predict")
async def batch_predict_yield(
    payload: Union[List[PredictionRequest], BatchPredictionRequest] = Body(...)
):
    try:
        model, preprocessing_info = _load_artifacts()
        model_name = _get_model_name(preprocessing_info)

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
