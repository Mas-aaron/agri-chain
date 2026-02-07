# Agrichain Backend (FastAPI)

## What this is
A FastAPI backend intended to be called by the `agri_chain` Flutter app for **Maize yield prediction**.

## Required model files
Place these files in `backend/` (or set env vars to point to them):

- `maize_yield_linear_regression_20250113_141237.joblib`
- `maize_yield_preprocessing_info_20250113_141237.pkl`

## Run locally
From the `backend/` folder:

```bash
pip install -r requirements.txt
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

Open:
- `http://localhost:8000/`
- `http://localhost:8000/docs`

## Environment variables
- `MAIZE_MODEL_PATH`: path to `.joblib`
- `MAIZE_PREPROCESSING_PATH`: path to `.pkl`
- `CORS_ORIGINS`: comma-separated origins (default `*`)

## Flutter base URL notes
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://localhost:8000`
- Physical device: `http://<your-pc-lan-ip>:8000`
