import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/wearable_models.dart';
import '../data/repositories/ehospital_repository.dart';
import '../data/repositories/wearable_ingestion_repository.dart';
import 'fitbit_service.dart';

abstract class WearablePlatformSyncService {
  String get source;

  Future<WearableSourceReadResult> readLatestSample({
    required String patientId,
  });
}

abstract class WearablePlatformWorkoutSyncService {
  String get source;

  Future<WearableWorkoutReadResult> readRecentWorkouts({
    required String patientId,
  });
}

class WearableSyncService {
  final WearableIngestionClient _ingestionClient;
  final WearableExportClient? _exportClient;
  final WearablePlatformSyncService _appleHealthSyncService;
  final WearablePlatformSyncService _googleHealthSyncService;
  final WearablePlatformWorkoutSyncService _appleWorkoutSyncService;
  final WearablePlatformWorkoutSyncService _googleWorkoutSyncService;
  final bool? _isWebOverride;
  final TargetPlatform? _platformOverride;

  WearableSyncService({
    WearableIngestionClient? ingestionClient,
    WearableExportClient? exportClient,
    WearablePlatformSyncService? appleHealthSyncService,
    WearablePlatformSyncService? googleHealthSyncService,
    WearablePlatformWorkoutSyncService? appleWorkoutSyncService,
    WearablePlatformWorkoutSyncService? googleWorkoutSyncService,
    bool? isWebOverride,
    TargetPlatform? platformOverride,
  }) : _ingestionClient = ingestionClient ?? WearableIngestionRepository(),
       _exportClient = _resolveExportClient(exportClient, ingestionClient),
       _appleHealthSyncService =
           appleHealthSyncService ?? AppleHealthSyncService(),
       _googleHealthSyncService =
           googleHealthSyncService ?? GoogleHealthSyncService(),
       _appleWorkoutSyncService =
           appleWorkoutSyncService ?? AppleHealthSyncService(),
       _googleWorkoutSyncService =
           googleWorkoutSyncService ?? GoogleHealthSyncService(),
       _isWebOverride = isWebOverride,
       _platformOverride = platformOverride;

  bool get _isWeb => _isWebOverride ?? kIsWeb;
  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  static WearableExportClient? _resolveExportClient(
    WearableExportClient? exportClient,
    WearableIngestionClient? ingestionClient,
  ) {
    if (exportClient != null) return exportClient;
    if (ingestionClient is WearableExportClient) {
      return ingestionClient as WearableExportClient;
    }
    if (ingestionClient == null) return WearableIngestionRepository();
    return null;
  }

  Future<WearableSyncResult> uploadManual({
    required String patientId,
    required int heartRate,
    required int steps,
    required int calories,
    required int sleep,
    DateTime? timestamp,
  }) {
    return uploadSample(
      WearableSample(
        patientId: patientId,
        heartRate: heartRate.toDouble(),
        steps: steps.toDouble(),
        calories: calories.toDouble(),
        sleep: sleep.toDouble(),
        timestamp: timestamp ?? DateTime.now(),
        source: WearableSource.manual,
      ),
    );
  }

  Future<WearableSyncResult> uploadSimulationSample({
    required String patientId,
    required int heartRate,
    required int steps,
    required int calories,
    required int sleep,
    DateTime? timestamp,
  }) {
    return uploadSample(
      WearableSample(
        patientId: patientId,
        heartRate: heartRate.toDouble(),
        steps: steps.toDouble(),
        calories: calories.toDouble(),
        sleep: sleep.toDouble(),
        timestamp: timestamp ?? DateTime.now(),
        source: WearableSource.simulation,
      ),
    );
  }

