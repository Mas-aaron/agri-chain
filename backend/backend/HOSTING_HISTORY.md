# Hosting History: FastAPI Backend on Huawei Cloud ECS

## Overview
This document records the complete setup and deployment process for hosting the AgriChain FastAPI backend on Huawei Cloud ECS (Ubuntu), including decisions, steps taken, and current status.

---

## 1) Initial Context & Decisions
- **Backend tech**: FastAPI (Python 3.11)
- **Original storage**: SQLite (`sqlite3`) in `app.py`
- **Target platform**: Huawei Cloud ECS
- **OS chosen**: Ubuntu (latest LTS)
- **Database decision**: Deploy with SQLite first (fastest), later migrate to PostgreSQL
- **Domain**: No domain; use public IP + port 8000 (no HTTPS initially)

---

## 2) Backend Code Organization
### Before
- Single monolithic `app.py` with all logic (540+ lines)
- No package structure

### After (reorganized)
```
backend/
├── app.py               # thin entrypoint: `from agrichain.main import app`
├── agrichain/
│   ├── __init__.py
│   ├── main.py          # FastAPI app factory + router registration
│   ├── core/
│   │   ├── __init__.py
│   │   └── config.py    # env vars and paths
│   ├── services/
│   │   ├── __init__.py
│   │   └── model.py     # ML artifact loading and caching
│   ├── db/
│   │   ├── __init__.py
│   │   └── sqlite.py    # SQLite connection, init, helpers
│   └── routers/
│       ├── __init__.py
│       ├── predict.py   # /, /health, /predict, /batch-predict
│       └── contracts.py # /contracts, /ledger, purchase/deliver
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── .env
└── requirements.txt
```

- **Backward compatibility**: `uvicorn app:app` still works
- **CORS**: Configurable via `CORS_ORIGINS` env var
- **SQLite persistence**: Path set to `/app/data/agrichain.db` in container

---

## 3) Docker & Deployment Artifacts Created
- **Dockerfile**: Python 3.11-slim, install requirements, expose 8000, `uvicorn app:app --host 0.0.0.0 --port 8000`
- **docker-compose.yml**: API service only; optional Postgres commented out for later
- **.env**: `CORS_ORIGINS=*` and `AGRICHAIN_DB_PATH=/app/data/agrichain.db`
- **.dockerignore**: Excludes `.venv`, `__pycache__`, `.env`, `.git`

---

## 4) Huawei Cloud ECS Setup Steps
### 4.1) Instance Creation
- **Image**: Ubuntu (latest LTS)
- **Network**: Assigned Elastic IP (public IP) `119.8.62.170`
- **Security Group**: Added inbound TCP 22 (SSH) and TCP 8000 (API)

### 4.2) Docker & Docker Compose Installation
Commands run as `root` on Ubuntu:
```bash
apt update
apt -y install ca-certificates curl gnupp
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
apt update
apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
- Verified with `docker --version` and `docker compose version`

---

## 5) File Upload Attempts & Issues
### 5.1) First attempt: `scp` with key
```powershell
scp -i "C:\path\to\your-key.pem" -r "C:\Users\masen\OneDrive\Desktop\agri-chain\backend\backend" root@119.8.62.170:/opt/agrichain/
```
- Issue: Prompt “Are you sure you want to continue connecting (yes/no/[fingerprint])?” but input not accepted in PowerShell

### 5.2) Second attempt: `scp -o StrictHostKeyChecking=no`
```powershell
scp -o StrictHostKeyChecking=no -i "C:\path\to\your-key.pem" -r "C:\Users\masen\OneDrive\Desktop\agri-chain\backend\backend" root@119.8.62.170:/opt/agrichain/
```
- Issue: Identity file path placeholder (`C:/path/to/your-key.pem`) not found
- Fallback: Password login accepted
- Error: `realpath /opt/agrichain/: No such file` (target directory must exist first)

---

## 6) Next Steps (Pending)
### 6.1) Create target directory on ECS
```bash
mkdir -p /opt/agrichain
```
### 6.2) Upload backend folder (retry `scp` or use WinSCP)
### 6.3) Start the API
```bash
cd /opt/agrichain/backend
docker compose up -d --build
docker compose ps
docker compose logs -f
```
### 6.4) Verify endpoints
- `http://119.8.62.170:8000/health`
- `http://119.8.62.170:8000/docs`

---

## 7) Future Improvements
- **Database migration**: SQLite → PostgreSQL (SQLAlchemy + Alembic)
- **Reverse proxy**: Nginx on port 80 (cleaner than direct 8000)
- **HTTPS**: Let’s Encrypt (requires domain)
- **CI/CD**: GitHub Actions or similar to auto-deploy on push

---

## 8) Key Commands Summary
```bash
# On ECS (as root)
mkdir -p /opt/agrichain
cd /opt/agrichain/backend
docker compose up -d --build
docker compose ps
docker compose logs -f

# From Windows (upload)
scp -o StrictHostKeyChecking=no -r "C:\Users\masen\OneDrive\Desktop\agri-chain\backend\backend" root@119.8.62.170:/opt/agrichain/
```

---

## 9) Status (as of now)
- [x] Backend code organized
- [x] Docker + compose files created
- [x] ECS instance created + Docker installed
- [x] Security group inbound rule for port 8000 added
- [ ] Backend folder uploaded to ECS (pending)
- [ ] API container started (pending)
- [ ] Endpoints tested (pending)

---

*Last updated: 2026-02-12*
