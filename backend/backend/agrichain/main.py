from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from agrichain.core.config import ALLOWED_ORIGINS
from agrichain.db.sqlite import init_db
from agrichain.routers.contracts import router as contracts_router
from agrichain.routers.predict import router as predict_router


def create_app() -> FastAPI:
    app = FastAPI(title="Maize Yield Prediction API")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS if ALLOWED_ORIGINS else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(predict_router)
    app.include_router(contracts_router)

    @app.on_event("startup")
    def _on_startup() -> None:
        init_db()

    return app


app = create_app()
