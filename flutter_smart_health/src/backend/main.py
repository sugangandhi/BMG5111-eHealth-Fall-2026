from __future__ import annotations

from contextlib import asynccontextmanager
import hashlib
import os
from pathlib import Path
from time import monotonic, perf_counter
from dotenv import load_dotenv
import httpx

_env_file = Path(__file__).resolve().parents[2] / ".env"
load_dotenv(_env_file)
load_dotenv(Path(__file__).resolve().parents[3] / ".env")
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from starlette.requests import Request

from src.backend.api.assistant import router as assistant_router
from src.backend.api.auth import router as auth_router
from src.backend.api.query_tools import router as query_tools_router
from src.backend.api.report_interpreter import router as report_interpreter_router
from src.backend.api.nutrition_monitor import router as nutrition_monitor_router
from src.backend.api.sleep import router as sleep_router
from src.backend.api.stress import router as stress_router
from src.backend.api.urgent_care import router as urgent_care_router
from src.backend.api.wearables import router as wearables_router
from src.backend.api.whatsapp import router as whatsapp_router
from src.backend.core.config import settings
from src.backend.core.logging import get_backend_logger


logger = get_backend_logger()

_WEB_NO_CACHE_PATHS = {
    "/",
    "/index.html",
    "/flutter_bootstrap.js",
    "/flutter_service_worker.js",
    "/main.dart.js",
    "/manifest.json",
    "/version.json",
    "/web-version",
    "/apk-version",
}

_DEFAULT_APK_VERSION_URL = (
    "https://github.com/sugangandhi/BMG5111-eHealth-Fall-2026/"
    "releases/download/android-latest/apk-version.json"
)
_APK_VERSION_CACHE_TTL_SECONDS = 45.0
_apk_version_cache: dict[str, object] = {"fetched_at": 0.0, "payload": None}


async def _fetch_apk_version_metadata() -> dict:
    """Fetch latest published Android APK release metadata with short in-memory caching."""
    now = monotonic()
    cached_payload = _apk_version_cache.get("payload")
    fetched_at = float(_apk_version_cache.get("fetched_at") or 0.0)
    if isinstance(cached_payload, dict) and (now - fetched_at) < _APK_VERSION_CACHE_TTL_SECONDS:
        return cached_payload

    url = os.getenv("APK_VERSION_URL", _DEFAULT_APK_VERSION_URL).strip() or _DEFAULT_APK_VERSION_URL
    try:
        async with httpx.AsyncClient(follow_redirects=True, timeout=6.0) as client:
            resp = await client.get(url)
        if resp.status_code == 200:
            data = resp.json()
            if isinstance(data, dict) and data.get("apk_url"):
                payload = {
                    "available": True,
                    "version_code": int(data.get("version_code") or 0),
                    "version_name": str(data.get("version_name") or "1.0.0"),
                    "apk_url": str(data["apk_url"]),
                    "release_notes": str(data.get("release_notes") or ""),
                    "published_at": str(data.get("published_at") or ""),
                }
                _apk_version_cache["fetched_at"] = now
                _apk_version_cache["payload"] = payload
                return payload
    except Exception as exc:
        logger.warning("Failed fetching APK version metadata from %s: %s", url, exc)

    return {
        "available": False,
        "version_code": 0,
        "version_name": "0.0.0",
        "apk_url": None,
        "release_notes": "",
        "published_at": "",
    }


def _resolve_web_dir() -> Path | None:
    """Return the built Flutter Web directory if present."""
    dist_dir = Path(__file__).resolve().parents[2] / "web_dist"
    if dist_dir.exists():
        return dist_dir
    app_build_dir = Path(__file__).resolve().parents[1] / "app" / "build" / "web"
    if app_build_dir.exists():
        return app_build_dir
    return None


def _resolve_web_build_id(web_dir: Path | None) -> str:
    """Compute a deterministic hash representing the active Flutter Web bundle."""
    if web_dir is None:
        return "no-web-dist"
    hasher = hashlib.sha256()
    hashed_any = False
    for filename in ("main.dart.js", "flutter_bootstrap.js", "index.html", "manifest.json"):
        target = web_dir / filename
        if target.is_file():
            hasher.update(filename.encode("utf-8"))
            hasher.update(target.read_bytes())
            hashed_any = True
    return hasher.hexdigest()[:16] if hashed_any else "empty-web-dist"


