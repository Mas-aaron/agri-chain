# AgriChain — Service Startup Guide

## Quick Start (After ECS Reboot)

### Step 1: SSH into the server
```bash
ssh root@101.44.10.153
```
Enter your password when prompted.

### Step 2: Start the backend API
```bash
cd /root/backend-backend
docker compose up -d
```
> **Note:** Use `docker compose up -d --build` ONLY if you changed `requirements.txt` or `Dockerfile`.
> For code-only changes, just use `docker compose up -d` or `docker compose restart api`.

### Step 3: Verify backend is running
```bash
docker compose logs -f

cd /root/backend-backend && docker compose logs --tail 50 -f agrichain-api

```
Press `Ctrl+C` to stop viewing logs. Visit `http://101.44.10.153:8000/docs` in your browser.

### Step 4: Start the web frontend (Nginx)
Nginx starts automatically on boot. If it's down:
```bash
systemctl start nginx
```
Visit `http://101.44.10.153` in your browser.

---

## Deploying Code Changes

### Backend code changes (Python files only)
```powershell
# From local PowerShell (C:\Users\masen\OneDrive\Desktop\agri-chain)
scp .\backend\backend\agrichain\routers\payments.py root@101.44.10.153:/root/backend-backend/agrichain/routers/
```
Then in SSH:
```bash
cd /root/backend-backend && docker compose restart agrichain-api
```

### Backend dependency changes (requirements.txt or Dockerfile)
```powershell
# Upload changed files
scp .\backend\backend\requirements.txt root@101.44.10.153:/root/backend-backend/
scp .\backend\backend\Dockerfile root@101.44.10.153:/root/backend-backend/
```
Then in SSH:
```bash
cd /root/backend-backend && docker compose up -d --build
```

### Flutter app
```powershell
# From local PowerShell
cd C:\Users\masen\OneDrive\Desktop\agri-chain\agri-chain
flutter run
```

---

## Useful Commands (SSH)

| Command | What it does |
|---|---|
| `docker compose up -d` | Start containers (no rebuild) |
| `docker compose up -d --build` | Rebuild + start (after dependency changes) |
| `docker compose restart api` | Restart after code-only changes |
| `docker compose logs -f` | View live logs |
| `docker compose down` | Stop all containers |
| `docker compose ps` | Check container status |
| `systemctl status nginx` | Check web frontend status |

---

## Server Info
- **ECS IP:** `101.44.10.153`
- **Backend API:** `http://101.44.10.153:8000`
- **API Docs:** `http://101.44.10.153:8000/docs`
- **Web Frontend:** `http://101.44.10.153`
- **PesaPal:** Sandbox mode (switch to production in `.env`)
