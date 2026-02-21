from __future__ import annotations

import pickle
from pathlib import Path
from typing import Optional

import joblib

from agrichain.core.config import BASE_DIR, FEATURES_PATH, MODEL_PATH, PREPROCESSING_PATH

_model = None
_preprocessing_info = None


def _load_pickle_or_joblib(path: Path) -> object:
    try:
        return joblib.load(str(path))
    except Exception:
        with open(path, "rb") as f:
            return pickle.load(f)


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


def _resolve_features_path() -> Optional[Path]:
    features_path = FEATURES_PATH
    if features_path.exists():
        return features_path

    detected = _pick_first("feature_names*.pkl")
    if detected is None:
        detected = _pick_first("*feature*names*.pkl")
    return detected


def load_artifacts() -> tuple[object, dict]:
    global _model, _preprocessing_info

    if _model is not None and _preprocessing_info is not None:
        return _model, _preprocessing_info

    model_path, preprocessing_path = _resolve_paths()
    features_path = _resolve_features_path()

    if not model_path.exists():
        raise FileNotFoundError(
            f"Model file not found at '{MODEL_PATH}'. Set MAIZE_MODEL_PATH or place a .joblib file in backend/."
        )

    if not preprocessing_path.exists():
        raise FileNotFoundError(
            f"Preprocessing info file not found at '{PREPROCESSING_PATH}'. Set MAIZE_PREPROCESSING_PATH or place a .pkl file in backend/."
        )

    if features_path is None or not features_path.exists():
        raise FileNotFoundError(
            f"Feature names file not found at '{FEATURES_PATH}'. Set MAIZE_FEATURES_PATH or place a feature_names*.pkl file in backend/."
        )

    _model = _load_pickle_or_joblib(model_path)

    scaler = _load_pickle_or_joblib(preprocessing_path)
    feature_names = _load_pickle_or_joblib(features_path)

    if isinstance(feature_names, dict) and "feature_names" in feature_names:
        feature_names = feature_names["feature_names"]

    if not isinstance(feature_names, (list, tuple)):
        raise ValueError("Invalid feature names: expected a list/tuple.")

    _preprocessing_info = {
        "feature_names": list(feature_names),
        "scaler": scaler,
        "best_model_name": type(_model).__name__,
    }

    return _model, _preprocessing_info
