# Flutter: authenticated `/v1` migration

This repo supports **both** public routes (legacy) and authenticated `/v1` routes (new).

Flutter has been updated so that:

- If a Firebase user is signed in, requests include:

```http
Authorization: Bearer <Firebase ID token>
```

…and the app prefers `/v1/*` endpoints.

- If no user is signed in, the app falls back to public endpoints.

## What changed

- `lib/services/contracts_api_service.dart`
  - Uses `/v1/contracts` and `/v1/ledger` when signed in
  - Uses `/contracts` and `/ledger` when signed out

- `lib/services/yield_api_service.dart`
  - Uses `/v1/predict` when signed in
  - Uses `/predict` when signed out

## Backend requirements

### Base URL

Typical dev base URLs:

- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://localhost:8000`
- Physical device: `http://<your-pc-lan-ip>:8000`

### Firebase

- Flutter uses Firebase client config (`google-services.json`, etc.) for login.
- Go gateway uses a Firebase **service account json** via `GOOGLE_APPLICATION_CREDENTIALS`.

### RBAC (server side)

Authenticated `/v1/contracts` actions require SQLite roles:

- `POST /v1/contracts` and `POST /v1/contracts/{id}/deliver`
  - roles: `farmer` or `admin`
- `POST /v1/contracts/{id}/purchase`
  - roles: `bank`, `investor`, or `admin`

Read-only endpoints:

- `GET /v1/contracts`
- `GET /v1/ledger`

## Manual test flow

### 1) Start services

- Go gateway: `http://localhost:8000`
- Python ML: `http://localhost:8001`

Ensure Go has:

- `ML_BASE_URL=http://127.0.0.1:8001`
- `GOOGLE_APPLICATION_CREDENTIALS=<path-to-service-account.json>`

### 2) Sign in from Flutter

Use an account configured in Firebase Authentication.

Confirm in logs (or by behavior) that requests are now hitting `/v1/*`.

### 3) Assign roles (admin)

To test RBAC, sign in with a user that has role `admin` already (in SQLite), then call:

- `PUT /v1/admin/users/<TARGET_UID>/roles`

Body:

```json
{ "roles": ["farmer"] }
```

or

```json
{ "roles": ["bank"] }
```

### 4) Confirm RBAC works

- With `farmer` role:
  - create a contract in app (should succeed)
  - deliver a contract (should succeed)
  - purchase should fail with `403`

- With `bank` or `investor` role:
  - purchase should succeed
  - create/deliver should fail with `403`

If you see `401`, check:

- Flutter is signed in
- Go has `GOOGLE_APPLICATION_CREDENTIALS` configured

