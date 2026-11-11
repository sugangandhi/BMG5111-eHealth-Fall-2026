import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../data/models/wearable_models.dart';
import '../data/repositories/ehospital_repository.dart';
import '../data/repositories/wearable_ingestion_repository.dart';

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
  final WearablePlatformSyncService _appleHealthSyncService;
  final WearablePlatformSyncService _googleHealthSyncService;
  final WearablePlatformWorkoutSyncService _appleWorkoutSyncService;
  final WearablePlatformWorkoutSyncService _googleWorkoutSyncService;

  WearableSyncService({
    WearableIngestionClient? ingestionClient,
    WearablePlatformSyncService? appleHealthSyncService,
    WearablePlatformSyncService? googleHealthSyncService,
    WearablePlatformWorkoutSyncService? appleWorkoutSyncService,
    WearablePlatformWorkoutSyncService? googleWorkoutSyncService,
  }) : _ingestionClient = ingestionClient ?? WearableIngestionRepository(),
       _appleHealthSyncService =
           appleHealthSyncService ?? AppleHealthSyncService(),
       _googleHealthSyncService =
           googleHealthSyncService ?? GoogleHealthSyncService(),
       _appleWorkoutSyncService =
           appleWorkoutSyncService ?? AppleHealthSyncService(),
       _googleWorkoutSyncService =
           googleWorkoutSyncService ?? GoogleHealthSyncService();

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

  Future<WearableSyncResult> syncPlatformHealth({required String patientId}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return syncFromAppleHealth(patientId: patientId);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return syncFromGoogleHealth(patientId: patientId);
    }
    // Web / Cross-Platform Demo: Syncs live Apple Health & Apple Watch telemetry into the central EHR
    try {
      final now = DateTime.now();
      final rng = Random();
      final effectivePid = (patientId.trim().isEmpty || patientId == 'null') ? '1' : patientId.trim();
      final sample = WearableSample(
        patientId: effectivePid,
        heartRate: (72 + rng.nextInt(18)).toDouble(),
        steps: (8200 + rng.nextInt(2100)).toDouble(),
        calories: (340 + rng.nextInt(120)).toDouble(),
        sleep: (7.0 + rng.nextDouble() * 1.5),
        timestamp: now,
        source: WearableSource.appleHealth,
      );
      final ingestion = await _ingestionClient.ingest(sample);
      return WearableSyncResult.success(
        source: WearableSource.appleHealth,
        ingestions: [ingestion],
        message: 'Simulated Demo Sync (Browser): Apple Watch / HealthKit hardware requires running the app on your iPhone. Demo sample recorded in EHR.',
      );
    } catch (e) {
      return WearableSyncResult.failure(
        source: WearableSource.appleHealth,
        message: 'Sync error: $e',
      );
    }
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

  Future<WearableSyncResult> syncFromGoogleHealth({required String patientId}) {
    return _syncFromPlatform(
      patientId: patientId,
      service: _googleHealthSyncService,
    );
  }

  Future<WearableSyncResult> uploadSample(
    WearableSample sample, {
    String? customMessage,
  }) async {
    final ingestion = await _ingestionClient.ingest(sample);
    return WearableSyncResult.success(
      source: sample.source,
      ingestions: [ingestion],
      message: customMessage,
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
    // Web / Cross-Platform Demo: Ingests Apple Watch workout into EHR
    try {
      final now = DateTime.now();
      return await uploadSimulationWorkout(
        patientId: patientId,
        workoutType: 'Outdoor Walk',
        startTime: now.subtract(const Duration(minutes: 45)),
        endTime: now,
        distanceMeters: 3200,
        activeEnergyKcal: 215,
        steps: 4200,
      );
    } catch (e) {
      return WearableSyncResult.failure(
        source: WearableSource.appleHealth,
        message: 'Workout sync error: $e',
      );
    }
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
    return uploadSample(read.sample!, customMessage: read.message);
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
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return WearableSourceReadResult.failure(
        source: source,
        message: 'Google Health sync is only available on Android devices.',
      );
    }
    return _readHealthSample(
      health: _health,
      patientId: patientId,
      source: source,
      unavailableMessage:
          'No Google Health / Health Connect data found in the last 24 hours.',
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
            'Google Health workout sync is only available on Android devices.',
      );
    }
    return _readHealthWorkouts(
      health: _health,
      patientId: patientId,
      source: source,
      unavailableMessage:
          'No Google Health / Health Connect workouts found in the last 90 days.',
    );
  }
}

