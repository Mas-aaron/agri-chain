from __future__ import annotations

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[2]

_DEFAULT_MODEL_PATH = BASE_DIR / "maize_model_package" / "maize_model" / "best_model.pkl"
_DEFAULT_PREPROCESSING_PATH = BASE_DIR / "maize_model_package" / "maize_model" / "scaler.pkl"
_DEFAULT_FEATURES_PATH = BASE_DIR / "maize_model_package" / "maize_model" / "feature_names.pkl"

MODEL_PATH = Path(os.getenv("MAIZE_MODEL_PATH", str(_DEFAULT_MODEL_PATH)))
PREPROCESSING_PATH = Path(os.getenv("MAIZE_PREPROCESSING_PATH", str(_DEFAULT_PREPROCESSING_PATH)))
FEATURES_PATH = Path(os.getenv("MAIZE_FEATURES_PATH", str(_DEFAULT_FEATURES_PATH)))

ALLOWED_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

DB_PATH = Path(os.getenv("AGRICHAIN_DB_PATH", str(BASE_DIR / "agrichain.db")))
