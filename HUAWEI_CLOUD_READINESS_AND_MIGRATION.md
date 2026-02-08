# Huawei Cloud Readiness & Migration Guide (AgriChain)

This document explains:

- How to run the current MVP **now** (with the existing local/demo components).
- How to migrate the same MVP to **Huawei Cloud** once you receive resources (ECS/OBS/BCS/ModelArts).
- Additional features that improve competition scoring and product completeness.

## 1) Current MVP Scope (What Works Today)

### Roles (MVP)

- Farmer
  - On-device disease diagnosis (Flutter + TensorFlow Lite model in assets)
  - Online yield prediction (FastAPI backend)
  - Create “future harvest contract” (currently UI/demo)
- Buyer
  - Browse contracts (currently UI/demo)

Bank is intentionally deferred to Phase 2.

### Where the models live

- Disease diagnosis model (on-device)
  - `agri-chain/assets/maize_disease.tflite`
  - `agri-chain/assets/labels.txt`
  - Inference service: `agri-chain/lib/services/tflite_service.dart`

- Yield prediction model (online)
  - FastAPI app: `backend/backend/app.py`
  - Model artifacts: `backend/backend/*.joblib` and `backend/backend/*preprocessing_info*.pkl`
  - Endpoints:
    - `POST /predict`
    - `POST /batch-predict`

### Current limitations (expected)

- Blockchain screens are **simulation/demo** (`agri-chain/lib/screens/blockchain/*`).
- Huawei Cloud services are not yet integrated (no ECS/OBS/BCS/ModelArts wiring).

## 2) Run the MVP Now (Local/Dev)

### Backend (FastAPI)

1. Open a terminal in the `backend/` folder.
2. Install requirements:
   - `pip install -r requirements.txt`
3. Run:
   - `uvicorn backend.app:app --reload --host 0.0.0.0 --port 8000`

Notes:

- The backend loader auto-detects the first `*.joblib` and `*.pkl` if the defaults aren’t found.
- Confirm it is up at:
  - `http://localhost:8000/`
  - `http://localhost:8000/docs`

### Contracts + ledger (SQLite demo backend)

The backend now includes a **SQLite-backed** Future Harvest Contracts + Ledger implementation.

Endpoints:

- `GET /contracts` (list contracts)
- `POST /contracts` (create contract)
- `POST /contracts/{id}/purchase` (purchase contract)
- `POST /contracts/{id}/deliver` (mark delivered)
- `GET /ledger` (list ledger events)

Database:

- A local SQLite file is created at:
  - `backend/backend/agrichain.db`

You can override the DB location:

- `AGRICHAIN_DB_PATH` (path to the sqlite file)

### Flutter app

- The yield screen uses a default emulator base URL:
  - `http://10.0.2.2:8000`

If you run on a physical phone, you must use your PC LAN IP (example):

- `http://192.168.1.20:8000`

Where the call is made:

- `agri-chain/lib/services/yield_api_service.dart`
- `agri-chain/lib/screens/yield_prediction_screen.dart`

## 3) Huawei Cloud Migration Overview (Target Architecture)

When resources are available, the target for the MVP is:

- Compute: **Huawei Cloud ECS**
- Storage: **Huawei Cloud OBS**
- Blockchain: **Huawei Cloud BCS**
- AI training/inference: **MindSpore + ModelArts**

Recommended MVP data flow (farmer+buyer):

1. Farmer gets disease diagnosis on-device.
2. Farmer requests yield prediction online (eventually via ModelArts).
3. Backend writes a “Future Harvest Contract” to BCS.
4. Backend stores contract evidence (prediction report JSON, optional images) in OBS.
5. Buyer browses contracts and purchases a contract (BCS transaction).

## 4) Migration Steps (Do These In This Order)

### Phase A — Deploy backend on ECS (keep current model first)

Goal: move FastAPI from local machine to Huawei Cloud.

- Provision an **ECS** instance.
- Configure security group rules:
  - Allow inbound `8000/tcp` (or use `80/443` behind a proxy)
- Deploy the backend code to ECS.
- Run the API via a process manager (recommended):
  - `systemd`, `supervisor`, or container

Deliverable:

- A stable public base URL (example): `https://api.your-domain.com`

### Phase B — OBS for evidence storage (off-chain)

Goal: store large files off-chain and hash them.

For MVP, store:

- Yield prediction report JSON
- (Optional) disease scan summary JSON
- (Optional) farmer uploaded field images

Implementation approach:

