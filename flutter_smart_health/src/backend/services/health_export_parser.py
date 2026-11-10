from __future__ import annotations

import base64
import binascii
import csv
from dataclasses import dataclass, field
from datetime import datetime, timezone
import io
import json
from pathlib import Path
from typing import Any
import xml.etree.ElementTree as ET
import zipfile

from fastapi import HTTPException

from src.backend.schemas.wearables import (
    WearableExportImportRequest,
    WearableExportImportResponse,
    WearableIngestionRequest,
    WearableSource,
)
from src.backend.services.wearable_ingestion import ingest_wearable_sample


MAX_EXPORT_BYTES = 20 * 1024 * 1024
MAX_ZIP_ENTRIES = 80
MAX_ZIP_UNCOMPRESSED_BYTES = 35 * 1024 * 1024

_SUPPORTED_INNER_EXTS = {".csv", ".xml", ".json"}


@dataclass
class _DailyAggregate:
    day: str
    latest_timestamp: datetime
    hr_values: list[float] = field(default_factory=list)
    steps_total: float = 0.0
    has_steps: bool = False
    calories_total: float = 0.0
    has_calories: bool = False
    sleep_hours_total: float = 0.0
    has_sleep: bool = False

    def add(
        self,
        ts: datetime,
        *,
        heart_rate: float | None = None,
        steps: float | None = None,
        calories: float | None = None,
        sleep_hours: float | None = None,
    ) -> None:
        if ts > self.latest_timestamp:
            self.latest_timestamp = ts
        if heart_rate is not None and 20 <= heart_rate <= 250:
            self.hr_values.append(heart_rate)
        if steps is not None and steps >= 0:
            self.steps_total = max(self.steps_total, steps) if self.has_steps else steps
            self.has_steps = True
        if calories is not None and calories >= 0:
            self.calories_total = (
                max(self.calories_total, calories) if self.has_calories else calories
            )
            self.has_calories = True
        if sleep_hours is not None and 0 < sleep_hours <= 24:
            self.sleep_hours_total += sleep_hours
            self.has_sleep = True

    def to_request(
        self,
        *,
        patient_id: int | str,
        source: WearableSource,
        filename: str,
    ) -> WearableIngestionRequest | None:
        avg_hr = (
            round(sum(self.hr_values) / len(self.hr_values), 1)
            if self.hr_values
            else None
        )
        steps = round(self.steps_total) if self.has_steps else None
        calories = round(self.calories_total, 1) if self.has_calories else None
        sleep = (
            round(min(self.sleep_hours_total, 24.0), 2) if self.has_sleep else None
        )
        if avg_hr is None and steps is None and calories is None and sleep is None:
            return None
        return WearableIngestionRequest(
            patient_id=patient_id,
            heart_rate=avg_hr,
            steps=steps,
            calories=calories,
            sleep=sleep,
            timestamp=self.latest_timestamp,
            recorded_on=self.latest_timestamp,
            source=source,
            source_metadata={
                "import_filename": filename,
                "day": self.day,
                "ingestion_channel": "export_file",
            },
        )


def parse_export_payload(
    *,
    filename: str,
    raw_bytes: bytes,
    provider_hint: WearableSource | None = None,
) -> tuple[WearableSource, dict[str, _DailyAggregate], int]:
    """Parse CSV, XML, JSON, or ZIP health export bytes into daily aggregates."""
    if len(raw_bytes) > MAX_EXPORT_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Export file exceeds maximum allowed size (20 MB).",
        )

    ext = Path(filename).suffix.lower()
    buckets: dict[str, _DailyAggregate] = {}
    detected_sources: list[WearableSource] = []
    parsed_rows = 0

    if ext == ".zip":
        parsed_rows += _parse_zip_bytes(
            raw_bytes=raw_bytes,
            buckets=buckets,
            detected_sources=detected_sources,
        )
    elif ext == ".xml":
        src, count = _parse_xml_bytes(raw_bytes, buckets)
        if src:
            detected_sources.append(src)
        parsed_rows += count
    elif ext == ".json":
        src, count = _parse_json_bytes(raw_bytes, filename, buckets)
        if src:
            detected_sources.append(src)
        parsed_rows += count
    elif ext == ".csv":
        src, count = _parse_csv_bytes(raw_bytes, filename, buckets)
        if src:
            detected_sources.append(src)
        parsed_rows += count
    else:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported export file type '{ext}'. Upload CSV, XML, JSON, or ZIP.",
        )

    resolved_provider: WearableSource = (
        provider_hint
        or (detected_sources[0] if detected_sources else None)
        or ("xml_import" if ext == ".xml" else "csv_import")
    )
    return resolved_provider, buckets, parsed_rows


