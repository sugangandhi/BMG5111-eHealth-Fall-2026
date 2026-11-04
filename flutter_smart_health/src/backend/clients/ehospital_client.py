from __future__ import annotations

import time
from typing import Any

import httpx
from fastapi import HTTPException

from src.backend.core.config import settings

_TABLE_CACHE: dict[str, tuple[float, list[dict[str, Any]]]] = {}
_CACHE_TTL_SECONDS = 30.0


def invalidate_table_cache(table: str | None = None) -> None:
    if table:
        _TABLE_CACHE.pop(table, None)
    else:
        _TABLE_CACHE.clear()


async def fetch_ehospital_table(
    table: str,
    patient_id: int | str | None = None,
) -> list[dict[str, Any]]:
    # In-memory cache for fast UI loading of large remote AWS tables
    now = time.time()
    clean_rows: list[dict[str, Any]] | None = None
    if table in _TABLE_CACHE:
        cached_time, cached_data = _TABLE_CACHE[table]
        if (now - cached_time) < _CACHE_TTL_SECONDS:
            clean_rows = cached_data

    if clean_rows is None:
        params = {"patient_id": str(patient_id)} if patient_id is not None else None
        url = f"{settings.ehospital_base_url}/table/{table}"
        try:
            async with httpx.AsyncClient(timeout=20, verify=False) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            raise HTTPException(
                status_code=502,
                detail=(
                    f"Failed to fetch eHospital table '{table}': "
                    f"{exc.response.status_code} {exc.response.text}"
                ),
            ) from exc
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=502,
                detail=f"Failed to fetch eHospital table '{table}': {exc}",
            ) from exc

        payload = response.json()
        rows = payload.get("data", payload) if isinstance(payload, dict) else payload
        if not isinstance(rows, list):
            return []

        clean_rows = [row for row in rows if isinstance(row, dict)]
        _TABLE_CACHE[table] = (now, clean_rows)

    if patient_id is None:
        return clean_rows

    patient_id_str = str(patient_id)
    return [
        row
        for row in clean_rows
        if row.get("patient_id") is not None
        and str(row.get("patient_id")) == patient_id_str
    ]


async def fetch_ehospital_tables_metadata() -> dict[str, Any]:
    url = f"{settings.ehospital_base_url}/tables"
    try:
        async with httpx.AsyncClient(timeout=20, verify=False) as client:
            response = await client.get(url)
            response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                "Failed to fetch eHospital table metadata: "
                f"{exc.response.status_code} {exc.response.text}"
            ),
        ) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to fetch eHospital table metadata: {exc}",
        ) from exc

    payload = response.json()
    if not isinstance(payload, dict):
        return {"count": 0, "tables": []}
    return payload


async def write_ehospital_table_row(table: str, row: dict[str, Any]) -> dict[str, Any]:
    invalidate_table_cache(table)
    url = f"{settings.ehospital_base_url}/table/{table}"
    try:
        async with httpx.AsyncClient(timeout=20, verify=False) as client:
            response = await client.post(url, json=row)
            response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                f"Failed to write eHospital table '{table}': "
                f"{exc.response.status_code} {exc.response.text}"
            ),
        ) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to write eHospital table '{table}': {exc}",
        ) from exc

    if not response.content:
        return {}

    payload = response.json()
    if not isinstance(payload, dict):
        return {"data": payload}
    return payload


async def update_ehospital_table_row(
    table: str,
    row_id: int | str,
    row: dict[str, Any],
) -> dict[str, Any]:
    invalidate_table_cache(table)
    url = f"{settings.ehospital_base_url}/table/{table}/{row_id}"
    try:
        async with httpx.AsyncClient(timeout=20, verify=False) as client:
            response = await client.put(url, json=row)
            response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                f"Failed to update eHospital table '{table}' row '{row_id}': "
                f"{exc.response.status_code} {exc.response.text}"
            ),
        ) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to update eHospital table '{table}' row '{row_id}': {exc}",
        ) from exc

    if not response.content:
        return {}

    payload = response.json()
    if not isinstance(payload, dict):
        return {"data": payload}
    return payload


# Compatibility aliases for teammate feature code and older tests.
write_ehospital_row = write_ehospital_table_row
update_ehospital_row = update_ehospital_table_row


async def execute_ehospital_select(
    sql: str,
    replacements: dict[str, Any] | None = None,
) -> dict[str, Any]:
    url = f"{settings.ehospital_base_url}/sql/select"
    body = {"sql": sql, "replacements": replacements or {}}
    try:
        async with httpx.AsyncClient(timeout=30, verify=False) as client:
            response = await client.post(url, json=body)
            response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                "Failed to execute eHospital SELECT query: "
                f"{exc.response.status_code} {exc.response.text}"
            ),
        ) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to execute eHospital SELECT query: {exc}",
        ) from exc

    payload = response.json()
    if not isinstance(payload, dict):
        return {"count": 0, "data": []}
    return payload
