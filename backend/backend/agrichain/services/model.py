from __future__ import annotations

import pickle
from pathlib import Path
from typing import Optional

import joblib

from agrichain.core.config import MODEL_PATH, PREPROCESSING_PATH, BASE_DIR

_model = None
_preprocessing_info = None


def get_model_name(preprocessing_info: dict) -> Optional[str]:
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


def load_artifacts() -> tuple[object, dict]:
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