async def import_health_export(
    request: WearableExportImportRequest,
) -> WearableExportImportResponse:
    """Decode, parse, normalize, and ingest health export files into eHospital."""
    try:
        raw_bytes = base64.b64decode(request.content_base64, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise HTTPException(
            status_code=400,
            detail="Invalid base64 payload in content_base64.",
        ) from exc

    if not raw_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    provider, buckets, parsed_rows = parse_export_payload(
        filename=request.filename,
        raw_bytes=raw_bytes,
        provider_hint=request.provider,
    )
    if not buckets:
        raise HTTPException(
            status_code=422,
            detail=(
                "No recognizable heart rate, steps, calories, or sleep records were "
                f"found inside '{request.filename}'."
            ),
        )

    recent_days = sorted(buckets.keys(), reverse=True)[: request.max_days]
    ingested_count = 0
    accepted_metrics_set: set[str] = set()
    previews: list[dict[str, Any]] = []

    for day in sorted(recent_days):
        sample_req = buckets[day].to_request(
            patient_id=request.patient_id,
            source=provider,
            filename=request.filename,
        )
        if sample_req is None:
            continue
        result = await ingest_wearable_sample(sample_req)
        ingested_count += 1
        accepted_metrics_set.update(result.accepted_metrics)
        if len(previews) < 5:
            previews.append(
                {
                    "day": day,
                    "heart_rate": sample_req.heart_rate,
                    "steps": sample_req.steps,
                    "calories": sample_req.calories,
                    "sleep": sample_req.sleep,
                }
            )

    if ingested_count == 0:
        raise HTTPException(
            status_code=422,
            detail="Parsed rows contained no non-negative vitals metrics to ingest.",
        )

    return WearableExportImportResponse(
        patient_id=str(request.patient_id),
        detected_provider=provider,
        filename=request.filename,
        records_parsed=parsed_rows,
        records_ingested=ingested_count,
        accepted_metrics=sorted(accepted_metrics_set),
        samples_preview=previews,
    )


def _parse_zip_bytes(
    *,
    raw_bytes: bytes,
    buckets: dict[str, _DailyAggregate],
    detected_sources: list[WearableSource],
) -> int:
    parsed = 0
    try:
        zf = zipfile.ZipFile(io.BytesIO(raw_bytes))
    except zipfile.BadZipFile as exc:
        raise HTTPException(status_code=400, detail="Invalid ZIP archive.") from exc

    total_uncompressed = 0
    with zf:
        infos = [info for info in zf.infolist() if not info.is_dir()][:MAX_ZIP_ENTRIES]
        for info in infos:
            entry_ext = Path(info.filename).suffix.lower()
            if entry_ext not in _SUPPORTED_INNER_EXTS:
                continue
            total_uncompressed += info.file_size
            if total_uncompressed > MAX_ZIP_UNCOMPRESSED_BYTES:
                raise HTTPException(
                    status_code=413,
                    detail="ZIP archive uncompressed content exceeds limit (35 MB).",
                )
            inner_bytes = zf.read(info)
            src: WearableSource | None = None
            count = 0
            if entry_ext == ".csv":
                src, count = _parse_csv_bytes(inner_bytes, info.filename, buckets)
            elif entry_ext == ".xml":
                src, count = _parse_xml_bytes(inner_bytes, buckets)
            elif entry_ext == ".json":
                src, count = _parse_json_bytes(inner_bytes, info.filename, buckets)
            if src:
                detected_sources.append(src)
            parsed += count
    return parsed


def _parse_csv_bytes(
    raw_bytes: bytes,
    filename: str,
    buckets: dict[str, _DailyAggregate],
) -> tuple[WearableSource | None, int]:
    text = raw_bytes.decode("utf-8-sig", errors="replace")
    lines = [line for line in text.splitlines() if line.strip()]
    if not lines:
        return None, 0

    detected_provider = _detect_provider_from_hint(filename, lines[0])
    header_idx = 0
    # Samsung Health exports prepend a metadata banner line (e.g. com.samsung.shealth...)
    if "com.samsung." in lines[0].lower() and len(lines) > 1:
        detected_provider = "samsung_health"
        header_idx = 1

    reader = csv.DictReader(lines[header_idx:])
    if not reader.fieldnames:
        return detected_provider, 0

    parsed = 0
    for row in reader:
        norm = {str(k).strip().lower(): (v.strip() if isinstance(v, str) else v) for k, v in row.items() if k}
        ts = _extract_timestamp(norm)
        if ts is None:
            continue
        hr = _first_float(
            norm,
            ("heart_rate", "heartrate", "hr", "bpm", "avg_heart_rate", "com.samsung.health.heart_rate.heart_rate"),
        )
        steps = _first_float(
            norm,
            ("steps", "step_count", "count", "total_steps", "pedometer_step_count"),
        )
        calories = _first_float(
            norm,
            ("calories", "calorie", "active_calories", "calories_burned", "total_calories"),
        )
        sleep_hours = _extract_sleep_hours(norm, ts_row=norm)
        if hr is None and steps is None and calories is None and sleep_hours is None:
            continue
        _record_bucket(
            buckets,
            ts,
            heart_rate=hr,
            steps=steps,
            calories=calories,
            sleep_hours=sleep_hours,
        )
        parsed += 1
    return detected_provider, parsed


def _parse_xml_bytes(
    raw_bytes: bytes,
    buckets: dict[str, _DailyAggregate],
) -> tuple[WearableSource | None, int]:
    text = raw_bytes.decode("utf-8-sig", errors="replace")
    lower_head = text[:2048].lower()
    if "<!entity" in lower_head:
        raise HTTPException(status_code=400, detail="Unsafe XML DOCTYPE entities rejected.")
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid XML format: {exc}") from exc

    parsed = 0
    for elem in root.iter("Record"):
        rec_type = elem.attrib.get("type", "")
        raw_val = elem.attrib.get("value", "")
        start_str = elem.attrib.get("startDate") or elem.attrib.get("creationDate")
        end_str = elem.attrib.get("endDate") or start_str
        ts = _parse_timestamp_value(start_str)
        if ts is None:
            continue

        if rec_type == "HKQuantityTypeIdentifierHeartRate":
            val = _to_float(raw_val)
            if val is not None:
                _record_bucket(buckets, ts, heart_rate=val)
                parsed += 1
        elif rec_type == "HKQuantityTypeIdentifierStepCount":
            val = _to_float(raw_val)
            if val is not None:
                day_key = ts.date().isoformat()
                bucket = buckets.setdefault(day_key, _DailyAggregate(day=day_key, latest_timestamp=ts))
                bucket.steps_total = (bucket.steps_total + val) if bucket.has_steps else val
                bucket.has_steps = True
                if ts > bucket.latest_timestamp:
                    bucket.latest_timestamp = ts
                parsed += 1
        elif rec_type == "HKQuantityTypeIdentifierActiveEnergyBurned":
            val = _to_float(raw_val)
            if val is not None:
                day_key = ts.date().isoformat()
                bucket = buckets.setdefault(day_key, _DailyAggregate(day=day_key, latest_timestamp=ts))
                bucket.calories_total = (bucket.calories_total + val) if bucket.has_calories else val
                bucket.has_calories = True
                if ts > bucket.latest_timestamp:
                    bucket.latest_timestamp = ts
                parsed += 1
        elif rec_type == "HKCategoryTypeIdentifierSleepAnalysis":
            if "Asleep" in raw_val or raw_val in ("", "1", "3", "4", "5"):
                end_ts = _parse_timestamp_value(end_str)
                if end_ts and end_ts > ts:
                    hours = (end_ts - ts).total_seconds() / 3600.0
                    _record_bucket(buckets, ts, sleep_hours=hours)
                    parsed += 1

    return ("apple_health" if parsed > 0 else None), parsed


def _parse_json_bytes(
    raw_bytes: bytes,
    filename: str,
    buckets: dict[str, _DailyAggregate],
) -> tuple[WearableSource | None, int]:
    try:
        decoded = json.loads(raw_bytes.decode("utf-8-sig", errors="replace"))
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid JSON export: {exc}") from exc

    records: list[dict[str, Any]] = []
    if isinstance(decoded, list):
        records = [item for item in decoded if isinstance(item, dict)]
    elif isinstance(decoded, dict):
        for key in ("records", "data", "samples", "vitals", "activities-heart", "sleep"):
            candidate = decoded.get(key)
            if isinstance(candidate, list):
                records.extend(item for item in candidate if isinstance(item, dict))
        if not records:
            records = [decoded]

    parsed = 0
    detected = _detect_provider_from_hint(filename, "")
    for row in records:
        norm = {str(k).strip().lower(): v for k, v in row.items()}
        ts = _extract_timestamp(norm)
        if ts is None:
            continue
        hr = _first_float(norm, ("heart_rate", "heartrate", "bpm", "restingheartrate"))
        steps = _first_float(norm, ("steps", "step_count", "count"))
        calories = _first_float(norm, ("calories", "caloriesout", "active_energy_kcal"))
        sleep_hours = _extract_sleep_hours(norm, ts_row=norm)
        if hr is None and steps is None and calories is None and sleep_hours is None:
            continue
        _record_bucket(
            buckets,
            ts,
            heart_rate=hr,
            steps=steps,
            calories=calories,
            sleep_hours=sleep_hours,
        )
        parsed += 1
    return (detected or "health_connect"), parsed


def _record_bucket(
    buckets: dict[str, _DailyAggregate],
    ts: datetime,
    *,
    heart_rate: float | None = None,
    steps: float | None = None,
    calories: float | None = None,
    sleep_hours: float | None = None,
) -> None:
    day_key = ts.date().isoformat()
    bucket = buckets.get(day_key)
    if bucket is None:
        bucket = _DailyAggregate(day=day_key, latest_timestamp=ts)
        buckets[day_key] = bucket
    bucket.add(
        ts,
        heart_rate=heart_rate,
        steps=steps,
        calories=calories,
        sleep_hours=sleep_hours,
    )


def _detect_provider_from_hint(filename: str, header_line: str) -> WearableSource | None:
    combined = f"{filename} {header_line}".lower()
    if "samsung" in combined or "shealth" in combined:
        return "samsung_health"
    if "fitbit" in combined:
        return "fitbit"
    if "garmin" in combined:
        return "garmin"
    if "strava" in combined:
        return "strava"
    if "oura" in combined:
        return "oura"
    if "whoop" in combined:
        return "whoop"
    if "withings" in combined:
        return "withings"
    if "polar" in combined:
        return "polar"
    if "health_connect" in combined or "healthconnect" in combined:
        return "health_connect"
    if "google" in combined or "fit" in combined:
        return "google_health"
    if "apple" in combined or "export.xml" in combined:
        return "apple_health"
    return None


def _extract_timestamp(norm: dict[str, Any]) -> datetime | None:
    for key in (
        "timestamp",
        "start_time",
        "day_time",
        "recorded_on",
        "datetime",
        "date",
        "create_time",
        "dateofsleep",
        "time",
    ):
        if key in norm and norm[key] not in (None, ""):
            ts = _parse_timestamp_value(norm[key])
            if ts is not None:
                return ts
    return None


def _parse_timestamp_value(raw: Any) -> datetime | None:
    if raw is None:
        return None
    if isinstance(raw, (int, float)):
        num = float(raw)
        if num > 1e12:
            num /= 1000.0
        try:
            return datetime.fromtimestamp(num, tz=timezone.utc)
        except (OSError, OverflowError, ValueError):
            return None

    text = str(raw).strip()
    if not text:
        return None
    if text.isdigit():
        num = float(text)
        if num > 1e12:
            num /= 1000.0
        try:
            return datetime.fromtimestamp(num, tz=timezone.utc)
        except (OSError, OverflowError, ValueError):
            return None

    normalized = text.replace("Z", "+00:00")
    for candidate in (
        normalized,
        normalized.replace(" ", "T"),
    ):
        try:
            dt = datetime.fromisoformat(candidate)
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            pass

    for fmt in (
        "%Y-%m-%d %H:%M:%S %z",
        "%Y-%m-%d %H:%M:%S.%f",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
        "%m/%d/%Y",
    ):
        try:
            dt = datetime.strptime(text, fmt)
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return None


def _first_float(row: dict[str, Any], keys: tuple[str, ...]) -> float | None:
    for key in keys:
        if key in row and row[key] not in (None, ""):
            val = _to_float(row[key])
            if val is not None:
                return val
    return None


def _extract_sleep_hours(row: dict[str, Any], *, ts_row: dict[str, Any]) -> float | None:
    direct_hours = _first_float(row, ("sleep", "sleep_hours", "hours_asleep"))
    if direct_hours is not None:
        return direct_hours
    minutes = _first_float(row, ("minutesasleep", "sleep_minutes", "duration_minutes", "total_minutes_asleep"))
    if minutes is not None:
        return minutes / 60.0
    millis = _first_float(row, ("sleep_duration", "duration_ms"))
    if millis is not None:
        if millis > 10000:
            return millis / 3600000.0
        return millis / 60.0 if millis > 24 else millis
    # Fallback: start_time & end_time when file itself is a sleep export
    if any("sleep" in str(k) for k in ts_row.keys()) and ts_row.get("start_time") and ts_row.get("end_time"):
        s = _parse_timestamp_value(ts_row.get("start_time"))
        e = _parse_timestamp_value(ts_row.get("end_time"))
        if s and e and e > s:
            return (e - s).total_seconds() / 3600.0
    return None


def _to_float(raw: Any) -> float | None:
    try:
        return float(str(raw).replace(",", "").strip())
    except (ValueError, TypeError):
        return None