  Future<WearableSyncResult> syncPlatformHealth({
    required String patientId,
    String? preferredSourceKey,
  }) async {
    final effectivePid = (patientId.trim().isEmpty || patientId == 'null')
        ? '1'
        : patientId.trim();

    if (!_isWeb && _platform == TargetPlatform.iOS) {
      if (preferredSourceKey == WearableSource.fitbit) {
        final fitbitRes = await _trySyncFitbitCloud(effectivePid);
        if (fitbitRes != null && fitbitRes.success) return fitbitRes;
      }
      return syncFromAppleHealth(patientId: effectivePid);
    }
    if (!_isWeb && _platform == TargetPlatform.android) {
      if (preferredSourceKey == WearableSource.fitbit) {
        final fitbitRes = await _trySyncFitbitCloud(effectivePid);
        if (fitbitRes != null && fitbitRes.success) return fitbitRes;
      }
      return syncFromHealthConnect(
        patientId: effectivePid,
        preferredSourceKey: preferredSourceKey,
      );
    }

    // Web / Mobile Browser PWA: only real cloud/file connections are allowed.
    // Browsers cannot directly read on-device Samsung Health, Health Connect, or Apple Health.
    if (preferredSourceKey == null || preferredSourceKey == WearableSource.fitbit) {
      final fitbitRes = await _trySyncFitbitCloud(effectivePid);
      if (fitbitRes != null && fitbitRes.success) {
        return fitbitRes;
      }
    }

    final resolvedSource =
        preferredSourceKey ??
        (_platform == TargetPlatform.iOS
            ? WearableSource.appleHealth
            : WearableSource.healthConnect);
    final label = WearableSource.labelFor(resolvedSource);

    return WearableSyncResult.failure(
      source: resolvedSource,
      message:
          'Not connected to $label in browser mode. Browsers cannot read on-device health apps directly — upload your real $label export file (CSV/XML/JSON/ZIP) or install the Android APK to connect via Health Connect.',
    );
  }

  Future<WearableSyncResult> syncFromDetectedApp({
    required String patientId,
    required DetectedHealthApp app,
  }) async {
    return syncPlatformHealth(
      patientId: patientId,
      preferredSourceKey: app.sourceKey,
    );
  }

  Future<WearableSyncResult> syncFromHealthConnect({
    required String patientId,
    String? preferredSourceKey,
  }) async {
    final service = _googleHealthSyncService;
    if (service is GoogleHealthSyncService) {
      final read = await service.readLatestSample(
        patientId: patientId,
        preferredSourceKey: preferredSourceKey,
      );
      if (!read.success || read.sample == null) {
        return WearableSyncResult.failure(
          source: read.source,
          message: read.message ?? 'No Health Connect data available.',
        );
      }
      final ingestion = await _ingestionClient.ingest(read.sample!);
      await _recordLastConnectedProvider(read.sample!.source);
      final s = read.sample!;
      final label = WearableSource.labelFor(s.source);
      final apps = s.sourceMetadata['contributing_apps'];
      final via = apps is List && apps.isNotEmpty
          ? ' via ${apps.join(", ")}'
          : '';
      final details = <String>[
        if (s.steps != null) '${s.steps!.round()} today steps',
        if (s.heartRate != null) '${s.heartRate!.round()} bpm HR',
        if (s.calories != null) '${s.calories!.round()} kcal',
        if (s.sleep != null) '${s.sleep!.toStringAsFixed(1)}h sleep',
      ].join(', ');
      return WearableSyncResult.success(
        source: s.source,
        ingestions: [ingestion],
        message: 'Synced $label telemetry$via ($details) into EHR.',
      );
    }
    return syncFromGoogleHealth(patientId: patientId);
  }

  Future<WearableExportImportResult> importExportFile({
    required String patientId,
    required String filename,
    required List<int> bytes,
    String? provider,
  }) async {
    final exporter = _exportClient;
    if (exporter == null) {
      throw StateError('Wearable export client is not configured.');
    }
    final result = await exporter.importExportFile(
      patientId: patientId,
      filename: filename,
      bytes: bytes,
      provider: provider,
    );
    await _recordLastConnectedProvider(result.detectedProvider);
    return result;
  }

