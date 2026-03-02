from __future__ import annotations

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from agrichain.core.config import ALLOWED_ORIGINS
from agrichain.db.sqlite import init_db
from agrichain.routers.blockchain import router as blockchain_router
from agrichain.routers.contracts import router as contracts_router
from agrichain.routers.predict import router as predict_router
from agrichain.routers.payments import router as payments_router
from agrichain.routers.sensor_data import router as sensor_data_router
from agrichain.routers.loans import router as loans_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


def create_app() -> FastAPI:
    app = FastAPI(
        title="AgriChain Maize Yield API",
        description="Maize yield prediction and blockchain asset management API.",
        version="1.0.0",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS if ALLOWED_ORIGINS else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(predict_router)
    app.include_router(contracts_router)
    app.include_router(blockchain_router)
    app.include_router(payments_router)
    app.include_router(sensor_data_router)
    app.include_router(loans_router)

    @app.get("/health", tags=["system"])
    async def health():
        fabric_mode = os.getenv("FABRIC_MODE", "mock").strip().lower()
        return {
            "status": "ok",
            "fabric_mode": fabric_mode,
            "version": "1.0.0",
        }

    return app


app = create_app()
