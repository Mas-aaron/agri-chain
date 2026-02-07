from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


def _load_backend_app():
    repo_root = Path(__file__).resolve().parents[1]
    backend_app_path = repo_root / "backend" / "app.py"

    spec = importlib.util.spec_from_file_location("backend_app", str(backend_app_path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load backend app module from {backend_app_path}")

    module = importlib.util.module_from_spec(spec)
    sys.modules["backend_app"] = module
    spec.loader.exec_module(module)

    backend_app = getattr(module, "app", None)
    if backend_app is None:
        raise RuntimeError("backend/app.py does not define `app`")

    return backend_app


app = _load_backend_app()
