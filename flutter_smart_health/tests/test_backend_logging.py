import logging

import pytest
from fastapi.testclient import TestClient

from src.backend.core.logging import LOGGER_NAME
from src.backend.main import create_app


def test_backend_startup_logs_readiness(caplog):
    app = create_app()

    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        with TestClient(app):
            pass

    startup_logs = [
        record.message
        for record in caplog.records
        if "Smart Health backend ready" in record.message
    ]
    assert startup_logs
    assert "host=" in startup_logs[0]
    assert "port=" in startup_logs[0]
    assert "ehospital_base_url=" in startup_logs[0]
    assert "ehospital_auth_base_url=" in startup_logs[0]
    assert "assistant_provider=" in startup_logs[0]
    assert "model_provider=" in startup_logs[0]
    assert "model_name=" in startup_logs[0]


def test_backend_logs_successful_api_request(caplog):
    app = create_app()

    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        with TestClient(app) as client:
            response = client.get("/openapi.json")

    assert response.status_code == 200
    assert any(
        "api_request method=GET path=/openapi.json status=200" in record.message
        for record in caplog.records
    )


def test_backend_logs_failed_api_request_without_swallowing_exception(caplog):
    app = create_app()

    @app.get("/logging-test/boom")
    def boom():
        raise RuntimeError("test failure")

    with caplog.at_level(logging.INFO, logger=LOGGER_NAME):
        with TestClient(app) as client:
            with pytest.raises(RuntimeError, match="test failure"):
                client.get("/logging-test/boom")

    assert any(
        "api_request method=GET path=/logging-test/boom status=ERROR" in record.message
        for record in caplog.records
    )


def test_web_version_and_no_store_cache_headers():
    app = create_app()

    with TestClient(app) as client:
        ver_resp = client.get("/web-version")
        assert ver_resp.status_code == 200
        payload = ver_resp.json()
        assert isinstance(payload.get("build_id"), str)
        assert len(payload["build_id"]) >= 8
        assert "no-store" in ver_resp.headers.get("cache-control", "")
        assert ver_resp.headers.get("pragma") == "no-cache"
        assert ver_resp.headers.get("expires") == "0"

        for asset_path in (
            "/",
            "/flutter_bootstrap.js",
            "/flutter_service_worker.js",
            "/manifest.json",
        ):
            resp = client.get(asset_path)
            assert resp.status_code == 200
            assert "no-store" in resp.headers.get("cache-control", "")
            assert resp.headers.get("pragma") == "no-cache"
            assert resp.headers.get("expires") == "0"


def test_apk_version_endpoint_returns_no_store_metadata(monkeypatch):
    from src.backend import main as backend_main

    async def fake_meta():
        return {
            "available": True,
            "version_code": 15,
            "version_name": "1.0.15",
            "apk_url": "https://example.test/app-release.apk",
            "release_notes": "CI build",
            "published_at": "2026-11-11T00:00:00Z",
        }

    monkeypatch.setattr(backend_main, "_fetch_apk_version_metadata", fake_meta)
    app = create_app()
    with TestClient(app) as client:
        resp = client.get("/apk-version")
        assert resp.status_code == 200
        assert resp.json()["version_code"] == 15
        assert "no-store" in resp.headers.get("cache-control", "")