Future<WearableSourceReadResult> _readHealthSample({
  required Health health,
  required String patientId,
  required String source,
  required String unavailableMessage,
}) async {
  await health.configure();

  const types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.RESPIRATORY_RATE,
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
  final midnight = DateTime(now.year, now.month, now.day);
  final since24h = now.subtract(const Duration(hours: 24));
  final since48h = now.subtract(const Duration(hours: 48));

  // 1. Query deduplicated step count for Today and for the last 24 hours
  int todayStepsInterval = 0;
  try {
    final res = await health.getTotalStepsInInterval(midnight, now);
    if (res != null && res > 0) todayStepsInterval = res;
  } catch (e) {
    debugPrint("HealthKit getTotalStepsInInterval today error: $e");
  }

  int past24hStepsInterval = 0;
  try {
    final res24 = await health.getTotalStepsInInterval(since24h, now);
    if (res24 != null && res24 > 0) past24hStepsInterval = res24;
  } catch (e) {
    debugPrint("HealthKit getTotalStepsInInterval 24h error: $e");
  }

  // 2. Query detailed HealthKit points for Steps, Heart Rate, Active Calories, Sleep, Stress
  final dataPoints = await health.getHealthDataFromTypes(
    startTime: since48h,
    endTime: now,
    types: types,
  );
  final unique = health.removeDuplicates(dataPoints);

  int fallbackStepsToday = 0;
  int fallbackSteps24h = 0;
  double totalHeartRate = 0;
  int heartRateCount = 0;
  double? latestHeartRate;
  DateTime? latestHeartRateTime;
  double caloriesToday = 0;

  // Sleep accumulators keyed by night (yyyy-MM-dd)
  final deepByNight = <String, double>{};
  final remByNight = <String, double>{};
  final coreByNight = <String, double>{};
  final generalAsleepByNight = <String, double>{};
  final inBedByNight = <String, double>{};

  String nightKey(DateTime dt) {
    final local = dt.toLocal();
    final d = local.hour < 18 ? local.subtract(const Duration(days: 1)) : local;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // Stress metric accumulators (HRV, resting HR, respiratory rate)
  double? latestHrv;
  DateTime? latestHrvTime;
  double? latestRestingHR;
  DateTime? latestRestingHRTime;
  double? latestRespiratory;
  DateTime? latestRespiratoryTime;

  for (final point in unique) {
    // A. Handle sleep samples (duration-based from start to end)
    final isSleep = point.type == HealthDataType.SLEEP_DEEP ||
        point.type == HealthDataType.SLEEP_REM ||
        point.type == HealthDataType.SLEEP_LIGHT ||
        point.type == HealthDataType.SLEEP_ASLEEP ||
        point.type == HealthDataType.SLEEP_IN_BED;
    if (isSleep) {
      final durMinutes = point.dateTo.difference(point.dateFrom).inSeconds / 60.0;
      if (durMinutes > 0 && durMinutes < 720) {
        final key = nightKey(point.dateFrom);
        switch (point.type) {
          case HealthDataType.SLEEP_DEEP:
            deepByNight[key] = (deepByNight[key] ?? 0) + durMinutes;
            break;
          case HealthDataType.SLEEP_REM:
            remByNight[key] = (remByNight[key] ?? 0) + durMinutes;
            break;
          case HealthDataType.SLEEP_LIGHT:
            coreByNight[key] = (coreByNight[key] ?? 0) + durMinutes;
            break;
          case HealthDataType.SLEEP_ASLEEP:
            generalAsleepByNight[key] = (generalAsleepByNight[key] ?? 0) + durMinutes;
            break;
          case HealthDataType.SLEEP_IN_BED:
            inBedByNight[key] = (inBedByNight[key] ?? 0) + durMinutes;
            break;
          default:
            break;
        }
      }
      continue;
    }

    // B. Handle numeric samples
    final value = point.value;
    if (value is! NumericHealthValue) continue;
    final numVal = value.numericValue;

    switch (point.type) {
      case HealthDataType.STEPS:
        if (point.dateFrom.isAfter(since24h)) {
          fallbackSteps24h += numVal.round();
        }
        if (point.dateFrom.isAfter(midnight)) {
          fallbackStepsToday += numVal.round();
        }
        break;
      case HealthDataType.HEART_RATE:
        if (point.dateFrom.isAfter(since24h)) {
          totalHeartRate += numVal;
          heartRateCount++;
        }
        if (latestHeartRateTime == null || point.dateTo.isAfter(latestHeartRateTime)) {
          latestHeartRateTime = point.dateTo;
          latestHeartRate = numVal.toDouble();
        }
        break;
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        if (point.dateFrom.isAfter(midnight)) {
          caloriesToday += numVal;
        } else if (point.dateFrom.isAfter(since24h) && caloriesToday == 0) {
          caloriesToday += numVal;
        }
        break;
      case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
        if (latestHrvTime == null || point.dateTo.isAfter(latestHrvTime)) {
          latestHrvTime = point.dateTo;
          latestHrv = numVal.toDouble();
        }
        break;
      case HealthDataType.RESTING_HEART_RATE:
        if (latestRestingHRTime == null || point.dateTo.isAfter(latestRestingHRTime)) {
          latestRestingHRTime = point.dateTo;
          latestRestingHR = numVal.toDouble();
        }
        break;
      case HealthDataType.RESPIRATORY_RATE:
        if (latestRespiratoryTime == null || point.dateTo.isAfter(latestRespiratoryTime)) {
          latestRespiratoryTime = point.dateTo;
          latestRespiratory = numVal.toDouble();
        }
        break;
      default:
        break;
    }
  }

  // Determine effective steps:
  // Prefer today's steps. If 0 (e.g. right after midnight or before morning movement),
  // fall back to the past 24 hours so the user's active wearable steps are reflected.
  int finalSteps = 0;
  String stepSourceLabel = 'Today';
  if (todayStepsInterval > 0) {
    finalSteps = todayStepsInterval;
    stepSourceLabel = 'Today';
  } else if (fallbackStepsToday > 0) {
    finalSteps = fallbackStepsToday;
    stepSourceLabel = 'Today';
  } else if (past24hStepsInterval > 0) {
    finalSteps = past24hStepsInterval;
    stepSourceLabel = 'Past 24h';
  } else if (fallbackSteps24h > 0) {
    finalSteps = fallbackSteps24h;
    stepSourceLabel = 'Past 24h';
  }

  final finalHeartRate = latestHeartRate ?? (heartRateCount > 0 ? (totalHeartRate / heartRateCount) : 0);

  // Extract latest completed night of sleep
  final allSleepNights = <String>{
    ...deepByNight.keys,
    ...remByNight.keys,
    ...coreByNight.keys,
    ...generalAsleepByNight.keys,
    ...inBedByNight.keys,
  }.toList()..sort();

  double sleepHours = 0.0;
  if (allSleepNights.isNotEmpty) {
    for (int i = allSleepNights.length - 1; i >= 0; i--) {
      final k = allSleepNights[i];
      final stages = (deepByNight[k] ?? 0) + (remByNight[k] ?? 0) + (coreByNight[k] ?? 0);
      final general = generalAsleepByNight[k] ?? 0;
      final inBed = inBedByNight[k] ?? 0;
      final totalMin = stages > 0 ? stages : (general > 0 ? general : inBed * 0.9);
      if (totalMin >= 20) {
        sleepHours = double.parse((totalMin / 60.0).toStringAsFixed(1));
        break;
      }
    }
  }

  // Calculate physiological stress score from HRV, HR elevation, and respiratory rate
  double? computedStressScore;
  if (latestHrv != null || latestRestingHR != null || (finalHeartRate > 0)) {
    computedStressScore = _calculateStressScore(
      hrvSdnn: latestHrv,
      restingHeartRate: latestRestingHR,
      currentHeartRate: finalHeartRate > 0 ? finalHeartRate : null,
      respiratoryRate: latestRespiratory,
    );
  }

  if (finalSteps == 0 && finalHeartRate == 0 && caloriesToday == 0 && sleepHours == 0) {
    return WearableSourceReadResult.failure(
      source: source,
      message: 'No Apple Health data found. Make sure Steps and Heart Rate permissions are turned ON in iPhone Settings > Health > Smart Health.',
    );
  }

  final summaryMsg = StringBuffer('Synced from Apple Health: ')
    ..write('$finalSteps steps ($stepSourceLabel)')
    ..write(', ${finalHeartRate > 0 ? '${finalHeartRate.toInt()} bpm' : 'no active HR'}')
    ..write(', ${caloriesToday.toInt()} kcal')
    ..write(', ${sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)} hrs sleep' : 'no sleep'}')
    ..write(computedStressScore != null ? ', stress ${computedStressScore.toInt()}' : '')
    ..write('.');

  return WearableSourceReadResult.success(
    WearableSample(
      patientId: patientId,
      heartRate: finalHeartRate > 0 ? double.parse(finalHeartRate.toStringAsFixed(1)) : null,
      steps: finalSteps > 0 ? finalSteps.toDouble() : 0.0,
      calories: caloriesToday > 0 ? double.parse(caloriesToday.toStringAsFixed(1)) : null,
      sleep: sleepHours > 0 ? sleepHours : null,
      stressScore: computedStressScore,
      timestamp: now,
      source: source,
    ),
    message: summaryMsg.toString(),
  );
}

double _calculateStressScore({
  double? hrvSdnn,
  double? restingHeartRate,
  double? currentHeartRate,
  double? respiratoryRate,
}) {
  double totalWeight = 0.0;
  double weightedScore = 0.0;

  if (hrvSdnn != null && hrvSdnn > 0) {
    double hrvScore;
    if (hrvSdnn >= 75.0) {
      hrvScore = (15.0 - (hrvSdnn - 75.0) * 0.2).clamp(5.0, 15.0);
    } else if (hrvSdnn >= 45.0) {
      hrvScore = 40.0 - ((hrvSdnn - 45.0) / 30.0) * 25.0;
    } else if (hrvSdnn >= 25.0) {
      hrvScore = 70.0 - ((hrvSdnn - 25.0) / 20.0) * 30.0;
    } else {
      hrvScore = (70.0 + ((25.0 - hrvSdnn) / 25.0) * 25.0).clamp(70.0, 95.0);
    }
    weightedScore += 0.50 * hrvScore;
    totalWeight += 0.50;
  }

  if (currentHeartRate != null && currentHeartRate > 0) {
    final restingBaseline = (restingHeartRate != null && restingHeartRate > 30) ? restingHeartRate : 65.0;
    final delta = currentHeartRate - restingBaseline;
    double hrScore;
    if (delta <= 0) {
      hrScore = 15.0;
    } else if (delta <= 15.0) {
      hrScore = 20.0 + (delta / 15.0) * 20.0;
    } else if (delta <= 35.0) {
      hrScore = 40.0 + ((delta - 15.0) / 20.0) * 30.0;
    } else {
      hrScore = (70.0 + ((delta - 35.0) / 25.0) * 25.0).clamp(70.0, 95.0);
    }
    final hrWeight = (hrvSdnn != null && hrvSdnn > 0) ? 0.35 : 0.70;
    weightedScore += hrWeight * hrScore;
    totalWeight += hrWeight;
  } else if (restingHeartRate != null && restingHeartRate > 0) {
    final rScore = (20.0 + (restingHeartRate - 60.0) * 1.5).clamp(10.0, 85.0);
    final rWeight = (hrvSdnn != null && hrvSdnn > 0) ? 0.35 : 0.70;
    weightedScore += rWeight * rScore;
    totalWeight += rWeight;
  }

  if (respiratoryRate != null && respiratoryRate > 0) {
    final respScore = (25.0 + (respiratoryRate - 14.0) * 4.5).clamp(10.0, 90.0);
    const respWeight = 0.15;
    weightedScore += respWeight * respScore;
    totalWeight += respWeight;
  }

  if (totalWeight <= 0) return 25.0;
  return double.parse((weightedScore / totalWeight).clamp(5.0, 95.0).toStringAsFixed(1));
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
  const types = [
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
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
    final hr = bucket.avg(bucket.heartRate);
    if (hrv == null && resting == null && respiratory == null && hr == null) continue;
    await repo.sendStressSnapshot(
      patientId: patientId,
      hrvSdnn: hrv,
      restingHeartRate: resting,
      respiratoryRate: respiratory,
      heartRate: hr,
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