  Future<WearableSyncResult?> _trySyncFitbitCloud(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('fitbit_access_token') ?? '').trim();
      if (token.isEmpty) return null;
      final vitals = await FitbitService.getLatestVitals();
      if (vitals.isEmpty) return null;
      final hr = (vitals['heart_rate'] as num?)?.toDouble();
      final steps = (vitals['steps'] as num?)?.toDouble();
      final calories = (vitals['calories'] as num?)?.toDouble();
      final sleepMins = (vitals['sleep'] as num?)?.toDouble();
      final sleepHours = sleepMins != null && sleepMins > 0
          ? double.parse((sleepMins / 60.0).toStringAsFixed(2))
          : null;
      if ((hr ?? 0) <= 0 &&
          (steps ?? 0) <= 0 &&
          (calories ?? 0) <= 0 &&
          (sleepHours ?? 0) <= 0) {
        return null;
      }
      final sample = WearableSample(
        patientId: patientId,
        heartRate: hr != null && hr > 0 ? hr : null,
        steps: steps != null && steps > 0 ? steps : null,
        calories: calories != null && calories > 0 ? calories : null,
        sleep: sleepHours,
        timestamp: DateTime.now(),
        source: WearableSource.fitbit,
        sourceMetadata: const {'channel': 'fitbit_cloud_oauth'},
      );
      final ingestion = await _ingestionClient.ingest(sample);
      await _recordLastConnectedProvider(WearableSource.fitbit);
      return WearableSyncResult.success(
        source: WearableSource.fitbit,
        ingestions: [ingestion],
        message: 'Synced Fitbit Cloud data into EHR.',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordLastConnectedProvider(String sourceKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_wearable_source', sourceKey);
      final existing = prefs.getStringList('synced_wearable_sources') ?? const [];
      final updated = <String>{...existing, sourceKey}.toList();
      await prefs.setStringList('synced_wearable_sources', updated);
    } catch (_) {}
  }

  Future<WearableSyncResult> syncFromAppleHealth({required String patientId}) {
    return _syncFromPlatform(
      patientId: patientId,
      service: _appleHealthSyncService,
    );
  }

  Future<int> syncRecentStressFromAppleHealth({
    required String patientId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return 0;
    return _uploadHourlyStressBuckets(health: Health(), patientId: patientId);
  }

  Future<int> syncRecentStressFromPlatformHealth({
    required String patientId,
  }) async {
    if (kIsWeb) return 0;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      return _uploadHourlyStressBuckets(health: Health(), patientId: patientId);
    }
    return 0;
  }

  Future<WearableSyncResult> syncFromGoogleHealth({required String patientId}) {
    return _syncFromPlatform(
      patientId: patientId,
      service: _googleHealthSyncService,
    );
  }

  Future<WearableSyncResult> uploadSample(WearableSample sample) async {
    final ingestion = await _ingestionClient.ingest(sample);
    return WearableSyncResult.success(
      source: sample.source,
      ingestions: [ingestion],
    );
  }

  Future<WearableSyncResult> uploadWorkout(WearableWorkout workout) async {
    final ingestion = await _ingestionClient.ingestWorkout(workout);
    return WearableSyncResult.workoutsSuccess(
      source: workout.sourceProvider,
      ingestions: [ingestion],
    );
  }

  Future<WearableSyncResult> uploadWorkouts(
    List<WearableWorkout> workouts, {
    String? source,
  }) async {
    if (workouts.isEmpty) {
      return WearableSyncResult.failure(
        source: source ?? 'workout',
        message: 'No workout data available.',
      );
    }
    final ingestion = await _ingestionClient.ingestWorkoutBatch(workouts);
    return WearableSyncResult.workoutsSuccess(
      source: source ?? workouts.first.sourceProvider,
      ingestions: ingestion.workouts,
      message: 'Uploaded ${ingestion.acceptedCount} workout(s).',
    );
  }

  Future<WearableSyncResult> uploadSimulationWorkout({
    required String patientId,
    required String workoutType,
    required DateTime startTime,
    required DateTime endTime,
    double? distanceMeters,
    double? activeEnergyKcal,
    int? steps,
  }) {
    final duration = endTime.difference(startTime).inSeconds;
    return uploadWorkout(
      WearableWorkout(
        patientId: patientId,
        sourceProvider: WearableSource.simulation,
        sourceWorkoutId:
            'simulation-${patientId}-${startTime.toUtc().toIso8601String()}',
        workoutType: workoutType,
        workoutTypeRaw: workoutType,
        startTime: startTime,
        endTime: endTime,
        durationSeconds: duration < 0 ? 0 : duration,
        distanceMeters: distanceMeters,
        activeEnergyKcal: activeEnergyKcal,
        totalEnergyKcal: activeEnergyKcal,
        steps: steps,
        sourceMetadata: const {'source': 'fixture'},
      ),
    );
  }

