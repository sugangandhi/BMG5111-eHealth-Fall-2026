import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/wearable_models.dart';
import '../data/repositories/ehospital_repository.dart';
import '../data/repositories/wearable_ingestion_repository.dart';
import 'fitbit_service.dart';
import 'mobile_health_registry_service.dart';

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
      final syncWindow = s.sourceMetadata['sync_window']?.toString();
      final isFallbackWindow =
          syncWindow == 'latest_within_29d' || syncWindow == 'last_24h_previous_day';
      final dayStr = s.timestamp.toLocal().toIso8601String().split('T').first;
      final stepsLabel = isFallbackWindow ? 'steps' : 'today steps';
      final details = <String>[
        if (s.steps != null) '${s.steps!.round()} $stepsLabel',
        if (s.heartRate != null) '${s.heartRate!.round()} bpm HR',
        if (s.calories != null) '${s.calories!.round()} kcal',
        if (s.sleep != null) '${s.sleep!.toStringAsFixed(1)}h sleep',
      ].join(', ');
      final dateSuffix = isFallbackWindow ? ' (latest recorded $dayStr)' : '';
      return WearableSyncResult.success(
        source: s.source,
        ingestions: [ingestion],
        message: 'Synced $label telemetry$via ($details)$dateSuffix into EHR.',
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
  final Future<Map<String, dynamic>?> Function()? _diagnosticsProvider;
  final bool? _isWebOverride;
  final TargetPlatform? _platformOverride;

  GoogleHealthSyncService({
    Health? health,
    Future<Map<String, dynamic>?> Function()? diagnosticsProvider,
    bool? isWebOverride,
    TargetPlatform? platformOverride,
  }) : _health = health ?? Health(),
       _diagnosticsProvider = diagnosticsProvider,
       _isWebOverride = isWebOverride,
       _platformOverride = platformOverride;

  bool get _isWeb => _isWebOverride ?? kIsWeb;
  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  @override
  String get source => WearableSource.googleHealth;

  @override
  Future<WearableSourceReadResult> readLatestSample({
    required String patientId,
    String? preferredSourceKey,
  }) async {
    if (_isWeb || _platform != TargetPlatform.android) {
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
      diagnosticsProvider:
          _diagnosticsProvider ??
          () => MobileHealthRegistryService(
                isWebOverride: _isWebOverride,
                platformOverride: _platformOverride,
                health: _health,
              ).diagnoseHealthConnect(),
      unavailableMessage:
          'No $targetName data found in Health Connect for the last 24 hours. Make sure sharing is enabled in $targetName settings -> Health Connect.',
    );
  }

  @override
  Future<WearableWorkoutReadResult> readRecentWorkouts({
    required String patientId,
  }) async {
    if (_isWeb || _platform != TargetPlatform.android) {
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

const _androidVitalTypes = <HealthDataType>[
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.TOTAL_CALORIES_BURNED,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
  HealthDataType.SLEEP_SESSION,
];

const _iosVitalTypes = <HealthDataType>[
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
];

const _healthPermissionLabels = <HealthDataType, String>{
  HealthDataType.STEPS: 'Steps',
  HealthDataType.HEART_RATE: 'Heart Rate',
  HealthDataType.RESTING_HEART_RATE: 'Heart Rate',
  HealthDataType.ACTIVE_ENERGY_BURNED: 'Active Calories',
  HealthDataType.TOTAL_CALORIES_BURNED: 'Total Calories',
  HealthDataType.SLEEP_ASLEEP: 'Sleep',
  HealthDataType.SLEEP_DEEP: 'Sleep',
  HealthDataType.SLEEP_LIGHT: 'Sleep',
  HealthDataType.SLEEP_REM: 'Sleep',
  HealthDataType.SLEEP_SESSION: 'Sleep',
};

class _HealthReadPermissionStatus {
  final List<HealthDataType> grantedTypes;
  final List<String> missingCoreLabels;

  const _HealthReadPermissionStatus({
    required this.grantedTypes,
    required this.missingCoreLabels,
  });
}

Future<_HealthReadPermissionStatus> _requestAndVerifyReadPermissions({
  required Health health,
  required List<HealthDataType> types,
  required bool isAndroid,
}) async {
  if (!isAndroid) {
    final permissions = types.map((_) => HealthDataAccess.READ).toList();
    final granted = await health.requestAuthorization(
      types,
      permissions: permissions,
    );
    return _HealthReadPermissionStatus(
      grantedTypes: granted ? types : const [],
      missingCoreLabels: granted ? const [] : const ['Health Data'],
    );
  }

  Future<List<HealthDataType>?> probeGranted() async {
    final granted = <HealthDataType>[];
    var sawNull = false;
    for (final type in types) {
      bool? hasPerm;
      try {
        hasPerm = await health.hasPermissions(
          [type],
          permissions: const [HealthDataAccess.READ],
        );
      } catch (_) {
        hasPerm = null;
      }
      if (hasPerm == null) {
        sawNull = true;
      } else if (hasPerm) {
        granted.add(type);
      }
    }
    return sawNull && granted.isEmpty ? null : granted;
  }

  final initialGranted = await probeGranted();
  final typesToRequest = initialGranted == null
      ? types
      : types.where((t) => !initialGranted.contains(t)).toList();

  var authGranted = initialGranted != null && typesToRequest.isEmpty;
  if (typesToRequest.isNotEmpty) {
    authGranted = await health.requestAuthorization(
      typesToRequest,
      permissions: typesToRequest.map((_) => HealthDataAccess.READ).toList(),
    );
  }

  final verifiedGranted = await probeGranted();
  final resolvedGranted =
      verifiedGranted ?? (authGranted ? types : const <HealthDataType>[]);

  final missingLabels = <String>{};
  for (final type in types) {
    if (!resolvedGranted.contains(type)) {
      final label = _healthPermissionLabels[type];
      if (label != null) missingLabels.add(label);
    }
  }

  return _HealthReadPermissionStatus(
    grantedTypes: resolvedGranted,
    missingCoreLabels: missingLabels.toList(),
  );
}

class _SourceSelection {
  final List<HealthDataPoint> points;
  final List<String> contributingLabels;
  final List<String> contributingSourceKeys;
  final String resolvedSource;
  final bool filteredByApp;

  const _SourceSelection({
    required this.points,
    required this.contributingLabels,
    required this.contributingSourceKeys,
    required this.resolvedSource,
    required this.filteredByApp,
  });
}

_SourceSelection _resolveSourceSelection(
  List<HealthDataPoint> points, {
  required String fallbackSource,
  String? preferredSourceKey,
}) {
  final contributingLabels = <String>{};
  final contributingSourceKeys = <String>{};
  final sourcePointCounts = <String, int>{};

  for (final point in points) {
    final key = WearableSource.fromSourceIdentifier(
      '${point.sourceId} ${point.sourceName}',
      fallback: fallbackSource,
    );
    contributingSourceKeys.add(key);
    sourcePointCounts[key] = (sourcePointCounts[key] ?? 0) + 1;
    final label = point.sourceName.trim().isNotEmpty
        ? point.sourceName.trim()
        : WearableSource.labelFor(key);
    contributingLabels.add(label);
  }

  final filteredByApp =
      preferredSourceKey != null &&
      contributingSourceKeys.contains(preferredSourceKey);
  final selectedPoints = filteredByApp
      ? points.where((point) {
          final key = WearableSource.fromSourceIdentifier(
            '${point.sourceId} ${point.sourceName}',
            fallback: fallbackSource,
          );
          return key == preferredSourceKey;
        }).toList()
      : points;

  var resolvedSource = fallbackSource;
  if (preferredSourceKey != null &&
      contributingSourceKeys.contains(preferredSourceKey)) {
    resolvedSource = preferredSourceKey;
  } else if (sourcePointCounts.isNotEmpty) {
    final sorted = sourcePointCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    resolvedSource = sorted.first.key;
  }

  return _SourceSelection(
    points: selectedPoints,
    contributingLabels: contributingLabels.toList(),
    contributingSourceKeys: contributingSourceKeys.toList(),
    resolvedSource: resolvedSource,
    filteredByApp: filteredByApp,
  );
}

class _MetricsSummary {
  final int steps;
  final int averageHeartRate;
  final double effectiveCalories;
  final double sleepHours;
  final bool useAggregateSteps;
  final DateTime? latestPointTimestamp;

  const _MetricsSummary({
    required this.steps,
    required this.averageHeartRate,
    required this.effectiveCalories,
    required this.sleepHours,
    required this.useAggregateSteps,
    this.latestPointTimestamp,
  });

  bool get hasAnyMetric =>
      steps > 0 ||
      averageHeartRate > 0 ||
      effectiveCalories > 0 ||
      sleepHours > 0;
}

_MetricsSummary _summarizeHealthPoints({
  required List<HealthDataPoint> points,
  required DateTime windowStart,
  DateTime? windowEnd,
  int? aggregateSteps,
  required bool allowAggregateSteps,
  required bool filterStepsCaloriesToWindow,
}) {
  var rawSteps = 0;
  var workoutSteps = 0;
  var totalHeartRate = 0.0;
  var heartRateCount = 0;
  var restingHeartRateTotal = 0.0;
  var restingHeartRateCount = 0;
  var activeCalories = 0.0;
  var totalCalories = 0.0;
  var workoutCalories = 0.0;
  var sleepAsleepMinutes = 0.0;
  var sleepStageMinutes = 0.0;
  var sleepSessionMinutes = 0.0;
  DateTime? latestTs;

  for (final point in points) {
    final endLocal = point.dateTo.toLocal();
    if (latestTs == null || endLocal.isAfter(latestTs)) {
      latestTs = endLocal;
    }

    final inStepCalorieWindow =
        !filterStepsCaloriesToWindow ||
        (!endLocal.isBefore(windowStart) &&
            (windowEnd == null || !endLocal.isAfter(windowEnd)));

    final value = point.value;
    final numVal = value is NumericHealthValue ? value.numericValue.toDouble() : null;
    switch (point.type) {
      case HealthDataType.STEPS:
        if (inStepCalorieWindow && numVal != null) rawSteps += numVal.round();
        break;
      case HealthDataType.HEART_RATE:
        if (inStepCalorieWindow && numVal != null) {
          totalHeartRate += numVal;
          heartRateCount++;
        }
        break;
      case HealthDataType.RESTING_HEART_RATE:
        if (inStepCalorieWindow && numVal != null) {
          restingHeartRateTotal += numVal;
          restingHeartRateCount++;
        }
        break;
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        if (inStepCalorieWindow && numVal != null) activeCalories += numVal;
        break;
      case HealthDataType.TOTAL_CALORIES_BURNED:
        if (inStepCalorieWindow && numVal != null) totalCalories += numVal;
        break;
      case HealthDataType.WORKOUT:
        if (inStepCalorieWindow && value is WorkoutHealthValue) {
          if ((value.totalSteps ?? 0) > 0) workoutSteps += value.totalSteps!;
          if ((value.totalEnergyBurned ?? 0) > 0) {
            workoutCalories += value.totalEnergyBurned!.toDouble();
          }
        }
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
      aggregateSteps != null &&
      aggregateSteps > 0 &&
      allowAggregateSteps;
  final resolvedSteps = useAggregateSteps
      ? aggregateSteps
      : (rawSteps > 0 ? rawSteps : workoutSteps);

  final effectiveCalories = activeCalories > 0
      ? activeCalories
      : (totalCalories > 0 ? totalCalories : workoutCalories);
  final effectiveSleepMinutes = sleepStageMinutes > 0
      ? sleepStageMinutes
      : (sleepAsleepMinutes > 0 ? sleepAsleepMinutes : sleepSessionMinutes);
  final averageHeartRate = heartRateCount > 0
      ? (totalHeartRate / heartRateCount).round()
      : (restingHeartRateCount > 0
            ? (restingHeartRateTotal / restingHeartRateCount).round()
            : 0);

  return _MetricsSummary(
    steps: resolvedSteps,
    averageHeartRate: averageHeartRate,
    effectiveCalories: effectiveCalories,
    sleepHours: effectiveSleepMinutes / 60.0,
    useAggregateSteps: useAggregateSteps,
    latestPointTimestamp: latestTs,
  );
}

@visibleForTesting
String buildHealthConnectDiagnosticMessage({
  required String targetName,
  required List<String> missingCoreLabels,
  Map<String, dynamic>? nativeDiagnostics,
  required String fallbackMessage,
}) {
  final nativeMissing =
      (nativeDiagnostics?['missingCorePermissions'] as List?)
          ?.map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList() ??
      const <String>[];
  final missing = <String>{...missingCoreLabels, ...nativeMissing}.toList();
  if (missing.isNotEmpty) {
    return 'eHospital is missing Health Connect read access for: ${missing.join(', ')}. Tap "Permissions" above -> eHospital -> Allow all, then tap Sync again.';
  }

  if (nativeDiagnostics == null || nativeDiagnostics['available'] == false) {
    return fallbackMessage;
  }

  final originLabelsRaw = nativeDiagnostics['originLabels'];
  final origins29dRaw = nativeDiagnostics['dataOrigins29d'];
  final records29d =
      (nativeDiagnostics['records29dCount'] as num?)?.toInt() ?? 0;

  final isGenericHub = targetName == 'Health Connect';
  final appLabel = isGenericHub
      ? 'your health app (such as Samsung Health or Google Fit)'
      : targetName;

  if (origins29dRaw is Map && origins29dRaw.isNotEmpty) {
    final labels = <String>[];
    for (final entry in origins29dRaw.entries) {
      final pkg = entry.key.toString();
      final label = originLabelsRaw is Map && originLabelsRaw[pkg] != null
          ? originLabelsRaw[pkg].toString()
          : WearableSource.labelFor(
              WearableSource.fromSourceIdentifier(pkg),
            );
      labels.add('$label (${entry.value})');
    }
    return 'eHospital has Health Connect permissions and found records from ${labels.join(', ')} in the last 29 days, but no readable vitals matched $appLabel. Check $appLabel -> Settings -> Connected services -> Health Connect and ensure "Allow to write" is ON.';
  }

  if (records29d == 0) {
    return 'eHospital has Health Connect read permissions, but Health Connect currently holds 0 records from $appLabel in the last 29 days. Open Health Connect -> App permissions -> $appLabel and ensure "Allow to write" is ON, then open Samsung Health Home once to sync before tapping Sync here.';
  }

  return fallbackMessage;
}

Future<WearableSourceReadResult> _readHealthSample({
  required Health health,
  required String patientId,
  required String source,
  String? preferredSourceKey,
  bool isAndroid = false,
  Future<Map<String, dynamic>?> Function()? diagnosticsProvider,
  required String unavailableMessage,
}) async {
  await health.configure();

  final types = isAndroid ? _androidVitalTypes : _iosVitalTypes;
  final permStatus = await _requestAndVerifyReadPermissions(
    health: health,
    types: types,
    isAndroid: isAndroid,
  );
  if (permStatus.grantedTypes.isEmpty) {
    final missingText = permStatus.missingCoreLabels.isEmpty
        ? 'health vitals'
        : permStatus.missingCoreLabels.join(', ');
    return WearableSourceReadResult.failure(
      source: source,
      message: isAndroid
          ? 'Health Connect read permission is required for: $missingText. Tap "Permissions" above -> eHospital -> Allow all.'
          : 'Health permission was denied.',
    );
  }

  final targetName = preferredSourceKey != null
      ? WearableSource.labelFor(preferredSourceKey)
      : 'Health Connect';

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final since24h = now.subtract(const Duration(hours: 24));
  final points24h = health.removeDuplicates(
    await health.getHealthDataFromTypes(
      startTime: since24h,
      endTime: now,
      types: permStatus.grantedTypes,
    ),
  );

  final stepsGranted = permStatus.grantedTypes.contains(HealthDataType.STEPS);
  int? aggregateStepsToday;
  if (stepsGranted) {
    try {
      aggregateStepsToday = await health.getTotalStepsInInterval(
        startOfToday,
        now,
      );
    } catch (_) {}
  }

  var selection = _resolveSourceSelection(
    points24h,
    fallbackSource: source,
    preferredSourceKey: preferredSourceKey,
  );
  var allowAggregate =
      !selection.filteredByApp || selection.contributingSourceKeys.length <= 1;
  var summary = _summarizeHealthPoints(
    points: selection.points,
    windowStart: startOfToday,
    aggregateSteps: aggregateStepsToday,
    allowAggregateSteps: allowAggregate,
    filterStepsCaloriesToWindow: true,
  );
  var syncWindow = 'last_24h';
  var sampleTimestamp = now;

  // Fallback 1: check earlier-within-24h points (e.g., yesterday evening before midnight)
  if (!summary.hasAnyMetric && selection.points.isNotEmpty) {
    final prevDaySummary = _summarizeHealthPoints(
      points: selection.points,
      windowStart: since24h,
      aggregateSteps: aggregateStepsToday,
      allowAggregateSteps: allowAggregate,
      filterStepsCaloriesToWindow: false,
    );
    if (prevDaySummary.hasAnyMetric) {
      summary = prevDaySummary;
      syncWindow = 'last_24h_previous_day';
      sampleTimestamp = prevDaySummary.latestPointTimestamp ?? now;
    }
  }

  // Fallback 2: widen lookback to the last 29 days (safe within Health Connect's 30-day window)
  if (!summary.hasAnyMetric) {
    final since29d = now.subtract(const Duration(days: 29));
    var points29d = health.removeDuplicates(
      await health.getHealthDataFromTypes(
        startTime: since29d,
        endTime: now,
        types: permStatus.grantedTypes,
      ),
    );

    if (points29d.isEmpty && isAndroid) {
      try {
        final workoutAllowed =
            await health.hasPermissions(
              const [HealthDataType.WORKOUT],
              permissions: const [HealthDataAccess.READ],
            ) ??
            false;
        if (workoutAllowed) {
          points29d = health.removeDuplicates(
            await health.getHealthDataFromTypes(
              startTime: since29d,
              endTime: now,
              types: const [HealthDataType.WORKOUT],
            ),
          );
        }
      } catch (_) {}
    }

    if (points29d.isNotEmpty) {
      selection = _resolveSourceSelection(
        points29d,
        fallbackSource: source,
        preferredSourceKey: preferredSourceKey,
      );
      allowAggregate =
          !selection.filteredByApp ||
          selection.contributingSourceKeys.length <= 1;

      DateTime? latestPointEnd;
      for (final point in selection.points) {
        final endLocal = point.dateTo.toLocal();
        if (latestPointEnd == null || endLocal.isAfter(latestPointEnd)) {
          latestPointEnd = endLocal;
        }
      }
      if (latestPointEnd != null) {
        final dayStart = DateTime(
          latestPointEnd.year,
          latestPointEnd.month,
          latestPointEnd.day,
        );
        final dayEnd = dayStart.add(const Duration(days: 1));
        int? dayAggSteps;
        if (stepsGranted && allowAggregate) {
          try {
            dayAggSteps = await health.getTotalStepsInInterval(
              dayStart,
              dayEnd.isAfter(now) ? now : dayEnd,
            );
          } catch (_) {}
        }
        final daySleepStart = dayStart.subtract(const Duration(hours: 12));
        final dayPoints = selection.points.where((point) {
          final endLocal = point.dateTo.toLocal();
          final isSleep =
              point.type == HealthDataType.SLEEP_ASLEEP ||
              point.type == HealthDataType.SLEEP_DEEP ||
              point.type == HealthDataType.SLEEP_LIGHT ||
              point.type == HealthDataType.SLEEP_REM ||
              point.type == HealthDataType.SLEEP_SESSION;
          final lowerBound = isSleep ? daySleepStart : dayStart;
          return !endLocal.isBefore(lowerBound) && !endLocal.isAfter(dayEnd);
        }).toList();

        final fallbackSummary = _summarizeHealthPoints(
          points: dayPoints,
          windowStart: dayStart,
          windowEnd: dayEnd,
          aggregateSteps: dayAggSteps,
          allowAggregateSteps: allowAggregate,
          filterStepsCaloriesToWindow: true,
        );
        if (fallbackSummary.hasAnyMetric) {
          summary = fallbackSummary;
          syncWindow = 'latest_within_29d';
          sampleTimestamp = fallbackSummary.latestPointTimestamp ?? latestPointEnd;
        }
      }
    }
  }

  if (!summary.hasAnyMetric) {
    Map<String, dynamic>? diagnostics;
    if (isAndroid && diagnosticsProvider != null) {
      try {
        diagnostics = await diagnosticsProvider();
      } catch (_) {}
    }
    return WearableSourceReadResult.failure(
      source: source,
      message: isAndroid
          ? buildHealthConnectDiagnosticMessage(
              targetName: targetName,
              missingCoreLabels: permStatus.missingCoreLabels,
              nativeDiagnostics: diagnostics,
              fallbackMessage: unavailableMessage,
            )
          : unavailableMessage,
    );
  }

  return WearableSourceReadResult.success(
    WearableSample(
      patientId: patientId,
      heartRate: summary.averageHeartRate > 0
          ? summary.averageHeartRate.toDouble()
          : null,
      steps: summary.steps > 0 ? summary.steps.toDouble() : null,
      calories: summary.effectiveCalories > 0
          ? summary.effectiveCalories.roundToDouble()
          : null,
      sleep: summary.sleepHours > 0
          ? double.parse(summary.sleepHours.toStringAsFixed(2))
          : null,
      timestamp: sampleTimestamp,
      source: selection.resolvedSource,
      sourceMetadata: {
        'contributing_apps': selection.contributingLabels,
        'detected_sources': selection.contributingSourceKeys,
        'sync_window': syncWindow,
        'steps_method':
            summary.useAggregateSteps ? 'os_aggregate_today' : 'filtered_today_points',
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