def log_startup_ready() -> None:
    logger.info(
        "Smart Health backend ready host=%s port=%s ehospital_base_url=%s "
        "ehospital_auth_base_url=%s assistant_provider=%s model_provider=%s "
        "model_name=%s cors_origins=%s",
        settings.host,
        settings.port,
        settings.ehospital_base_url,
        settings.ehospital_auth_base_url,
        settings.assistant_provider,
        settings.ai_model_provider,
        settings.ai_model_name,
        ",".join(settings.cors_allow_origins),
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    log_startup_ready()
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="Smart Health Backend API", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_allow_origins) if settings.cors_allow_origins else ["*"],
        allow_origin_regex=r"https?://.*",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.middleware("http")
    async def log_api_request(request: Request, call_next):
        start = perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            elapsed_ms = (perf_counter() - start) * 1000
            logger.exception(
                "api_request method=%s path=%s status=ERROR duration_ms=%.2f",
                request.method,
                request.url.path,
                elapsed_ms,
            )
            raise

        elapsed_ms = (perf_counter() - start) * 1000
        logger.info(
            "api_request method=%s path=%s status=%s duration_ms=%.2f",
            request.method,
            request.url.path,
            response.status_code,
            elapsed_ms,
        )
        response.headers["Access-Control-Allow-Private-Network"] = "true"
        if request.url.path in _WEB_NO_CACHE_PATHS or request.url.path.endswith((".js", ".html", ".json")):
            response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
            response.headers["Pragma"] = "no-cache"
            response.headers["Expires"] = "0"
        return response

    web_dir = _resolve_web_dir()
    web_build_id = _resolve_web_build_id(web_dir)

    @app.get("/web-version")
    async def get_web_version():
        """Expose a deterministic build ID so installed mobile PWAs detect new deploys."""
        return {"build_id": web_build_id}

    @app.get("/apk-version")
    async def get_apk_version():
        """Expose latest published Android APK release metadata for 1-tap in-app updates."""
        return await _fetch_apk_version_metadata()

    @app.get("/privacy", response_class=HTMLResponse)
    @app.get("/privacy.html", response_class=HTMLResponse)
    async def privacy_policy():
        """Public Privacy Policy required for Meta Developer App Review and Publishing."""
        html_content = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - e-Hospital SmartHealth</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #2D3748; max-width: 800px; margin: 40px auto; padding: 0 20px; }
        h1 { color: #1A365D; border-bottom: 2px solid #E2E8F0; padding-bottom: 12px; }
        h2 { color: #2B6CB0; margin-top: 24px; }
        p, li { font-size: 15px; }
        .card { background: #F7FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 20px; margin-top: 20px; }
    </style>
</head>
<body>
    <h1>e-Hospital SmartHealth Privacy Policy</h1>
    <p><strong>Effective Date:</strong> November 18, 2026</p>
    <p>This Privacy Policy describes how e-Hospital SmartHealth and its Clinical Care AI Assistant ("we", "our", or "us") collect, use, and protect your personal information and health telemetry.</p>
    
    <h2>1. Information We Collect</h2>
    <ul>
        <li><strong>Health & Telemetry Data:</strong> Vital signs (blood pressure, heart rate, blood glucose), symptoms, and medication updates communicated through our WhatsApp Clinical channel or app.</li>
        <li><strong>Contact Information:</strong> Your mobile phone number used for WhatsApp care communication and appointment notifications.</li>
    </ul>

    <h2>2. How We Use Information</h2>
    <ul>
        <li>To provide clinical triage assistance and record vitals directly into your patient health chart.</li>
        <li>To facilitate appointment scheduling and medication reminders with your care team (Dr. Patel).</li>
        <li>We do <strong>not</strong> sell, rent, or share personal health information with third-party advertisers.</li>
    </ul>

    <h2>3. Data Protection & Security</h2>
    <p>All clinical data transmissions are encrypted using industry-standard TLS/HTTPS protocols in compliance with healthcare data protection standards (PIPEDA / HIPAA).</p>

    <h2>4. Data Deletion & Inquiries</h2>
    <p>Patients may request deletion of their communication history or patient chart by contacting our clinical support desk at <a href="mailto:support@ehospital.org">support@ehospital.org</a>.</p>

    <div class="card">
        <p><strong>Contact Us:</strong> e-Hospital PrimeCare Clinical Network &bull; BMG5111 eHealth &bull; Ottawa, ON, Canada</p>
    </div>
</body>
</html>"""
        return HTMLResponse(content=html_content, status_code=200)

    @app.get("/terms", response_class=HTMLResponse)
    async def terms_of_service():
        """Public Terms of Service."""
        html_content = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Terms of Service - e-Hospital SmartHealth</title>
    <style>body { font-family: sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #2D3748; }</style>
</head>
<body>
    <h1>Terms of Service</h1>
    <p><strong>Effective Date:</strong> November 18, 2026</p>
    <p>e-Hospital SmartHealth provides AI-assisted clinical triage and telemetry logging. This service does not replace emergency medical care. In case of life-threatening emergencies, call 911 immediately.</p>
</body>
</html>"""
        return HTMLResponse(content=html_content, status_code=200)

    app.include_router(auth_router)
    app.include_router(assistant_router)
    app.include_router(query_tools_router)
    app.include_router(report_interpreter_router)
    app.include_router(nutrition_monitor_router)
    app.include_router(stress_router)
    app.include_router(sleep_router)
    app.include_router(urgent_care_router)
    app.include_router(wearables_router)
    app.include_router(whatsapp_router)

    from src.backend.clients.ehospital_client import (
        fetch_ehospital_table,
        write_ehospital_table_row,
    )

    @app.get("/table/{table_name}")
    async def proxy_get_table(table_name: str, patient_id: str | None = None):
        try:
            rows = await fetch_ehospital_table(table_name, patient_id=patient_id)
            return {"table": table_name, "count": len(rows), "data": rows}
        except Exception as e:
            logger.error("Error proxying table %s: %s", table_name, e)
            return {"table": table_name, "count": 0, "data": []}

    @app.post("/table/{table_name}")
    async def proxy_post_table(table_name: str, request: Request):
        try:
            body = await request.json()
            result = await write_ehospital_table_row(table_name, body)
            return result
        except Exception as e:
            logger.error("Error writing to table %s: %s", table_name, e)
            return {"status": "error", "detail": str(e)}

    # Mount Flutter Web frontend if built (enables unified cloud deployment on Render/Docker)
    if web_dir is not None and web_dir.exists():
        from fastapi.staticfiles import StaticFiles
        app.mount("/", StaticFiles(directory=str(web_dir), html=True), name="web_app")
        logger.info("Mounted Flutter Web app from %s", web_dir)

    return app


app = create_app()