  Future<WearableSyncResult> syncPlatformWorkouts({required String patientId}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return syncWorkoutsFromAppleHealth(patientId: patientId);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return syncWorkoutsFromGoogleHealth(patientId: patientId);
    }
    return WearableSyncResult.failure(
      source: WearableSource.healthConnect,
      message:
          'Workout sync requires the Android (Health Connect) or iOS (HealthKit) mobile app.',
    );
  }

  Future<WearableSyncResult> syncWorkoutsFromAppleHealth({
    required String patientId,
  }) {
    return _syncWorkoutsFromPlatform(
      patientId: patientId,
      service: _appleWorkoutSyncService,
    );
  }

  Future<WearableSyncResult> syncWorkoutsFromGoogleHealth({
    required String patientId,
  }) {
    return _syncWorkoutsFromPlatform(
      patientId: patientId,
      service: _googleWorkoutSyncService,
    );
  }

  Future<WearableSyncResult> _syncFromPlatform({
    required String patientId,
    required WearablePlatformSyncService service,
  }) async {
    final read = await service.readLatestSample(patientId: patientId);
    if (!read.success || read.sample == null) {
      return WearableSyncResult.failure(
        source: read.source,
        message: read.message ?? 'No wearable data available.',
      );
    }
    return uploadSample(read.sample!);
  }

  Future<WearableSyncResult> _syncWorkoutsFromPlatform({
    required String patientId,
    required WearablePlatformWorkoutSyncService service,
  }) async {
    final read = await service.readRecentWorkouts(patientId: patientId);
    if (!read.success || read.workouts.isEmpty) {
      return WearableSyncResult.failure(
        source: read.source,
        message: read.message ?? 'No workout data available.',
      );
    }
    return uploadWorkouts(read.workouts, source: read.source);
  }
}

class AppleHealthSyncService
    implements WearablePlatformSyncService, WearablePlatformWorkoutSyncService {
  final Health _health;

  AppleHealthSyncService({Health? health}) : _health = health ?? Health();

  @override
  String get source => WearableSource.appleHealth;

  @override
  Future<WearableSourceReadResult> readLatestSample({
    required String patientId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return WearableSourceReadResult.failure(
        source: source,
        message: 'Apple Health is only available on iOS devices.',
      );
    }
    return _readHealthSample(
      health: _health,
      patientId: patientId,
      source: source,
      unavailableMessage: 'No Apple Health data found in the last 24 hours.',
    );
  }

  @override
  Future<WearableWorkoutReadResult> readRecentWorkouts({
    required String patientId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return WearableWorkoutReadResult.failure(
        source: source,
        message: 'Apple Health workout sync is only available on iOS devices.',
      );
    }
    return _readHealthWorkouts(
      health: _health,
      patientId: patientId,
      source: source,
      unavailableMessage: 'No Apple Health workouts found in the last 90 days.',
    );
  }
}

class GoogleHealthSyncService
    implements WearablePlatformSyncService, WearablePlatformWorkoutSyncService {
  final Health _health;

  GoogleHealthSyncService({Health? health}) : _health = health ?? Health();

  @override
  String get source => WearableSource.googleHealth;

  @override
  Future<WearableSourceReadResult> readLatestSample({
    required String patientId,
    String? preferredSourceKey,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return WearableSourceReadResult.failure(
        source: preferredSourceKey ?? source,
        message: 'Health Connect sync is only available on Android devices.',
      );
    }

    await _health.configure();
    final hcStatus = await _health.getHealthConnectSdkStatus();
    if (hcStatus == HealthConnectSdkStatus.sdkUnavailable) {
      return WearableSourceReadResult.failure(
        source: preferredSourceKey ?? WearableSource.healthConnect,
        message:
            'Android Health Connect is not installed on this phone. Install Health Connect and allow Samsung Health (or your fitness app) to share data.',
      );
    }
    if (hcStatus ==
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      return WearableSourceReadResult.failure(
        source: preferredSourceKey ?? WearableSource.healthConnect,
        message:
            'Health Connect needs an update before reading Samsung Health / wearable data.',
      );
    }

    try {
      await Permission.activityRecognition.request();
    } catch (_) {}

    final targetName = preferredSourceKey != null
        ? WearableSource.labelFor(preferredSourceKey)
        : 'Health Connect (Samsung Health / Google Fit)';

    return _readHealthSample(
      health: _health,
      patientId: patientId,
      source: preferredSourceKey ?? source,
      preferredSourceKey: preferredSourceKey,
      isAndroid: true,
      unavailableMessage:
          'No $targetName data found in Health Connect for the last 24 hours. Make sure sharing is enabled in $targetName settings -> Health Connect.',
    );
  }

  @override
  Future<WearableWorkoutReadResult> readRecentWorkouts({
    required String patientId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return WearableWorkoutReadResult.failure(
        source: source,
        message:
            'Health Connect workout sync is only available on Android devices.',
      );
    }
    return _readHealthWorkouts(
      health: _health,
      patientId: patientId,
      source: source,
      unavailableMessage:
          'No Health Connect workouts found in the last 90 days.',
    );
  }
}

