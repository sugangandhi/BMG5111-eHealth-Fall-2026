import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:health/health.dart';
import '../../../data/models/wearable_models.dart';
import '../models/night_sleep.dart';

/// Reads real sleep data from mobile health platforms:
/// Apple HealthKit on iOS and Health Connect (Samsung Health, Google Fit, etc.) on Android.
/// Groups sleep stages (deep, REM, core/light, awake), blood oxygen (SpO2),
/// and heart rate into per-night summaries consumed by the UI and backend.
class HealthSleepService {
  final Health _health = Health();

  static const _iosTypes = <HealthDataType>[
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.HEART_RATE,
  ];

  static const _androidTypes = <HealthDataType>[
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.HEART_RATE,
  ];

  List<HealthDataType> get _types =>
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? _androidTypes
          : _iosTypes;

  /// Ask the user for read access to the sleep-related HealthKit types.
  Future<bool> requestPermissions() async {
    await _health.configure();
    final permissions = _types.map((_) => HealthDataAccess.READ).toList();
    // hasPermissions can return null on iOS; fall back to requesting.
    final already = await _health.hasPermissions(
      _types,
      permissions: permissions,
    );
    if (already == true) return true;
    return _health.requestAuthorization(_types, permissions: permissions);
  }

  /// Fetch the last [nights] nights of sleep and roll them up per night.
  /// A "sleep night" is keyed by the calendar date the sleep session started.
  Future<List<NightSleep>> fetchNightlySleep({int nights = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: nights + 1));

    final raw = await _health.getHealthDataFromTypes(
      startTime: start,
      endTime: now,
      types: _types,
    );
    final points = _health.removeDuplicates(raw);

    // Accumulators keyed by night (yyyy-MM-dd).
    final deep = <String, double>{};
    final rem = <String, double>{};
    final core = <String, double>{};
    final awake = <String, double>{};
    final asleep = <String, double>{};
    final inBed = <String, double>{};
    final spo2 = <String, List<double>>{};
    final hr = <String, List<double>>{};
    final sessionMinutes = <String, double>{};
    final nightSource = <String, String>{};
    final defaultSource =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? WearableSource.healthConnect
        : WearableSource.appleHealth;

    void addMinutes(
      Map<String, double> map,
      String night,
      DateTime a,
      DateTime b,
    ) {
      final minutes = b.difference(a).inSeconds / 60.0;
      map[night] = (map[night] ?? 0) + (minutes < 0 ? 0 : minutes);
    }

    for (final p in points) {
      final night = _nightKey(p.dateFrom);
      nightSource.putIfAbsent(
        night,
        () => WearableSource.fromSourceIdentifier(
          '${p.sourceId} ${p.sourceName}',
          fallback: defaultSource,
        ),
      );
      switch (p.type) {
        case HealthDataType.SLEEP_DEEP:
          addMinutes(deep, night, p.dateFrom, p.dateTo);
          addMinutes(asleep, night, p.dateFrom, p.dateTo);
          break;
        case HealthDataType.SLEEP_REM:
          addMinutes(rem, night, p.dateFrom, p.dateTo);
          addMinutes(asleep, night, p.dateFrom, p.dateTo);
          break;
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_ASLEEP:
          addMinutes(core, night, p.dateFrom, p.dateTo);
          addMinutes(asleep, night, p.dateFrom, p.dateTo);
          break;
        case HealthDataType.SLEEP_SESSION:
          addMinutes(sessionMinutes, night, p.dateFrom, p.dateTo);
          break;
        case HealthDataType.SLEEP_AWAKE:
          addMinutes(awake, night, p.dateFrom, p.dateTo);
          break;
        case HealthDataType.SLEEP_IN_BED:
          addMinutes(inBed, night, p.dateFrom, p.dateTo);
          break;
        case HealthDataType.BLOOD_OXYGEN:
          final v = _numeric(p.value);
          if (v != null) (spo2[night] ??= []).add(v <= 1 ? v * 100 : v);
          break;
        case HealthDataType.HEART_RATE:
          final v = _numeric(p.value);
          if (v != null) (hr[night] ??= []).add(v);
          break;
        default:
          break;
      }
    }

    final allNights = <String>{
      ...deep.keys,
      ...rem.keys,
      ...core.keys,
      ...awake.keys,
      ...asleep.keys,
      ...sessionMinutes.keys,
    }.toList()..sort();

    double? avg(List<double>? xs) => (xs == null || xs.isEmpty)
        ? null
        : xs.reduce((a, b) => a + b) / xs.length;
    double? lo(List<double>? xs) =>
        (xs == null || xs.isEmpty) ? null : xs.reduce((a, b) => a < b ? a : b);

    final result = <NightSleep>[];
    for (final night in allNights) {
      final rawAsleep = asleep[night] ?? 0;
      final effectiveAsleep =
          rawAsleep > 0 ? rawAsleep : (sessionMinutes[night] ?? 0);
      final effectiveCore =
          rawAsleep > 0 ? (core[night] ?? 0) : effectiveAsleep;
      final ib = inBed[night] ?? (effectiveAsleep + (awake[night] ?? 0));
      result.add(
        NightSleep(
          night: night,
          deepMinutes: deep[night] ?? 0,
          remMinutes: rem[night] ?? 0,
          coreMinutes: effectiveCore,
          lightMinutes: 0,
          awakeMinutes: awake[night] ?? 0,
          asleepMinutes: effectiveAsleep,
          inBedMinutes: ib,
          spo2Avg: avg(spo2[night]),
          spo2Min: lo(spo2[night]),
          hrAvg: avg(hr[night]),
          hrMin: lo(hr[night]),
          source: nightSource[night] ?? defaultSource,
        ),
      );
    }

    // Keep only the most recent [nights] with actual sleep recorded.
    final withSleep = result.where((n) => n.asleepMinutes > 0).toList();
    if (withSleep.length > nights) {
      return withSleep.sublist(withSleep.length - nights);
    }
    return withSleep;
  }

  /// A sleep session that starts after midnight (e.g. 1am) still belongs to the
  /// previous evening's "night"; anything before 6pm is bucketed to that date.
  String _nightKey(DateTime start) {
    final local = start.toLocal();
    final d = local.hour < 18 ? local.subtract(const Duration(days: 1)) : local;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  double? _numeric(HealthValue value) {
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    return null;
  }
}
