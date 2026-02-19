# Runbook: Go API Gateway + Python ML Service

This project runs as a **two-service** backend:

- **Go API Gateway** (primary API for Flutter)
  - Serves REST endpoints used by Flutter
  - Owns the central SQLite database
  - Proxies ML prediction requests to Python
  - Preserves legacy `/blockchain/*` routes for backward compatibility

- **Python ML Service (FastAPI)**
  - ML-only service that exposes `/predict` (and `/batch-predict`)

## Ports

- **Go Gateway**: `8000`
- **Python ML**: `8001`

## Environment variables

### Go gateway (`agri-chain/server`)

- `PORT` (default `8000`)
- `SQLITE_PATH` (default `./data/agrichain.db`)
- `ML_BASE_URL` (default `http://127.0.0.1:8001`)
- `GOOGLE_APPLICATION_CREDENTIALS` (optional; enables Firebase auth for `/v1/*`)

### Yield Prediction Integration

- `YIELD_API_BASE_URL` (optional)
  - If empty, it defaults to `ML_BASE_URL`.
  - Set this to your external Yield API base URL if you want the gateway to call it directly.

### Huawei Blockchain Cloud Service (BCS)

- `BLOCKCHAIN_MODE`
  - `mock` (default): no external blockchain dependency
  - `bcs`: enable Huawei BCS adapter
- `BCS_ENDPOINT`
  - Full HTTP URL for invoking chaincode (tenant-specific).
  - If empty, the BCS client falls back to a local mock.
- `BCS_ACCESS_KEY`, `BCS_SECRET_KEY`
  - Optional headers used by the built-in HTTP client.
  - If your BCS gateway uses a different auth mechanism, adjust `internal/blockchain/bcs/http_client.go`.

### Python ML service (`backend/backend`)

- `MAIZE_MODEL_PATH`
- `MAIZE_PREPROCESSING_PATH`
- `CORS_ORIGINS`

## Start services

## Start services (Docker Compose)

From: repo root (`agrichain/`)

1) Create `.env` from `.env.example`

2) Set `FIREBASE_CREDENTIALS_PATH` to an absolute path to your Firebase service account JSON

3) Start both services:

```bash
docker compose up --build
```

Gateway will be available on:

- `http://localhost:8000`

ML service will be available on:

- `http://localhost:8001`

### 1) Start Python ML service

From: `backend/backend`

```bash
pip install -r requirements.txt
uvicorn app:app --reload --host 0.0.0.0 --port 8001
```

### 2) Start Go API Gateway

From: `agri-chain/server`

```bash
go run ./cmd/api
```

## Flutter base URL notes

Flutter uses `AppConfig.apiBaseUrl`.

- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://localhost:8000`
- Physical device: `http://<your-pc-lan-ip>:8000`

## API Overview

### Public endpoints (no auth)

- `POST /predict` (proxies to ML service)
- `GET /contracts`
- `POST /contracts`
- `POST /contracts/{id}/purchase`
- `POST /contracts/{id}/deliver`
- `GET /ledger`
- `ANY /blockchain/*` (legacy compatibility)

### Authenticated endpoints (`/v1`)

These require:

```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
```

- `GET /v1/me`
- `GET /v1/contracts`
- `GET /v1/ledger`
- `POST /v1/predict`

RBAC (roles from SQLite):

- `POST /v1/contracts`
  - Roles: `farmer` or `admin`
- `POST /v1/contracts/{id}/deliver`
  - Roles: `farmer` or `admin`
- `POST /v1/contracts/{id}/purchase`
  - Roles: `bank`, `investor`, or `admin`

## Smoke tests (curl)

### Predict (public)

```bash
curl -s -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"region":"Central","soil_type":"Loam","rainfall_mm":100,"temperature_celsius":25,"fertilizer_used":true,"irrigation_used":false,"weather_condition":"Sunny","days_to_harvest":90}'
```

### Contracts lifecycle (public)

```bash
# Create
CID=$(curl -s -X POST http://localhost:8000/contracts \
  -H "Content-Type: application/json" \
  -d '{"crop":"Maize","quantity_kg":100,"unit_price":2.5,"currency":"UGX","farmer_name":"Farmer A"}' | python -c "import sys,json; print(json.load(sys.stdin)['id'])")

# Purchase
curl -s -X POST http://localhost:8000/contracts/$CID/purchase \
  -H "Content-Type: application/json" \
  -d '{"buyer_name":"Buyer B"}'

# Deliver
curl -s -X POST http://localhost:8000/contracts/$CID/deliver \
  -H "Content-Type: application/json" \
  -d '{"actor":"Farmer A","ref":"REF-1"}'

# Ledger
curl -s "http://localhost:8000/ledger?contract_id=$CID&limit=10"
```

## Notes

- If `GOOGLE_APPLICATION_CREDENTIALS` is not set, `/v1/*` endpoints will return `401`.
- SQLite migrations run automatically on Go startup.
