from fastapi import FastAPI
import ml_service

# Mount the existing ml_service FastAPI app under /api
app = FastAPI(title="AgriYield Local API Wrapper")
app.mount("/api", ml_service.app)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("run_api:app", host="0.0.0.0", port=3000, reload=True)
