from __future__ import annotations

import os
import pickle
import json
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Union

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

DB_PATH = Path(os.getenv("AGRICHAIN_DB_PATH", str(BASE_DIR / "agrichain.db")))


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _db_connect() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def _db_init() -> None:
    with _db_connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS contracts (
                id TEXT PRIMARY KEY,
                crop TEXT NOT NULL,
                quantity_kg REAL NOT NULL,
                unit_price REAL NOT NULL,
                currency TEXT NOT NULL,
                status TEXT NOT NULL,
                farmer_name TEXT NOT NULL,
                buyer_name TEXT,
                evidence_hash TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS ledger_events (
                id TEXT PRIMARY KEY,
                time TEXT NOT NULL,
                action TEXT NOT NULL,
                actor TEXT NOT NULL,
                contract_id TEXT NOT NULL,
                meta_json TEXT NOT NULL
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ledger_contract_id ON ledger_events (contract_id)")


@app.on_event("startup")
def _on_startup() -> None:
    _db_init()


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


class ContractCreateRequest(BaseModel):
    crop: str = "Maize"
    quantity_kg: float
    unit_price: float
    currency: str = "UGX"
    farmer_name: str
    evidence_hash: Optional[str] = None


class ContractPurchaseRequest(BaseModel):
    buyer_name: str


class ContractDeliverRequest(BaseModel):
    actor: str
    ref: Optional[str] = None


class ContractResponse(BaseModel):
    id: str
    crop: str
    quantity_kg: float
    unit_price: float
    currency: str
    status: str
    farmer_name: str
    buyer_name: Optional[str] = None
    evidence_hash: Optional[str] = None
    created_at: str

    @property
    def total(self) -> float:
        return self.quantity_kg * self.unit_price


class LedgerEventResponse(BaseModel):
    id: str
    time: str
    action: str
    actor: str
    contract_id: str
    meta: Dict[str, str]


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


def _row_to_contract(row: sqlite3.Row) -> ContractResponse:
    return ContractResponse(
        id=str(row["id"]),
        crop=str(row["crop"]),
        quantity_kg=float(row["quantity_kg"]),
        unit_price=float(row["unit_price"]),
        currency=str(row["currency"]),
        status=str(row["status"]),
        farmer_name=str(row["farmer_name"]),
        buyer_name=(str(row["buyer_name"]) if row["buyer_name"] is not None else None),
        evidence_hash=(str(row["evidence_hash"]) if row["evidence_hash"] is not None else None),
        created_at=str(row["created_at"]),
    )


def _insert_ledger_event(
    conn: sqlite3.Connection,
    *,
    action: str,
    actor: str,
    contract_id: str,
    meta: Dict[str, str],
) -> str:
    event_id = f"L-{uuid.uuid4().hex[:12]}"
    conn.execute(
        "INSERT INTO ledger_events (id, time, action, actor, contract_id, meta_json) VALUES (?, ?, ?, ?, ?, ?)",
        (event_id, _utc_now_iso(), action, actor, contract_id, json.dumps(meta, ensure_ascii=False)),
    )
    return event_id


@app.get("/contracts", response_model=List[ContractResponse])
async def list_contracts(status: Optional[str] = None):
    _db_init()
    with _db_connect() as conn:
        if status:
            rows = conn.execute(
                "SELECT * FROM contracts WHERE LOWER(status)=LOWER(?) ORDER BY created_at DESC",
                (status,),
            ).fetchall()
        else:
            rows = conn.execute("SELECT * FROM contracts ORDER BY created_at DESC").fetchall()
        return [_row_to_contract(r) for r in rows]


@app.post("/contracts", response_model=ContractResponse)
async def create_contract(payload: ContractCreateRequest):
    if payload.quantity_kg <= 0:
        raise HTTPException(status_code=400, detail="quantity_kg must be > 0")
    if payload.unit_price <= 0:
        raise HTTPException(status_code=400, detail="unit_price must be > 0")
    if not payload.farmer_name.strip():
        raise HTTPException(status_code=400, detail="farmer_name is required")

    contract_id = f"FH-{uuid.uuid4().hex[:12]}"
    now = _utc_now_iso()

    _db_init()
    with _db_connect() as conn:
        conn.execute(
            """
            INSERT INTO contracts (
                id, crop, quantity_kg, unit_price, currency, status,
                farmer_name, buyer_name, evidence_hash, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                contract_id,
                payload.crop,
                float(payload.quantity_kg),
                float(payload.unit_price),
                payload.currency,
                "LISTED",
                payload.farmer_name.strip(),
                None,
                payload.evidence_hash,
                now,
                now,
            ),
        )
        _insert_ledger_event(
            conn,
            action="MINT_AND_LIST",
            actor=payload.farmer_name.strip(),
            contract_id=contract_id,
            meta={"crop": payload.crop, "currency": payload.currency},
        )
        row = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=500, detail="Failed to create contract")
        return _row_to_contract(row)


@app.post("/contracts/{contract_id}/purchase", response_model=ContractResponse)
async def purchase_contract(contract_id: str, payload: ContractPurchaseRequest):
    if not payload.buyer_name.strip():
        raise HTTPException(status_code=400, detail="buyer_name is required")

    _db_init()
    with _db_connect() as conn:
        row = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Contract not found")
        if str(row["status"]).upper() != "LISTED":
            raise HTTPException(status_code=400, detail=f"Contract not purchasable (status={row['status']})")

        now = _utc_now_iso()
        conn.execute(
            "UPDATE contracts SET status=?, buyer_name=?, updated_at=? WHERE id=?",
            ("PURCHASED", payload.buyer_name.strip(), now, contract_id),
        )
        _insert_ledger_event(
            conn,
            action="PURCHASE",
            actor=payload.buyer_name.strip(),
            contract_id=contract_id,
            meta={"status": "PURCHASED"},
        )
        updated = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        return _row_to_contract(updated)


@app.post("/contracts/{contract_id}/deliver", response_model=ContractResponse)
async def deliver_contract(contract_id: str, payload: ContractDeliverRequest):
    if not payload.actor.strip():
        raise HTTPException(status_code=400, detail="actor is required")

    _db_init()
    with _db_connect() as conn:
        row = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Contract not found")
        if str(row["status"]).upper() != "PURCHASED":
            raise HTTPException(status_code=400, detail=f"Contract not deliverable (status={row['status']})")

        now = _utc_now_iso()
        conn.execute(
            "UPDATE contracts SET status=?, updated_at=? WHERE id=?",
            ("DELIVERED", now, contract_id),
        )
        meta: Dict[str, str] = {"status": "DELIVERED"}
        if payload.ref:
            meta["ref"] = payload.ref
        _insert_ledger_event(
            conn,
            action="DELIVERY_RECORDED",
            actor=payload.actor.strip(),
            contract_id=contract_id,
            meta=meta,
        )
        updated = conn.execute("SELECT * FROM contracts WHERE id=?", (contract_id,)).fetchone()
        return _row_to_contract(updated)


@app.get("/ledger", response_model=List[LedgerEventResponse])
async def list_ledger(contract_id: Optional[str] = None, limit: int = 100):
    _db_init()
    limit = max(1, min(int(limit), 500))

    with _db_connect() as conn:
        if contract_id:
            rows = conn.execute(
                "SELECT * FROM ledger_events WHERE contract_id=? ORDER BY time DESC LIMIT ?",
                (contract_id, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM ledger_events ORDER BY time DESC LIMIT ?",
                (limit,),
            ).fetchall()

        events: List[LedgerEventResponse] = []
        for r in rows:
            try:
                meta_obj = json.loads(str(r["meta_json"]))
                if not isinstance(meta_obj, dict):
                    meta_obj = {}
                meta = {str(k): str(v) for k, v in meta_obj.items()}
            except Exception:
                meta = {}
            events.append(
                LedgerEventResponse(
                    id=str(r["id"]),
                    time=str(r["time"]),
                    action=str(r["action"]),
                    actor=str(r["actor"]),
                    contract_id=str(r["contract_id"]),
                    meta=meta,
                )
            )
        return events


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
