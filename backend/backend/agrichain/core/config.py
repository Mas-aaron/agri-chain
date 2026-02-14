from __future__ import annotations

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[2]

_DEFAULT_MODEL_PATH = BASE_DIR / "maize_yield_linear_regression_20250113_141237.joblib"
_DEFAULT_PREPROCESSING_PATH = BASE_DIR / "maize_yield_preprocessing_info_20250113_141237.pkl"

MODEL_PATH = Path(os.getenv("MAIZE_MODEL_PATH", str(_DEFAULT_MODEL_PATH)))
PREPROCESSING_PATH = Path(os.getenv("MAIZE_PREPROCESSING_PATH", str(_DEFAULT_PREPROCESSING_PATH)))

ALLOWED_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

DB_PATH = Path(os.getenv("AGRICHAIN_DB_PATH", str(BASE_DIR / "agrichain.db")))
