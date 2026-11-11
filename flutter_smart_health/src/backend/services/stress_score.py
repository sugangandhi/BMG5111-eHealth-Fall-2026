from __future__ import annotations

from __future__ import annotations


def _clamp(value: float, low: float = 0.0, high: float = 100.0) -> float:
    return max(low, min(high, value))


def _hrv_component(hrv: float) -> float:
    # High HRV (>= 75 ms) = relaxed (5-15 score)
    # 45 - 75 ms = normal/calm (15-40 score)
    # 25 - 45 ms = mild/moderate stress (40-70 score)
    # < 25 ms = high stress (70-95 score)
    if hrv >= 75.0:
        return _clamp(15.0 - (hrv - 75.0) * 0.2, 5.0, 15.0)
    elif hrv >= 45.0:
        return 40.0 - ((hrv - 45.0) / 30.0) * 25.0
    elif hrv >= 25.0:
        return 70.0 - ((hrv - 25.0) / 20.0) * 30.0
    else:
        return _clamp(70.0 + ((25.0 - hrv) / 25.0) * 25.0, 70.0, 95.0)


def _hr_elevation_component(
    current_heart_rate: float,
    resting_heart_rate: float | None = None,
) -> float:
    baseline = resting_heart_rate if resting_heart_rate is not None and resting_heart_rate > 30 else 65.0
    delta = current_heart_rate - baseline
    if delta <= 0:
        return 15.0
    elif delta <= 15.0:
        return 20.0 + (delta / 15.0) * 20.0
    elif delta <= 35.0:
        return 40.0 + ((delta - 15.0) / 20.0) * 30.0
    else:
        return _clamp(70.0 + ((delta - 35.0) / 25.0) * 25.0, 70.0, 95.0)


def _resting_hr_component(resting_heart_rate: float) -> float:
    return _clamp(20.0 + (resting_heart_rate - 60.0) * 1.5, 10.0, 85.0)


def _respiratory_component(respiratory_rate: float) -> float:
    return _clamp(25.0 + (respiratory_rate - 14.0) * 4.5, 10.0, 90.0)


def compute_stress_score(
    hrv_sdnn: float | None,
    resting_heart_rate: float | None,
    respiratory_rate: float | None,
    current_heart_rate: float | None = None,
) -> float | None:
    components: list[tuple[float, float]] = []

    if hrv_sdnn is not None and hrv_sdnn > 0:
        components.append((0.50, _hrv_component(hrv_sdnn)))

    if current_heart_rate is not None and current_heart_rate > 0:
        hr_weight = 0.35 if (hrv_sdnn is not None and hrv_sdnn > 0) else 0.70
        components.append((hr_weight, _hr_elevation_component(current_heart_rate, resting_heart_rate)))
    elif resting_heart_rate is not None and resting_heart_rate > 0:
        r_weight = 0.35 if (hrv_sdnn is not None and hrv_sdnn > 0) else 0.70
        components.append((r_weight, _resting_hr_component(resting_heart_rate)))

    if respiratory_rate is not None and respiratory_rate > 0:
        components.append((0.15, _respiratory_component(respiratory_rate)))

    if not components:
        return None

    total_weight = sum(weight for weight, _ in components)
    weighted = sum(weight * score for weight, score in components)
    return round(_clamp(weighted / total_weight), 1)