Future<WearableSourceReadResult> _readHealthSample({
  required Health health,
  required String patientId,
  required String source,
  String? preferredSourceKey,
  bool isAndroid = false,
  required String unavailableMessage,
}) async {
  await health.configure();

  final types = isAndroid
      ? const [
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_SESSION,
        ]
      : const [
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
        ];
  final permissions = types.map((_) => HealthDataAccess.READ).toList();
  final granted = await health.requestAuthorization(
    types,
    permissions: permissions,
  );
  if (!granted) {
    return WearableSourceReadResult.failure(
      source: source,
      message: 'Health permission was denied.',
    );
  }

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final since = now.subtract(const Duration(hours: 24));
  final dataPoints = await health.getHealthDataFromTypes(
    startTime: since,
    endTime: now,
    types: types,
  );
  final unique = health.removeDuplicates(dataPoints);

  int? aggregateStepsToday;
  try {
    aggregateStepsToday = await health.getTotalStepsInInterval(
      startOfToday,
      now,
    );
  } catch (_) {}

  // Discover all contributing health apps in this fetch.
  final contributingLabels = <String>{};
  final contributingSourceKeys = <String>{};
  final sourcePointCounts = <String, int>{};
  for (final point in unique) {
    final key = WearableSource.fromSourceIdentifier(
      '${point.sourceId} ${point.sourceName}',
      fallback: source,
    );
    contributingSourceKeys.add(key);
    sourcePointCounts[key] = (sourcePointCounts[key] ?? 0) + 1;
    final label = point.sourceName.trim().isNotEmpty
        ? point.sourceName.trim()
        : WearableSource.labelFor(key);
    contributingLabels.add(label);
  }

  // If user specifically requested a health app (e.g. Google Fit or Samsung Health)
  // and it has points in Health Connect, filter to that app's points.
  final filteredByApp =
      preferredSourceKey != null &&
          contributingSourceKeys.contains(preferredSourceKey);
  final selectedPoints = filteredByApp
      ? unique.where((point) {
          final key = WearableSource.fromSourceIdentifier(
            '${point.sourceId} ${point.sourceName}',
            fallback: source,
          );
          return key == preferredSourceKey;
        }).toList()
      : unique;

  int rawTodaySteps = 0;
  double totalHeartRate = 0;
  int heartRateCount = 0;
  double activeCalories = 0;
  double totalCalories = 0;
  double sleepAsleepMinutes = 0;
  double sleepStageMinutes = 0;
  double sleepSessionMinutes = 0;

  for (final point in selectedPoints) {
    final value = point.value;
    final numVal = value is NumericHealthValue ? value.numericValue.toDouble() : null;
    final isToday = !point.dateTo.isBefore(startOfToday);
    switch (point.type) {
      case HealthDataType.STEPS:
        if (isToday && numVal != null) rawTodaySteps += numVal.round();
        break;
      case HealthDataType.HEART_RATE:
        if (numVal != null) {
          totalHeartRate += numVal;
          heartRateCount++;
        }
        break;
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        if (isToday && numVal != null) activeCalories += numVal;
        break;
      case HealthDataType.TOTAL_CALORIES_BURNED:
        if (isToday && numVal != null) totalCalories += numVal;
        break;
      case HealthDataType.SLEEP_ASLEEP:
        sleepAsleepMinutes +=
            numVal ?? point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
        break;
      case HealthDataType.SLEEP_DEEP:
      case HealthDataType.SLEEP_LIGHT:
      case HealthDataType.SLEEP_REM:
        sleepStageMinutes +=
            numVal ?? point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
        break;
      case HealthDataType.SLEEP_SESSION:
        sleepSessionMinutes +=
            numVal ?? point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
        break;
      default:
        break;
    }
  }

  final useAggregateSteps =
      aggregateStepsToday != null &&
      (!filteredByApp || contributingSourceKeys.length <= 1);
  final steps = useAggregateSteps ? aggregateStepsToday : rawTodaySteps;

  final effectiveCalories =
      activeCalories > 0 ? activeCalories : totalCalories;
  final effectiveSleepMinutes = sleepStageMinutes > 0
      ? sleepStageMinutes
      : (sleepAsleepMinutes > 0 ? sleepAsleepMinutes : sleepSessionMinutes);

  final averageHeartRate = heartRateCount > 0
      ? (totalHeartRate / heartRateCount).round()
      : 0;
  final sleepHours = effectiveSleepMinutes / 60.0;
  if (steps == 0 &&
      averageHeartRate == 0 &&
      effectiveCalories == 0 &&
      sleepHours == 0) {
    return WearableSourceReadResult.failure(
      source: source,
      message: unavailableMessage,
    );
  }

  // Pick resolved canonical source from actual dominant contributing app.
  var resolvedSource = source;
  if (preferredSourceKey != null &&
      contributingSourceKeys.contains(preferredSourceKey)) {
    resolvedSource = preferredSourceKey;
  } else if (sourcePointCounts.isNotEmpty) {
    final sorted = sourcePointCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    resolvedSource = sorted.first.key;
  }

  return WearableSourceReadResult.success(
    WearableSample(
      patientId: patientId,
      heartRate: averageHeartRate > 0 ? averageHeartRate.toDouble() : null,
      steps: steps > 0 ? steps.toDouble() : null,
      calories: effectiveCalories > 0 ? effectiveCalories.roundToDouble() : null,
      sleep: sleepHours > 0
          ? double.parse(sleepHours.toStringAsFixed(2))
          : null,
      timestamp: now,
      source: resolvedSource,
      sourceMetadata: {
        'contributing_apps': contributingLabels.toList(),
        'detected_sources': contributingSourceKeys.toList(),
        'steps_method':
            useAggregateSteps ? 'os_aggregate_today' : 'filtered_today_points',
        'platform': isAndroid ? 'android_health_connect' : 'ios_healthkit',
      },
    ),
  );
}

