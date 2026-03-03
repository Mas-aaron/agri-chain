from __future__ import annotations

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from agrichain.core.config import ALLOWED_ORIGINS
from agrichain.db.sqlite import init_db
from agrichain.db.risk_db import init_risk_tables
from agrichain.routers.blockchain import router as blockchain_router
from agrichain.routers.contracts import router as contracts_router
from agrichain.routers.predict import router as predict_router
from agrichain.routers.payments import router as payments_router
from agrichain.routers.sensor_data import router as sensor_data_router
from agrichain.routers.loans import router as loans_router
# ── Risk Management routers (new) ──────────────────────────────────
from agrichain.routers.oracle import router as oracle_router
from agrichain.routers.insurance import router as insurance_router
from agrichain.routers.reputation import router as reputation_router
from agrichain.routers.ml_staking import router as ml_staking_router
from agrichain.routers.verifier import router as verifier_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    init_risk_tables()  # creates all risk management tables (idempotent)
    yield


def create_app() -> FastAPI:
    app = FastAPI(
        title="AgriChain Maize Yield API",
        description=(
            "Maize yield prediction, blockchain asset management, and "
            "5-layer risk management API."
        ),
        version="2.0.0",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS if ALLOWED_ORIGINS else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Existing routers
    app.include_router(predict_router)
    app.include_router(contracts_router)
    app.include_router(blockchain_router)
    app.include_router(payments_router)
    app.include_router(sensor_data_router)
    app.include_router(loans_router)

    # Risk management routers
    app.include_router(oracle_router)
    app.include_router(insurance_router)
    app.include_router(reputation_router)
    app.include_router(ml_staking_router)
    app.include_router(verifier_router)

    @app.get("/health", tags=["system"])
    async def health():
        fabric_mode = os.getenv("FABRIC_MODE", "mock").strip().lower()
        return {
            "status": "ok",
            "fabric_mode": fabric_mode,
            "version": "2.1.0",
            "risk_management": {
                "layers": ["oracle", "insurance", "adjustment", "ml_staking", "reputation"],
                "status": "active",
            },
            "independent_verifier": {
                "status": "active",
                "prefix": "/verifier",
            },
        }

    return app


app = create_app()