- Backend endpoint creates report JSON
- Upload to OBS
- Compute `sha256(report_bytes)`
- Store the hash and OBS object key in the contract metadata (or chain events)

Deliverable:

- OBS bucket + access credentials
- Backend can upload evidence and return:
  - `obs_uri`
  - `sha256_hash`

### Phase C — Implement BCS “Future Harvest Contract” (on-chain)

Goal: replace the Flutter demo contract list with real on-chain contracts.

Minimum contract lifecycle:

- `LISTED` → `PURCHASED` → `DELIVERED`

Minimum fields:

- `contractId`
- `farmerId`
- `buyerId` (empty until purchased)
- `crop`
- `quantityKg` (or predicted yield)
- `unitPrice` and `currency`
- `evidenceHash` (sha256)
- `evidenceObjectKey` (OBS key) (store privately if needed)

Backend responsibilities:

- Provide REST endpoints for the Flutter app:
  - `POST /contracts` (create/list)
  - `GET /contracts` (browse)
  - `POST /contracts/{id}/purchase`
  - `POST /contracts/{id}/deliver`

Flutter responsibilities:

- Replace hardcoded demo data in:
  - `agri-chain/lib/screens/blockchain/contracts_screen.dart`

Deliverable:

- A demo where the UI shows contracts that were truly created and updated on-chain.

### Phase D — Move yield prediction to MindSpore + ModelArts

Goal: align with the “MindSpore-powered AI” competition topic and your proposal.

Recommended approach for MVP:

- Train a baseline MindSpore DNN for yield
- Deploy as a ModelArts inference service
- Backend `/predict` calls ModelArts endpoint

Deliverable:

- Proof that at least one AI module is trained/inferred with MindSpore and deployed on ModelArts.

## 5) What to Document for Judges (Competition Proof Checklist)

To avoid credibility gaps, collect these artifacts:

- Screenshots:
  - ModelArts training job
  - ModelArts endpoint details
  - BCS chain/network + contract deployment
  - OBS bucket objects (prediction report)

- Logs:
  - Backend request → OBS upload → sha256 → BCS tx hash

- Demo script:
  - “Farmer predicts yield → creates contract → buyer purchases → delivery confirmed → immutable ledger shows state changes.”

## 6) Security & Key Management (Do Not Hardcode Secrets)

- Store secrets in environment variables on ECS.
- Do not commit keys to git.

Suggested environment variables (names can be adjusted):

- `CORS_ORIGINS`
- `MAIZE_MODEL_PATH`
- `MAIZE_PREPROCESSING_PATH`

Huawei Cloud (future):

- `HUAWEI_OBS_ACCESS_KEY`
- `HUAWEI_OBS_SECRET_KEY`
- `HUAWEI_OBS_ENDPOINT`
- `HUAWEI_OBS_BUCKET`
- `HUAWEI_BCS_RPC_URL` (or gateway URL)
- `HUAWEI_BCS_CHAIN_ID`
- `HUAWEI_BCS_PRIVATE_KEY` (or key management integration)
- `MODElARTS_ENDPOINT_URL`
- `MODElARTS_AUTH_*`

## 7) Additional Features That Add Real Value (Recommended)

### A) QR traceability page (high proposal alignment)

- Generate a QR code for a delivered contract.
- QR opens a public traceability page (web or in-app) showing:
  - Farm/region (non-sensitive)
  - Disease scan history summaries
  - Prediction report hash
  - Contract lifecycle events

### B) SMS alerts (high inclusion value)

- Send SMS when:
  - Disease risk detected
  - Contract purchased
  - Delivery confirmed

If SMS provider is not ready, implement a “notification adapter” interface and start with a console logger.

### C) Roles and permissions (farmer vs buyer)

- Add a simple role field to user profile.
- Filter UI features and backend endpoints based on role.

### D) Offline-first improvements

- Disease diagnosis is already offline.
- Add local caching of:
  - last yield requests
  - last contracts list

### E) Evidence-based trust

- Store “evidence package” per contract:
  - prediction report
  - optional image(s)
  - hashes recorded on-chain

## 8) Suggested MVP Milestones (Practical)

- Milestone 1: ECS backend live (public base URL)
- Milestone 2: Contract endpoints + Flutter contracts screen uses backend
- Milestone 3: OBS evidence upload + hashes
- Milestone 4: BCS smart contract integrated end-to-end
- Milestone 5: Yield prediction moved to ModelArts (MindSpore)

## 9) Notes on Current Technology Choices

Current stack choices are acceptable for development because Huawei resources are not yet available. The migration steps above show how to transition without discarding the working MVP.