class _StressBucket {
  final DateTime hour;
  final List<double> hrvSdnn = [];
  final List<double> restingHeartRate = [];
  final List<double> respiratoryRate = [];
  final List<double> heartRate = [];

  _StressBucket(this.hour);

  double? avg(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

Future<int> _uploadHourlyStressBuckets({
  required Health health,
  required String patientId,
}) async {
  await health.configure();
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final hrvType = isAndroid
      ? HealthDataType.HEART_RATE_VARIABILITY_RMSSD
      : HealthDataType.HEART_RATE_VARIABILITY_SDNN;
  final types = [
    hrvType,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.HEART_RATE,
  ];
  final permissions = types.map((_) => HealthDataAccess.READ).toList();
  final granted = await health.requestAuthorization(
    types,
    permissions: permissions,
  );
  if (!granted) return 0;

  final now = DateTime.now();
  final since = now.subtract(const Duration(hours: 24));
  final points = health.removeDuplicates(
    await health.getHealthDataFromTypes(
      startTime: since,
      endTime: now,
      types: types,
    ),
  );
  final buckets = <DateTime, _StressBucket>{};
  for (final point in points) {
    final value = point.value;
    if (value is! NumericHealthValue) continue;
    final local = point.dateFrom.toLocal();
    final hour = DateTime(local.year, local.month, local.day, local.hour);
    final bucket = buckets.putIfAbsent(hour, () => _StressBucket(hour));
    switch (point.type) {
      case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
      case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
        bucket.hrvSdnn.add(value.numericValue.toDouble());
        break;
      case HealthDataType.RESTING_HEART_RATE:
        bucket.restingHeartRate.add(value.numericValue.toDouble());
        break;
      case HealthDataType.RESPIRATORY_RATE:
        bucket.respiratoryRate.add(value.numericValue.toDouble());
        break;
      case HealthDataType.HEART_RATE:
        bucket.heartRate.add(value.numericValue.toDouble());
        break;
      default:
        break;
    }
  }

  var uploaded = 0;
  final repo = EHospitalRepository();
  final sorted = buckets.values.toList()
    ..sort((a, b) => a.hour.compareTo(b.hour));
  for (final bucket in sorted) {
    final hrv = bucket.avg(bucket.hrvSdnn);
    final resting = bucket.avg(bucket.restingHeartRate);
    final respiratory = bucket.avg(bucket.respiratoryRate);
    if (hrv == null && resting == null && respiratory == null) continue;
    await repo.sendStressSnapshot(
      patientId: patientId,
      hrvSdnn: hrv,
      restingHeartRate: resting,
      respiratoryRate: respiratory,
      heartRate: bucket.avg(bucket.heartRate),
      timestamp: bucket.hour.toUtc().toIso8601String(),
    );
    uploaded++;
  }
  return uploaded;
}

Future<WearableWorkoutReadResult> _readHealthWorkouts({
  required Health health,
  required String patientId,
  required String source,
  required String unavailableMessage,
}) async {
  await health.configure();

  const types = [HealthDataType.WORKOUT];
  const permissions = [HealthDataAccess.READ];
  final granted = await health.requestAuthorization(
    types,
    permissions: permissions,
  );
  if (!granted) {
    return WearableWorkoutReadResult.failure(
      source: source,
      message: 'Health workout permission was denied.',
    );
  }

  final now = DateTime.now();
  final since = now.subtract(const Duration(days: 90));
  final dataPoints = await health.getHealthDataFromTypes(
    startTime: since,
    endTime: now,
    types: types,
  );
  final unique = health.removeDuplicates(dataPoints);
  final workouts = unique
      .where((point) => point.type == HealthDataType.WORKOUT)
      .map((point) => _workoutFromHealthPoint(point, patientId, source))
      .whereType<WearableWorkout>()
      .toList();

  if (workouts.isEmpty) {
    return WearableWorkoutReadResult.failure(
      source: source,
      message: unavailableMessage,
    );
  }

  return WearableWorkoutReadResult.success(source: source, workouts: workouts);
}

WearableWorkout? _workoutFromHealthPoint(
  HealthDataPoint point,
  String patientId,
  String source,
) {
  final value = point.value;
  if (value is! WorkoutHealthValue) return null;
  final duration = point.dateTo.difference(point.dateFrom).inSeconds;
  final rawType = value.workoutActivityType.name;
  final metadata = <String, dynamic>{
    'source_platform': point.sourcePlatform.name,
    'source_id': point.sourceId,
    'source_name': point.sourceName,
    'source_device_id': point.sourceDeviceId,
    'recording_method': point.recordingMethod.name,
    if (value.totalEnergyBurnedUnit != null)
      'total_energy_burned_unit': value.totalEnergyBurnedUnit!.name,
    if (value.totalDistanceUnit != null)
      'total_distance_unit': value.totalDistanceUnit!.name,
    if (value.totalStepsUnit != null)
      'total_steps_unit': value.totalStepsUnit!.name,
    if (point.metadata != null) 'metadata': point.metadata,
  };
  return WearableWorkout(
    patientId: patientId,
    sourceProvider: source,
    sourceWorkoutId: point.uuid,
    sourceBundleId: point.sourceId,
    sourceDeviceName: point.sourceName,
    sourceDeviceModel: point.deviceModel,
    workoutType: _normalizeWorkoutType(rawType),
    workoutTypeRaw: rawType,
    startTime: point.dateFrom,
    endTime: point.dateTo,
    durationSeconds: duration < 0 ? 0 : duration,
    distanceMeters: _distanceMeters(
      value.totalDistance,
      value.totalDistanceUnit,
    ),
    activeEnergyKcal: _energyKcal(
      value.totalEnergyBurned,
      value.totalEnergyBurnedUnit,
    ),
    totalEnergyKcal: _energyKcal(
      value.totalEnergyBurned,
      value.totalEnergyBurnedUnit,
    ),
    steps: value.totalSteps,
    sourceMetadata: metadata,
    rawPayload: point.toJson(),
  );
}

double? _distanceMeters(int? value, HealthDataUnit? unit) {
  if (value == null) return null;
  switch (unit) {
    case HealthDataUnit.METER:
    case null:
      return value.toDouble();
    case HealthDataUnit.CENTIMETER:
      return value / 100;
    default:
      return value.toDouble();
  }
}

double? _energyKcal(int? value, HealthDataUnit? unit) {
  if (value == null) return null;
  return value.toDouble();
}

String _normalizeWorkoutType(String rawType) {
  switch (rawType) {
    case 'RUNNING':
    case 'RUNNING_TREADMILL':
      return 'running';
    case 'BIKING':
    case 'BIKING_STATIONARY':
      return 'cycling';
    case 'WALKING':
    case 'WALKING_TREADMILL':
      return 'walking';
    case 'SWIMMING':
    case 'SWIMMING_OPEN_WATER':
    case 'SWIMMING_POOL':
      return 'swimming';
    default:
      return rawType.toLowerCase();
  }
}
