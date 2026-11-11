import 'dart:math' as math;

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
      final isMidnightReset = syncWindow == 'today_midnight_reset';
      final dayStr = s.timestamp.toLocal().toIso8601String().split('T').first;
      final stepsLabel = isFallbackWindow ? 'steps' : 'today steps';
      final calMethod = s.sourceMetadata['calories_method']?.toString();
      final calLabel =
          (calMethod == 'os_aggregate_total' || calMethod == 'deduped_total')
          ? 'kcal total (incl. resting)'
          : (calMethod == 'os_aggregate_active' || calMethod == 'deduped_active')
          ? 'kcal active'
          : 'kcal';
      final details = <String>[
        if (s.steps != null) '${s.steps!.round()} $stepsLabel',
        if (s.heartRate != null) '${s.heartRate!.round()} bpm HR',
        if (s.calories != null) '${s.calories!.round()} $calLabel',
        if (s.sleep != null) '${s.sleep!.toStringAsFixed(1)}h sleep',
      ].join(', ');
      final yesterdaySteps = s.sourceMetadata['yesterday_steps'];
      final stepsByOrigin = s.sourceMetadata['steps_by_origin'];
      final originLabels = s.sourceMetadata['origin_labels'];
      String originNote = '';
      if (stepsByOrigin is Map && stepsByOrigin.isNotEmpty) {
        final parts = <String>[];
        var differsFromSource = stepsByOrigin.length > 1;
        for (final entry in stepsByOrigin.entries) {
          final pkg = entry.key.toString();
          final rawLabel = originLabels is Map ? originLabels[pkg] : null;
          final originLabel =
              rawLabel?.toString() ??
              WearableSource.labelFor(WearableSource.fromSourceIdentifier(pkg));
          if (originLabel.toLowerCase() != label.toLowerCase()) {
            differsFromSource = true;
          }
          parts.add('$originLabel ${entry.value}');
        }
        if (differsFromSource) {
          originNote = ' [HC steps: ${parts.join(', ')}]';
        }
      }
      final preMidnightFiltered = s.sourceMetadata['pre_midnight_filtered_steps'];
      final preMidnightNote =
          preMidnightFiltered is num && preMidnightFiltered > 0
          ? ' (excluded ${preMidnightFiltered.round()} pre-midnight steps)'
          : '';
      final dateSuffix = isMidnightReset && yesterdaySteps != null
          ? ' (midnight reset; yesterday: $yesterdaySteps steps)'
          : isFallbackWindow
              ? ' (latest recorded $dayStr)'
              : '';
      return WearableSyncResult.success(
        source: s.source,
        ingestions: [ingestion],
        message:
            'Synced $label telemetry$via ($details)$dateSuffix$preMidnightNote$originNote into EHR.',
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

typedef HealthConnectAggregateProvider =
    Future<Map<String, dynamic>?> Function(
      DateTime startTime,
      DateTime endTime,
      List<String> packageNames,
    );

class GoogleHealthSyncService
    implements WearablePlatformSyncService, WearablePlatformWorkoutSyncService {
  final Health _health;
  final Future<Map<String, dynamic>?> Function()? _diagnosticsProvider;
  final HealthConnectAggregateProvider? _aggregateMetricsProvider;
  final bool? _isWebOverride;
  final TargetPlatform? _platformOverride;

  GoogleHealthSyncService({
    Health? health,
    Future<Map<String, dynamic>?> Function()? diagnosticsProvider,
    HealthConnectAggregateProvider? aggregateMetricsProvider,
    bool? isWebOverride,
    TargetPlatform? platformOverride,
  }) : _health = health ?? Health(),
       _diagnosticsProvider = diagnosticsProvider,
       _aggregateMetricsProvider = aggregateMetricsProvider,
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
      aggregateMetricsProvider:
          _aggregateMetricsProvider ??
          (start, end, packageNames) => MobileHealthRegistryService(
                isWebOverride: _isWebOverride,
                platformOverride: _platformOverride,
                health: _health,
              ).aggregateHealthMetrics(
                startTime: start,
                endTime: end,
                packageNames: packageNames,
              ),
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

const Map<String, List<String>> _knownPackagesBySource = <String, List<String>>{
  WearableSource.samsungHealth: ['com.sec.android.app.shealth'],
  WearableSource.googleHealth: ['com.google.android.apps.fitness'],
  WearableSource.fitbit: ['com.fitbit.FitbitMobile'],
  WearableSource.garmin: ['com.garmin.android.apps.connectmobile'],
  WearableSource.strava: ['com.strava'],
  WearableSource.oura: ['com.ouraring.oura'],
  WearableSource.whoop: ['com.whoop.android'],
};

bool _isAppSpecificSource(String? sourceKey) {
  return sourceKey != null &&
      sourceKey != WearableSource.healthConnect &&
      sourceKey != WearableSource.appleHealth;
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

  // Always enforce the app filter when an explicit app source (e.g. Samsung Health)
  // was requested, even if it has 0 points so other apps' data never leaks in.
  final filteredByApp = _isAppSpecificSource(preferredSourceKey);
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
  if (filteredByApp) {
    resolvedSource = preferredSourceKey!;
  } else if (preferredSourceKey != null &&
      contributingSourceKeys.contains(preferredSourceKey)) {
    resolvedSource = preferredSourceKey;
  } else if (sourcePointCounts.isNotEmpty) {
    final sorted = sourcePointCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    resolvedSource = sorted.first.key;
  }

  return _SourceSelection(
    points: selectedPoints,
    contributingLabels: filteredByApp
        ? <String>[WearableSource.labelFor(preferredSourceKey!)]
        : contributingLabels.toList(),
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
  final String caloriesMethod;
  final DateTime? latestPointTimestamp;

  const _MetricsSummary({
    required this.steps,
    required this.averageHeartRate,
    required this.effectiveCalories,
    required this.sleepHours,
    required this.useAggregateSteps,
    required this.caloriesMethod,
    this.latestPointTimestamp,
  });

  bool get hasAnyMetric =>
      steps > 0 ||
      averageHeartRate > 0 ||
      effectiveCalories > 0 ||
      sleepHours > 0;
}

class _AdditiveInterval {
  final String streamKey;
  final int startMs;
  final int endMs;
  final double value;

  const _AdditiveInterval({
    required this.streamKey,
    required this.startMs,
    required this.endMs,
    required this.value,
  });
}

class _OsAggregateSnapshot {
  final int? steps;
  final int? strictSteps;
  final double? activeCalories;
  final double? totalCalories;
  final bool usedNativeAggregate;
  final int crossMidnightRecords;
  final int longCrossMidnightRecords;
  final int strictStepRecords;
  final int preMidnightFilteredSteps;
  final Map<String, int> stepsByOrigin;
  final Map<String, String> originLabels;
  final List<String> stepRecordSamples;

  const _OsAggregateSnapshot({
    this.steps,
    this.strictSteps,
    this.activeCalories,
    this.totalCalories,
    this.usedNativeAggregate = false,
    this.crossMidnightRecords = 0,
    this.longCrossMidnightRecords = 0,
    this.strictStepRecords = 0,
    this.preMidnightFilteredSteps = 0,
    this.stepsByOrigin = const <String, int>{},
    this.originLabels = const <String, String>{},
    this.stepRecordSamples = const <String>[],
  });
}

List<String> _extractFilterPackageNames(
  _SourceSelection selection,
  String? preferredSourceKey,
) {
  if (!_isAppSpecificSource(preferredSourceKey)) {
    return const <String>[];
  }
  final packages = <String>{};
  for (final point in selection.points) {
    for (final raw in [point.sourceName, point.sourceId]) {
      final candidate = raw.trim();
      if (candidate.contains('.') && !candidate.contains(' ')) {
        packages.add(candidate);
      }
    }
  }
  final known = _knownPackagesBySource[preferredSourceKey!];
  if (known != null) {
    packages.addAll(known);
  }
  return packages.toList();
}

double _maxNonOverlappingStreamSum(List<_AdditiveInterval> intervals) {
  if (intervals.isEmpty) return 0.0;
  final sorted = List<_AdditiveInterval>.from(intervals)
    ..sort((a, b) {
      final cmp = a.endMs.compareTo(b.endMs);
      return cmp != 0 ? cmp : a.startMs.compareTo(b.startMs);
    });
  final dp = List<double>.filled(sorted.length, 0.0);
  for (var i = 0; i < sorted.length; i++) {
    final cur = sorted[i];
    var lo = 0;
    var hi = i - 1;
    var prev = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (sorted[mid].endMs <= cur.startMs) {
        prev = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    final take = cur.value + (prev >= 0 ? dp[prev] : 0.0);
    final skip = i > 0 ? dp[i - 1] : 0.0;
    dp[i] = math.max(take, skip);
  }
  return dp[sorted.length - 1];
}

double _sumDeduplicatedAdditivePoints(
  List<HealthDataPoint> points, {
  DateTime? clipStart,
  DateTime? clipEnd,
}) {
  if (points.isEmpty) return 0.0;
  final seen = <String>{};
  final timed = <_AdditiveInterval>[];
  final instantByTs = <int, double>{};
  final clipStartMs = clipStart?.millisecondsSinceEpoch;
  final clipEndMs = clipEnd?.millisecondsSinceEpoch;

  for (final p in points) {
    final v = p.value;
    if (v is! NumericHealthValue) continue;
    var val = v.numericValue.toDouble();
    if (val <= 0) continue;

    final origStartMs = p.dateFrom.millisecondsSinceEpoch;
    final origEndMs = p.dateTo.millisecondsSinceEpoch;
    final streamKey = '${p.sourceDeviceId}|${p.sourceId}|${p.sourceName}';
    final dedupKey = '$streamKey|$origStartMs|$origEndMs|$val';
    if (!seen.add(dedupKey)) continue;

    if (origEndMs > origStartMs) {
      var startMs = origStartMs;
      var endMs = origEndMs;
      if (clipStartMs != null && startMs < clipStartMs) startMs = clipStartMs;
      if (clipEndMs != null && endMs > clipEndMs) endMs = clipEndMs;
      if (endMs <= startMs) continue;
      final origDuration = origEndMs - origStartMs;
      final clippedDuration = endMs - startMs;
      if (clippedDuration < origDuration) {
        val = val * (clippedDuration / origDuration);
      }
      timed.add(
        _AdditiveInterval(
          streamKey: streamKey,
          startMs: startMs,
          endMs: endMs,
          value: val,
        ),
      );
    } else {
      final existing = instantByTs[origEndMs];
      if (existing == null || val > existing) {
        instantByTs[origEndMs] = val;
      }
    }
  }

  var total = instantByTs.values.fold<double>(0.0, (a, b) => a + b);
  if (timed.isEmpty) return total;

  timed.sort((a, b) {
    final cmp = a.startMs.compareTo(b.startMs);
    return cmp != 0 ? cmp : a.endMs.compareTo(b.endMs);
  });

  var comp = <_AdditiveInterval>[timed.first];
  var compMaxEnd = timed.first.endMs;

  double flushComponent(List<_AdditiveInterval> items) {
    final byStream = <String, List<_AdditiveInterval>>{};
    for (final item in items) {
      byStream.putIfAbsent(item.streamKey, () => []).add(item);
    }
    var best = 0.0;
    for (final streamItems in byStream.values) {
      best = math.max(best, _maxNonOverlappingStreamSum(streamItems));
    }
    return best;
  }

  for (var i = 1; i < timed.length; i++) {
    final item = timed[i];
    if (item.startMs < compMaxEnd) {
      comp.add(item);
      if (item.endMs > compMaxEnd) compMaxEnd = item.endMs;
    } else {
      total += flushComponent(comp);
      comp = [item];
      compMaxEnd = item.endMs;
    }
  }
  total += flushComponent(comp);
  return total;
}

_MetricsSummary _summarizeHealthPoints({
  required List<HealthDataPoint> points,
  required DateTime windowStart,
  DateTime? windowEnd,
  required _OsAggregateSnapshot osAggregate,
  required bool allowTotalCaloriesFallback,
  required bool filterStepsCaloriesToWindow,
}) {
  final windowStepPoints = <HealthDataPoint>[];
  final windowActiveCalPoints = <HealthDataPoint>[];
  final windowTotalCalPoints = <HealthDataPoint>[];
  var workoutSteps = 0;
  var totalHeartRate = 0.0;
  var heartRateCount = 0;
  var restingHeartRateTotal = 0.0;
  var restingHeartRateCount = 0;
  var workoutCalories = 0.0;
  var sleepAsleepMinutes = 0.0;
  var sleepStageMinutes = 0.0;
  var sleepSessionMinutes = 0.0;
  DateTime? latestTs;

  for (final point in points) {
    final startLocal = point.dateFrom.toLocal();
    final endLocal = point.dateTo.toLocal();
    final isInterval = endLocal.isAfter(startLocal);
    if (latestTs == null || endLocal.isAfter(latestTs)) {
      latestTs = endLocal;
    }

    final inStepCalorieWindow =
        !filterStepsCaloriesToWindow ||
        (isInterval
            ? (endLocal.isAfter(windowStart) &&
                (windowEnd == null || startLocal.isBefore(windowEnd)))
            : (!endLocal.isBefore(windowStart) &&
                (windowEnd == null || !endLocal.isAfter(windowEnd))));

    final value = point.value;
    final numVal = value is NumericHealthValue ? value.numericValue.toDouble() : null;
    switch (point.type) {
      case HealthDataType.STEPS:
        if (inStepCalorieWindow) windowStepPoints.add(point);
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
        if (inStepCalorieWindow) windowActiveCalPoints.add(point);
        break;
      case HealthDataType.TOTAL_CALORIES_BURNED:
        if (inStepCalorieWindow) windowTotalCalPoints.add(point);
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

  final clipStart = filterStepsCaloriesToWindow ? windowStart : null;
  final clipEnd = filterStepsCaloriesToWindow ? windowEnd : null;
  final dedupedSteps = _sumDeduplicatedAdditivePoints(
    windowStepPoints,
    clipStart: clipStart,
    clipEnd: clipEnd,
  ).round();
  final dedupedActiveCal = _sumDeduplicatedAdditivePoints(
    windowActiveCalPoints,
    clipStart: clipStart,
    clipEnd: clipEnd,
  );
  final dedupedTotalCal = _sumDeduplicatedAdditivePoints(
    windowTotalCalPoints,
    clipStart: clipStart,
    clipEnd: clipEnd,
  );

  final osSteps = osAggregate.steps;
  // When Android native Health Connect aggregate runs, trust 0 as authoritative so
  // midnight resets don't bleed raw boundary records back in.
  final useAggregateSteps = osAggregate.usedNativeAggregate
      ? osSteps != null
      : (osSteps != null && osSteps > 0);
  final resolvedSteps = useAggregateSteps
      ? osSteps
      : (dedupedSteps > 0 ? dedupedSteps : workoutSteps);

  final osActiveCal = osAggregate.activeCalories;
  final osTotalCal = osAggregate.totalCalories;
  final hasOsActive = osActiveCal != null && osActiveCal > 0;
  final hasOsTotal = osTotalCal != null && osTotalCal > 0;

  double effectiveCalories;
  String caloriesMethod;
  if (hasOsActive) {
    effectiveCalories = osActiveCal;
    caloriesMethod = 'os_aggregate_active';
  } else if (dedupedActiveCal > 0) {
    effectiveCalories = dedupedActiveCal;
    caloriesMethod = 'deduped_active';
  } else if (workoutCalories > 0) {
    effectiveCalories = workoutCalories;
    caloriesMethod = 'workout_total';
  } else if ((resolvedSteps > 0 || allowTotalCaloriesFallback) && hasOsTotal) {
    effectiveCalories = osTotalCal;
    caloriesMethod = 'os_aggregate_total';
  } else if ((resolvedSteps > 0 || allowTotalCaloriesFallback) && dedupedTotalCal > 0) {
    effectiveCalories = dedupedTotalCal;
    caloriesMethod = 'deduped_total';
  } else {
    effectiveCalories = 0.0;
    caloriesMethod = resolvedSteps == 0 ? 'midnight_zero' : 'none';
  }

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
    caloriesMethod: caloriesMethod,
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

Future<_OsAggregateSnapshot> _resolveOsAggregatedMetrics({
  required Health health,
  required DateTime startTime,
  required DateTime endTime,
  required bool stepsGranted,
  required _SourceSelection selection,
  required List<String> packageNames,
  required bool isAndroid,
  HealthConnectAggregateProvider? aggregateMetricsProvider,
}) async {
  int? osSteps;
  int? strictSteps;
  double? osActiveCalories;
  double? osTotalCalories;
  var usedNativeAggregate = false;
  var crossMidnightRecords = 0;
  var longCrossMidnightRecords = 0;
  var strictStepRecords = 0;
  var preMidnightFilteredSteps = 0;
  var stepsByOrigin = const <String, int>{};
  var originLabels = const <String, String>{};
  var stepRecordSamples = const <String>[];

  if (isAndroid && aggregateMetricsProvider != null) {
    try {
      final raw = await aggregateMetricsProvider(
        startTime,
        endTime,
        packageNames,
      );
      if (raw != null && raw['available'] == true) {
        usedNativeAggregate = true;
        final s = raw['steps'];
        if (s is num) osSteps = s.round();
        final ss = raw['strictSteps'];
        if (ss is num) strictSteps = ss.round();
        final a = raw['activeCalories'];
        if (a is num) osActiveCalories = a.toDouble();
        final t = raw['totalCalories'];
        if (t is num) osTotalCalories = t.toDouble();
        final cm = raw['crossMidnightRecords'];
        if (cm is num) crossMidnightRecords = cm.toInt();
        final lcm = raw['longCrossMidnightRecords'];
        if (lcm is num) longCrossMidnightRecords = lcm.toInt();
        final sr = raw['strictStepRecords'];
        if (sr is num) strictStepRecords = sr.toInt();

        final rawOrigins = raw['stepsByOrigin'];
        if (rawOrigins is Map && rawOrigins.isNotEmpty) {
          stepsByOrigin = <String, int>{
            for (final entry in rawOrigins.entries)
              if (entry.value is num)
                entry.key.toString(): (entry.value as num).round(),
          };
        }
        final rawLabels = raw['originLabels'];
        if (rawLabels is Map && rawLabels.isNotEmpty) {
          originLabels = <String, String>{
            for (final entry in rawLabels.entries)
              entry.key.toString(): entry.value.toString(),
          };
        }
        final rawSamples = raw['stepRecordSamples'];
        if (rawSamples is List && rawSamples.isNotEmpty) {
          stepRecordSamples = rawSamples.map((e) => e.toString()).toList();
        }

        // Prevent multi-hour pre-midnight step summaries (or crossing records when
        // zero records started today) from leaking yesterday's totals after midnight.
        if (osSteps != null && strictSteps != null && osSteps > strictSteps) {
          if (longCrossMidnightRecords > 0 ||
              (crossMidnightRecords > 0 && strictStepRecords == 0 && strictSteps == 0)) {
            preMidnightFilteredSteps = osSteps - strictSteps;
            osSteps = strictSteps;
          }
        }
      }
    } catch (_) {}
  }

  final allowLegacyStepsAgg =
      !usedNativeAggregate &&
      !selection.filteredByApp &&
      selection.contributingSourceKeys.length <= 1;
  if (osSteps == null && stepsGranted && allowLegacyStepsAgg) {
    try {
      osSteps = await health.getTotalStepsInInterval(startTime, endTime);
    } catch (_) {}
  }

  return _OsAggregateSnapshot(
    steps: osSteps,
    strictSteps: strictSteps,
    activeCalories: osActiveCalories,
    totalCalories: osTotalCalories,
    usedNativeAggregate: usedNativeAggregate,
    crossMidnightRecords: crossMidnightRecords,
    longCrossMidnightRecords: longCrossMidnightRecords,
    strictStepRecords: strictStepRecords,
    preMidnightFilteredSteps: preMidnightFilteredSteps,
    stepsByOrigin: stepsByOrigin,
    originLabels: originLabels,
    stepRecordSamples: stepRecordSamples,
  );
}

List<HealthDataPoint> _filterPointsToCalendarDay(
  List<HealthDataPoint> points,
  DateTime dayStart,
  DateTime dayEnd,
) {
  final daySleepStart = dayStart.subtract(const Duration(hours: 12));
  return points.where((point) {
    final startLocal = point.dateFrom.toLocal();
    final endLocal = point.dateTo.toLocal();
    final isSleep =
        point.type == HealthDataType.SLEEP_ASLEEP ||
        point.type == HealthDataType.SLEEP_DEEP ||
        point.type == HealthDataType.SLEEP_LIGHT ||
        point.type == HealthDataType.SLEEP_REM ||
        point.type == HealthDataType.SLEEP_SESSION;
    if (isSleep) {
      return !endLocal.isBefore(daySleepStart) && !endLocal.isAfter(dayEnd);
    }
    if (endLocal.isAfter(startLocal)) {
      // Strictly exclude previous-day intervals ending right at midnight (00:00:00).
      return endLocal.isAfter(dayStart) && startLocal.isBefore(dayEnd);
    }
    return endLocal.isAfter(dayStart) && !endLocal.isAfter(dayEnd);
  }).toList();
}

Future<_MetricsSummary> _summarizeCalendarWindow({
  required Health health,
  required List<HealthDataPoint> points,
  required DateTime dayStart,
  required DateTime dayEnd,
  required DateTime now,
  required bool stepsGranted,
  required _SourceSelection selection,
  required List<String> packageNames,
  required bool isAndroid,
  required bool hasActiveSupport,
  HealthConnectAggregateProvider? aggregateMetricsProvider,
}) async {
  final osAgg = await _resolveOsAggregatedMetrics(
    health: health,
    startTime: dayStart,
    endTime: dayEnd.isAfter(now) ? now : dayEnd,
    stepsGranted: stepsGranted,
    selection: selection,
    packageNames: packageNames,
    isAndroid: isAndroid,
    aggregateMetricsProvider: aggregateMetricsProvider,
  );
  final dayPoints = _filterPointsToCalendarDay(points, dayStart, dayEnd);
  return _summarizeHealthPoints(
    points: dayPoints,
    windowStart: dayStart,
    windowEnd: dayEnd,
    osAggregate: osAgg,
    allowTotalCaloriesFallback:
        !hasActiveSupport && !((osAgg.activeCalories ?? 0) > 0),
    filterStepsCaloriesToWindow: true,
  );
}

Future<WearableSourceReadResult> _readHealthSample({
  required Health health,
  required String patientId,
  required String source,
  String? preferredSourceKey,
  bool isAndroid = false,
  Future<Map<String, dynamic>?> Function()? diagnosticsProvider,
  HealthConnectAggregateProvider? aggregateMetricsProvider,
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
  var selection = _resolveSourceSelection(
    points24h,
    fallbackSource: source,
    preferredSourceKey: preferredSourceKey,
  );
  var filterPackages = _extractFilterPackageNames(
    selection,
    preferredSourceKey,
  );
  final hasActive24h = selection.points.any(
    (p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED,
  );

  final osToday = await _resolveOsAggregatedMetrics(
    health: health,
    startTime: startOfToday,
    endTime: now,
    stepsGranted: stepsGranted,
    selection: selection,
    packageNames: filterPackages,
    isAndroid: isAndroid,
    aggregateMetricsProvider: aggregateMetricsProvider,
  );
  final todaySleepAndDayPoints = _filterPointsToCalendarDay(
    selection.points,
    startOfToday,
    now,
  );
  var summary = _summarizeHealthPoints(
    points: todaySleepAndDayPoints,
    windowStart: startOfToday,
    windowEnd: now,
    osAggregate: osToday,
    allowTotalCaloriesFallback:
        !hasActive24h && !((osToday.activeCalories ?? 0) > 0),
    filterStepsCaloriesToWindow: true,
  );
  var hrSleepFromOtherOrigin = false;
  if (selection.filteredByApp &&
      (summary.averageHeartRate == 0 || summary.sleepHours == 0) &&
      points24h.isNotEmpty) {
    final allTodayPoints = _filterPointsToCalendarDay(
      points24h,
      startOfToday,
      now,
    );
    final crossOriginSummary = _summarizeHealthPoints(
      points: allTodayPoints,
      windowStart: startOfToday,
      windowEnd: now,
      osAggregate: const _OsAggregateSnapshot(),
      allowTotalCaloriesFallback: false,
      filterStepsCaloriesToWindow: true,
    );
    final mergedHr = summary.averageHeartRate > 0
        ? summary.averageHeartRate
        : crossOriginSummary.averageHeartRate;
    final mergedSleep = summary.sleepHours > 0
        ? summary.sleepHours
        : crossOriginSummary.sleepHours;
    if (mergedHr != summary.averageHeartRate ||
        mergedSleep != summary.sleepHours) {
      hrSleepFromOtherOrigin = true;
      summary = _MetricsSummary(
        steps: summary.steps,
        averageHeartRate: mergedHr,
        effectiveCalories: summary.effectiveCalories,
        sleepHours: mergedSleep,
        useAggregateSteps: summary.useAggregateSteps,
        caloriesMethod: summary.caloriesMethod,
        latestPointTimestamp: summary.latestPointTimestamp,
      );
    }
  }
  var syncWindow = 'last_24h';
  var sampleTimestamp = now;
  int? yesterdaySteps;

  // Fallback 1 / Midnight Reset: when Today is at 0 after midnight, either report
  // Today's authoritative 0 reset (on native Android Health Connect) or resolve
  // yesterday's calendar day when running without native aggregate.
  if (!summary.hasAnyMetric && selection.points.isNotEmpty) {
    DateTime? latestPrevEnd;
    for (final point in selection.points) {
      final endLocal = point.dateTo.toLocal();
      if (!endLocal.isAfter(startOfToday) &&
          (latestPrevEnd == null || endLocal.isAfter(latestPrevEnd))) {
        latestPrevEnd = endLocal;
      }
    }
    if (latestPrevEnd != null) {
      final prevDayAnchor = latestPrevEnd.subtract(const Duration(milliseconds: 1));
      final prevDayStart = DateTime(
        prevDayAnchor.year,
        prevDayAnchor.month,
        prevDayAnchor.day,
      );
      final prevDayEnd = prevDayStart.add(const Duration(days: 1));
      final prevDaySummary = await _summarizeCalendarWindow(
        health: health,
        points: selection.points,
        dayStart: prevDayStart,
        dayEnd: prevDayEnd,
        now: now,
        stepsGranted: stepsGranted,
        selection: selection,
        packageNames: filterPackages,
        isAndroid: isAndroid,
        hasActiveSupport: hasActive24h,
        aggregateMetricsProvider: aggregateMetricsProvider,
      );
      if (prevDaySummary.hasAnyMetric) {
        if (osToday.usedNativeAggregate && stepsGranted) {
          yesterdaySteps = prevDaySummary.steps;
          syncWindow = 'today_midnight_reset';
          sampleTimestamp = now;
          summary = _MetricsSummary(
            steps: osToday.steps ?? 0,
            averageHeartRate: summary.averageHeartRate,
            effectiveCalories: 0.0,
            sleepHours: summary.sleepHours,
            useAggregateSteps: true,
            caloriesMethod: 'midnight_zero',
            latestPointTimestamp: now,
          );
        } else {
          summary = prevDaySummary;
          syncWindow = 'last_24h_previous_day';
          sampleTimestamp = prevDaySummary.latestPointTimestamp ?? prevDayAnchor;
        }
      }
    }
  }

  // Fallback 2: widen lookback to the last 29 days (safe within Health Connect's 30-day window)
  if (!summary.hasAnyMetric && syncWindow != 'today_midnight_reset') {
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
      filterPackages = _extractFilterPackageNames(
        selection,
        preferredSourceKey,
      );
      final hasActive29d = selection.points.any(
        (p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED,
      );

      DateTime? latestPointEnd;
      for (final point in selection.points) {
        final endLocal = point.dateTo.toLocal();
        if (latestPointEnd == null || endLocal.isAfter(latestPointEnd)) {
          latestPointEnd = endLocal;
        }
      }
      if (latestPointEnd != null) {
        final anchor = latestPointEnd.subtract(const Duration(milliseconds: 1));
        final dayStart = DateTime(anchor.year, anchor.month, anchor.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final fallbackSummary = await _summarizeCalendarWindow(
          health: health,
          points: selection.points,
          dayStart: dayStart,
          dayEnd: dayEnd,
          now: now,
          stepsGranted: stepsGranted,
          selection: selection,
          packageNames: filterPackages,
          isAndroid: isAndroid,
          hasActiveSupport: hasActive29d,
          aggregateMetricsProvider: aggregateMetricsProvider,
        );
        if (fallbackSummary.hasAnyMetric) {
          summary = fallbackSummary;
          syncWindow = 'latest_within_29d';
          sampleTimestamp = fallbackSummary.latestPointTimestamp ?? latestPointEnd;
        }
      }
    }
  }

  if (!summary.hasAnyMetric && syncWindow != 'today_midnight_reset') {
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

  final isExplicitTodayZeroReset =
      syncWindow == 'today_midnight_reset' ||
      (syncWindow == 'last_24h' && osToday.usedNativeAggregate && stepsGranted);

  return WearableSourceReadResult.success(
    WearableSample(
      patientId: patientId,
      heartRate: summary.averageHeartRate > 0
          ? summary.averageHeartRate.toDouble()
          : null,
      steps: (summary.steps > 0 || isExplicitTodayZeroReset)
          ? summary.steps.toDouble()
          : null,
      calories: (summary.effectiveCalories > 0 || isExplicitTodayZeroReset)
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
        if (yesterdaySteps != null) 'yesterday_steps': yesterdaySteps,
        if (osToday.stepsByOrigin.isNotEmpty) 'steps_by_origin': osToday.stepsByOrigin,
        if (osToday.originLabels.isNotEmpty) 'origin_labels': osToday.originLabels,
        if (osToday.stepRecordSamples.isNotEmpty)
          'step_record_samples': osToday.stepRecordSamples,
        if (osToday.preMidnightFilteredSteps > 0)
          'pre_midnight_filtered_steps': osToday.preMidnightFilteredSteps,
        if (osToday.crossMidnightRecords > 0)
          'cross_midnight_records': osToday.crossMidnightRecords,
        if (osToday.strictSteps != null) 'strict_steps_today': osToday.strictSteps,
        if (hrSleepFromOtherOrigin) 'hr_sleep_cross_origin': true,
        'steps_method':
            summary.useAggregateSteps ? 'os_aggregate_today' : 'deduped_day_points',
        'calories_method': summary.caloriesMethod,
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
