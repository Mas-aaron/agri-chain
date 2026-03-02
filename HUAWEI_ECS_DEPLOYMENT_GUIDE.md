# Huawei Cloud ECS Deployment Guide – FastAPI Backend

> **Purpose:** Deploy the FastAPI backend (agrichain) on Huawei Cloud ECS using Docker.  
> **Scope:** Backend-only deployment (no Flutter frontend).  
> **Audience:** DevOps or developer deploying AgriChain MVP.

---

## 1) Prerequisites

### 1.1) Huawei Cloud ECS
- **OS:** Ubuntu 22.04 LTS (recommended) or Debian 12
- **Instance type:** 2 vCPU / 4 GB RAM minimum (FastAPI + sklearn/pandas)
- **Disk:** 40 GB+
- **Public IP:** Note the IP (example: `119.8.117.2`)
- **Security Group:** Inbound rules (see Section 2)

### 1.2) Local machine (for upload)
- Windows PowerShell (or any terminal with `scp`/`ssh` access)
- Backend zip prepared: `backend/backend.zip` (~106 MB)

---

## 2) Network / Security Group

In Huawei Cloud Console → **ECS → Security Group**:

| Rule | Protocol | Port Range | Source | Description |
|------|----------|-------------|-------------|
| SSH  | TCP       | 22          | Your IP (or 0.0.0.0/0) |
| API  | TCP       | 8000        | 0.0.0.0/0 (testing only) |
| HTTP | TCP       | 80          | 0.0.0.0/0 (optional, with Nginx) |
| HTTPS| TCP       | 443         | 0.0.0.0/0 (optional, with Nginx + TLS) |

> **Tip:** Keep 8000 open only for initial testing. Once Nginx is in front, close 8000 publicly.

---

## 3) Upload Backend Code to ECS

### 3.1) From local Windows (PowerShell)

```powershell
# From your repo root:
scp .\backend.zip root@<SERVER_PUBLIC_IP>:/root/
```

### 3.2) On ECS (extract + prepare)

```bash
# Verify upload
ls -lh /root/backend.zip

# Create working folder
mkdir -p /root/agrichain_api
cd /root/agrichain_api

# Extract
unzip -o /root/backend.zip -d /root/agrichain_api
cd /root/agrichain_api

# Verify contents (must contain Dockerfile, docker-compose.yml, requirements.txt, agrichain/)
ls
```

You should see:
- `Dockerfile`
- `docker-compose.yml`
- `requirements.txt`
- `agrichain/`

---

## 4) Create Environment File

Create `.env` inside the folder that contains `docker-compose.yml`:

```bash
nano .env
```

Add these minimal lines (adjust if needed):

```bash
CORS_ORIGINS=*
AGRICHAIN_DB_PATH=/app/data/agrichain.db
```

Save (`Ctrl+O`, `Enter`, `Ctrl+X`).

---

## 5) Start the FastAPI Service

```bash
# Ensure data volume exists
mkdir -p data

# Build and run in background
docker compose up -d --build

# Verify containers
docker compose ps

# View logs (first time)
docker compose logs -f api
```

Expected output:
- Container `api` should be `Up`
- Logs should show Uvicorn binding to `0.0.0.0:8000`

---

## 6) Verify the API is Reachable

From your laptop:

```bash
curl -I http://<SERVER_PUBLIC_IP>:8000/docs
```

You should receive HTTP `200 OK` and be able to open Swagger UI at that URL.

---

## 7) Post-Deployment Management Commands

### 7.1) View live logs
```bash
docker compose logs -f api
```

### 7.2) Stop the service
```bash
docker compose stop api
```

### 7.3) Restart the service
```bash
docker compose up -d
```

### 7.4) Update the code (recommended workflow)

From your local machine:

```powershell
# Update zip and re-upload
scp .\backend.zip root@<SERVER_PUBLIC_IP>:/root/
```

On ECS:

```bash
cd /root/agrichain_api
unzip -o /root/backend.zip -d /root/agrichain_api
docker compose up -d --build
docker logs -f agrichain_api-api-1

```

### 7.5) Backup the SQLite database (optional but recommended)

```bash
# Copy out the DB file
cp data/agrichain.db data/agrichain.db.backup.$(date +%Y%m%d)
```

### 7.6) Clean up unused Docker images (optional)

```bash
docker image prune -f
```

---

## 8) Optional: Add Reverse Proxy (Nginx) + TLS (HTTPS)

If you want a production setup with a domain and HTTPS:

### 8.1) Install Nginx on ECS
```bash
apt-get update && apt-get install -y nginx
systemctl enable --now nginx
```

### 8.2) Create Nginx site config
Create `/etc/nginx/sites-available/agrichain`:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable it:

```bash
ln -s /etc/nginx/sites-available/agrichain /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

### 8.3) Obtain TLS with Let’s Encrypt (Certbot)

```bash
apt-get install -y certbot python3-certbot-nginx
certbot --nginx -d your-domain.com
```

Nginx config will be auto-updated to use TLS.

### 8.4) Update security group
- Close inbound `8000` from public
- Keep `80` and `443` open
- Test HTTPS: `https://your-domain.com/docs`

---

## 9) Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `docker compose up` fails | Missing `Dockerfile`/`docker-compose.yml` or syntax error | Run `docker compose config` and verify paths |
| API 404/500 | Wrong WORKDIR or missing files | Ensure `agrichain/` folder is present and contains `main.py` |
| `docker compose logs` shows import errors | Missing Python deps | Run `docker compose exec api pip list` and compare to `requirements.txt` |
| Can’t reach `:8000` from internet | Security group blocks port | Open TCP 8000 in Huawei Console |

---

## 10) Health Checks (Optional)

Add cron or simple script:

```bash
#!/bin/bash
# health_check.sh
curl -f http://127.0.0.1:8000/health || systemctl restart docker-compose@api
```

Make executable and add to crontab for every 5 minutes if desired.

---

## 11) Scaling (Future)

- Use **ECS Auto Scaling** or **Elastic Cloud Server (ECS) with load balancer**
- Move SQLite to **Huawei Cloud RDS** or **OBS-backed DB** if you need HA
- Add **Huawei Cloud Monitor** alerts for container restarts or high error rates

---

# Summary Checklist

- [ ] ECS instance created with Ubuntu 22.04
- [ ] Security group allows 22, 8000 (and later 80/443)
- [ ] Docker and Docker Compose installed
- [ ] Backend zip uploaded and extracted
- [ ] `.env` created with `CORS_ORIGINS` and `AGRICHAIN_DB_PATH`
- [ ] `docker compose up -d --build` succeeded
- [ ] API responds at `http://<IP>:8000/docs`
- [ ] (Optional) Nginx reverse proxy + TLS configured
- [ ] (Optional) Monitoring/backup automation added

---

**Result:** Your FastAPI backend will be live on Huawei Cloud ECS, ready for the Flutter app and admin tools.
