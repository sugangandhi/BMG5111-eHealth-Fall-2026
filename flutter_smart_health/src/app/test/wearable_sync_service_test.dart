import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:smart_health_app/data/models/wearable_models.dart';
import 'package:smart_health_app/data/repositories/ehospital_repository.dart';
import 'package:smart_health_app/data/repositories/wearable_ingestion_repository.dart';
import 'package:smart_health_app/services/wearable_sync_service.dart';

void main() {
  test('manual upload routes through backend ingestion client', () async {
    final ingestion = _FakeIngestionClient();
    final service = WearableSyncService(ingestionClient: ingestion);

    final result = await service.uploadManual(
      patientId: '20',
      heartRate: 80,
      steps: 6000,
      calories: 300,
      sleep: 7,
    );

    expect(result.success, isTrue);
    expect(result.source, WearableSource.manual);
    expect(ingestion.samples.single.source, WearableSource.manual);
    expect(ingestion.samples.single.patientId, '20');
  });

  test('simulation upload routes through backend ingestion client', () async {
    final ingestion = _FakeIngestionClient();
    final service = WearableSyncService(ingestionClient: ingestion);

    final result = await service.uploadSimulationSample(
      patientId: '20',
      heartRate: 72,
      steps: 5000,
      calories: 250,
      sleep: 6,
    );

    expect(result.success, isTrue);
    expect(result.source, WearableSource.simulation);
    expect(ingestion.samples.single.source, WearableSource.simulation);
  });

  test(
    'Apple platform sync reads from AppleHealthSyncService then ingests',
    () async {
      final ingestion = _FakeIngestionClient();
      final apple = _FakePlatformSyncService(
        source: WearableSource.appleHealth,
        sample: WearableSample(
          patientId: '20',
          heartRate: 78,
          timestamp: DateTime.parse('2026-06-20T10:30:00Z'),
          source: WearableSource.appleHealth,
        ),
      );
      final service = WearableSyncService(
        ingestionClient: ingestion,
        appleHealthSyncService: apple,
      );

      final result = await service.syncFromAppleHealth(patientId: '20');

      expect(result.success, isTrue);
      expect(apple.readCount, 1);
      expect(ingestion.samples.single.source, WearableSource.appleHealth);
    },
  );

  test(
    'Google platform sync reads from GoogleHealthSyncService then ingests',
    () async {
      final ingestion = _FakeIngestionClient();
      final google = _FakePlatformSyncService(
        source: WearableSource.googleHealth,
        sample: WearableSample(
          patientId: '20',
          steps: 4000,
          timestamp: DateTime.parse('2026-06-20T10:30:00Z'),
          source: WearableSource.googleHealth,
        ),
      );
      final service = WearableSyncService(
        ingestionClient: ingestion,
        googleHealthSyncService: google,
      );

      final result = await service.syncFromGoogleHealth(patientId: '20');

      expect(result.success, isTrue);
      expect(google.readCount, 1);
      expect(ingestion.samples.single.source, WearableSource.googleHealth);
    },
  );

  test('platform source failure does not call backend ingestion', () async {
    final ingestion = _FakeIngestionClient();
    final apple = _FakePlatformSyncService.failure(
      source: WearableSource.appleHealth,
      message: 'permission denied',
    );
    final service = WearableSyncService(
      ingestionClient: ingestion,
      appleHealthSyncService: apple,
    );

    final result = await service.syncFromAppleHealth(patientId: '20');

    expect(result.success, isFalse);
    expect(result.message, 'permission denied');
    expect(ingestion.samples, isEmpty);
  });

  test(
    'fixture workout upload routes through backend ingestion client',
    () async {
      final ingestion = _FakeIngestionClient();
      final service = WearableSyncService(ingestionClient: ingestion);

      final result = await service.uploadWorkout(_testWorkout());

      expect(result.success, isTrue);
      expect(result.source, WearableSource.appleHealth);
      expect(result.uploadedCount, 1);
      expect(ingestion.workouts.single.sourceWorkoutId, 'HK-1');
    },
  );

  test(
    'simulation workout helper creates uploadable fixture workout',
    () async {
      final ingestion = _FakeIngestionClient();
      final service = WearableSyncService(ingestionClient: ingestion);

      final result = await service.uploadSimulationWorkout(
        patientId: '20',
        workoutType: 'running',
        startTime: DateTime.parse('2026-06-20T10:00:00Z'),
        endTime: DateTime.parse('2026-06-20T10:45:00Z'),
        distanceMeters: 8000,
        activeEnergyKcal: 520,
        steps: 9000,
      );

      expect(result.success, isTrue);
      final workout = ingestion.workouts.single;
      expect(workout.sourceProvider, WearableSource.simulation);
      expect(workout.sourceWorkoutId, contains('simulation-20-'));
      expect(workout.durationSeconds, 2700);
      expect(workout.distanceMeters, 8000);
      expect(workout.activeEnergyKcal, 520);
      expect(workout.sourceMetadata['source'], 'fixture');
    },
  );

  test(
    'batch workout upload routes through backend ingestion client',
    () async {
      final ingestion = _FakeIngestionClient();
      final service = WearableSyncService(ingestionClient: ingestion);

      final result = await service.uploadWorkouts([
        _testWorkout(),
        _testWorkout(sourceWorkoutId: 'HK-2'),
      ]);

      expect(result.success, isTrue);
      expect(result.uploadedCount, 2);
      expect(ingestion.workoutBatches.single.length, 2);
    },
  );

  test(
    'Apple workout sync reads platform workouts then ingests batch',
    () async {
      final ingestion = _FakeIngestionClient();
      final appleWorkouts = _FakeWorkoutSyncService(
        source: WearableSource.appleHealth,
        workouts: [_testWorkout()],
      );
      final service = WearableSyncService(
        ingestionClient: ingestion,
        appleWorkoutSyncService: appleWorkouts,
      );

      final result = await service.syncWorkoutsFromAppleHealth(patientId: '20');

      expect(result.success, isTrue);
      expect(appleWorkouts.readCount, 1);
      expect(ingestion.workoutBatches.single.single.sourceWorkoutId, 'HK-1');
    },
  );

  test(
    'workout platform source failure does not call backend ingestion',
    () async {
      final ingestion = _FakeIngestionClient();
      final appleWorkouts = _FakeWorkoutSyncService.failure(
        source: WearableSource.appleHealth,
        message: 'workout permission denied',
      );
      final service = WearableSyncService(
        ingestionClient: ingestion,
        appleWorkoutSyncService: appleWorkouts,
      );

      final result = await service.syncWorkoutsFromAppleHealth(patientId: '20');

      expect(result.success, isFalse);
      expect(result.message, 'workout permission denied');
      expect(ingestion.workoutBatches, isEmpty);
      expect(ingestion.workouts, isEmpty);
    },
  );

  test(
    'legacy eHospital wearable upload delegates to ingestion client',
    () async {
      final ingestion = _FakeIngestionClient();
      final repository = EHospitalRepository(
        wearableIngestionClient: ingestion,
      );

      await repository.sendWearableVitals(
        patientId: '20',
        heartRate: 72,
        steps: 4500,
        calories: 220,
        sleep: 7,
      );

      expect(ingestion.samples.single.patientId, '20');
      expect(ingestion.samples.single.source, WearableSource.manual);
    },
  );

  test(
    'syncPlatformHealth refuses fake simulation data when running on Web without Fitbit OAuth',
    () async {
      final ingestion = _FakeIngestionClient();
      final service = WearableSyncService(
        ingestionClient: ingestion,
        isWebOverride: true,
        platformOverride: TargetPlatform.android,
      );

      final result = await service.syncPlatformHealth(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isFalse);
      expect(result.source, WearableSource.samsungHealth);
      expect(result.message, contains('Not connected'));
      expect(ingestion.samples, isEmpty);
    },
  );

  test(
    'Android Health Connect reports missing read permissions when requestAuthorization only partially grants',
    () async {
      final fakeHealth = _FakeHealth(
        initiallyGranted: {HealthDataType.ACTIVE_ENERGY_BURNED},
        grantedAfterRequest: {HealthDataType.ACTIVE_ENERGY_BURNED},
      );
      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        diagnosticsProvider: () async => {
          'available': true,
          'missingCorePermissions': ['Steps', 'Heart Rate', 'Sleep'],
          'records29dCount': 0,
        },
      );

      final result = await google.readLatestSample(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('missing Health Connect read access'));
      expect(result.message, contains('Steps'));
      expect(result.message, contains('Heart Rate'));
    },
  );

  test(
    'Android Health Connect uses earlier-within-24h Samsung Health points when today after midnight is empty',
    () async {
      final now = DateTime.now();
      final pointTime = now.subtract(const Duration(hours: 20));
      final fakeHealth = _FakeHealth(
        initiallyGranted: {
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_SESSION,
          HealthDataType.RESTING_HEART_RATE,
        },
        aggregateStepsToday: 0,
        points: [
          HealthDataPoint(
            uuid: 'sh-1',
            value: NumericHealthValue(numericValue: 4120),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: pointTime.subtract(const Duration(minutes: 30)),
            dateTo: pointTime,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'sh-2',
            value: NumericHealthValue(numericValue: 265),
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: pointTime.subtract(const Duration(minutes: 30)),
            dateTo: pointTime,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
        ],
      );
      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
      );

      final result = await google.readLatestSample(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isTrue);
      expect(result.sample?.source, WearableSource.samsungHealth);
      expect(result.sample?.steps, 4120);
      expect(result.sample?.calories, 265);
    },
  );

  test(
    'Android Health Connect falls back to most recent active day within 29 days when 24h is empty',
    () async {
      final now = DateTime.now();
      final twoDaysAgo = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 2))
          .add(const Duration(hours: 14));
      final fakeHealth = _FakeHealth(
        initiallyGranted: {
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
        },
        aggregateStepsToday: 0,
        points: [
          HealthDataPoint(
            uuid: 'sh-old-1',
            value: NumericHealthValue(numericValue: 6500),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: twoDaysAgo.subtract(const Duration(hours: 1)),
            dateTo: twoDaysAgo,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'sh-old-2',
            value: NumericHealthValue(numericValue: 74),
            type: HealthDataType.HEART_RATE,
            unit: HealthDataUnit.BEATS_PER_MINUTE,
            dateFrom: twoDaysAgo,
            dateTo: twoDaysAgo,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
        ],
      );
      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
      );

      final result = await google.readLatestSample(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isTrue);
      expect(result.sample?.source, WearableSource.samsungHealth);
      expect(result.sample?.steps, 6500);
      expect(result.sample?.heartRate, 74);
      expect(result.sample?.sourceMetadata['sync_window'], 'latest_within_29d');
    },
  );

  test(
    'Android Health Connect surfaces clear Samsung Allow-to-write diagnosis when granted but 0 records exist',
    () async {
      final allCore = {
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
      };
      final fakeHealth = _FakeHealth(
        initiallyGranted: allCore,
        aggregateStepsToday: 0,
      );
      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        diagnosticsProvider: () async => {
          'available': true,
          'missingCorePermissions': const <String>[],
          'records29dCount': 0,
          'dataOrigins29d': const <String, int>{},
        },
      );

      final result = await google.readLatestSample(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Allow to write'));
      expect(result.message, contains('Samsung Health'));
    },
  );

  test(
    'Android Health Connect uses native OS AggregateRequest consistently across overlapping watch/phone/multi-app records',
    () async {
      final now = DateTime.now();
      final pointTime = now.isAfter(
        DateTime(now.year, now.month, now.day).add(const Duration(seconds: 2)),
      )
          ? now.subtract(const Duration(seconds: 1))
          : now;
      final fakeHealth = _FakeHealth(
        initiallyGranted: {
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
        },
        // Even if raw points contain overlapping Samsung Health + Google Fit + Total Calories:
        points: [
          HealthDataPoint(
            uuid: 'sh-phone',
            value: NumericHealthValue(numericValue: 4000),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: pointTime.subtract(const Duration(minutes: 40)),
            dateTo: pointTime,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy-phone',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'sh-watch',
            value: NumericHealthValue(numericValue: 4200),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: pointTime.subtract(const Duration(minutes: 40)),
            dateTo: pointTime,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy-watch',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'gfit-overlap',
            value: NumericHealthValue(numericValue: 3900),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: pointTime.subtract(const Duration(minutes: 40)),
            dateTo: pointTime,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy-phone',
            sourceId: '',
            sourceName: 'com.google.android.apps.fitness',
          ),
          HealthDataPoint(
            uuid: 'sh-total-cal',
            value: NumericHealthValue(numericValue: 1890),
            type: HealthDataType.TOTAL_CALORIES_BURNED,
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: pointTime.subtract(const Duration(minutes: 40)),
            dateTo: pointTime,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy-watch',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
        ],
      );

      List<String>? capturedPackages;
      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        aggregateMetricsProvider: (start, end, packageNames) async {
          capturedPackages = packageNames;
          return {
            'available': true,
            'steps': 4350,
            'activeCalories': 312.4,
            'totalCalories': 1920.0,
          };
        },
      );

      final result = await google.readLatestSample(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isTrue);
      expect(capturedPackages, contains('com.sec.android.app.shealth'));
      expect(result.sample?.steps, 4350);
      expect(result.sample?.calories, 312);
      expect(result.sample?.sourceMetadata['steps_method'], 'os_aggregate_today');
      expect(
        result.sample?.sourceMetadata['calories_method'],
        'os_aggregate_active',
      );
    },
  );

  test(
    'Dart interval deduplication merges overlapping Watch+Phone points and prevents flipping between Active and Total BMR calories',
    () async {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final baseTime = now.difference(dayStart).inSeconds >= 10
          ? dayStart.add(const Duration(seconds: 2))
          : now.subtract(const Duration(seconds: 5));
      final firstEnd = baseTime.add(const Duration(seconds: 1));
      final secondStart = baseTime.add(const Duration(seconds: 2));
      final secondEnd = baseTime.add(const Duration(seconds: 3));

      final fakeHealth = _FakeHealth(
        initiallyGranted: {
          HealthDataType.STEPS,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED,
        },
        aggregateStepsToday: 0,
        points: [
          // Overlapping Phone (3800) & Watch (4100) for same window -> keeps max 4100
          HealthDataPoint(
            uuid: 'phone-morning',
            value: NumericHealthValue(numericValue: 3800),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: baseTime,
            dateTo: firstEnd,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'phone-1',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'watch-morning',
            value: NumericHealthValue(numericValue: 4100),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: baseTime,
            dateTo: firstEnd,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'watch-1',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          // Separate non-overlapping window -> adds +900 => 5000 total steps
          HealthDataPoint(
            uuid: 'watch-evening',
            value: NumericHealthValue(numericValue: 900),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: secondStart,
            dateTo: secondEnd,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'watch-1',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          // Earlier ACTIVE_ENERGY_BURNED inside 24h; current window has only TOTAL_CALORIES_BURNED so far -> never jump to 1950 BMR!
          HealthDataPoint(
            uuid: 'prev-active',
            value: NumericHealthValue(numericValue: 240),
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: dayStart.subtract(const Duration(hours: 4)),
            dateTo: dayStart.subtract(const Duration(hours: 3)),
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'watch-1',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'today-total-bmr',
            value: NumericHealthValue(numericValue: 1950),
            type: HealthDataType.TOTAL_CALORIES_BURNED,
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: baseTime,
            dateTo: secondEnd,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'watch-1',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
        ],
      );

      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
      );

      final result = await google.readLatestSample(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isTrue);
      expect(result.sample?.steps, 5000);
      expect(result.sample?.calories, 1950);
    },
  );

  test(
    'Midnight reset reports 0 today steps and 0 cal while excluding yesterday intervals ending at 00:00:00',
    () async {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = dayStart.subtract(const Duration(hours: 6));
      final fakeHealth = _FakeHealth(
        initiallyGranted: {
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED,
        },
        points: [
          HealthDataPoint(
            uuid: 'yday-steps-midnight',
            value: NumericHealthValue(numericValue: 5000),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: yesterdayStart,
            dateTo: dayStart,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy-phone',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'yday-cal-midnight',
            value: NumericHealthValue(numericValue: 240),
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: yesterdayStart,
            dateTo: dayStart,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy-phone',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
        ],
      );

      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        aggregateMetricsProvider: (start, end, packageNames) async {
          if (!start.isBefore(dayStart)) {
            // Today after midnight: 0 steps, 0 active, small BMR should stay 0.
            return {
              'available': true,
              'steps': 0,
              'activeCalories': 0.0,
              'totalCalories': 18.0,
            };
          }
          // Yesterday aggregate
          return {
            'available': true,
            'steps': 5000,
            'activeCalories': 240.0,
            'totalCalories': 1850.0,
          };
        },
      );

      final result = await google.readLatestSample(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isTrue);
      expect(result.sample?.steps, 0);
      expect(result.sample?.calories, 0);
      expect(
        result.sample?.sourceMetadata['sync_window'],
        'today_midnight_reset',
      );
      expect(result.sample?.sourceMetadata['yesterday_steps'], 5000);
    },
  );

  test(
    'Preferred Samsung Health filter stays locked even when only another app has today steps',
    () async {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final fakeHealth = _FakeHealth(
        initiallyGranted: {
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.ACTIVE_ENERGY_BURNED,
        },
        aggregateStepsToday: 5040,
        points: [
          // Another app in Health Connect holds 5040 today steps
          HealthDataPoint(
            uuid: 'gfit-today-steps',
            value: NumericHealthValue(numericValue: 5040),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: dayStart.add(const Duration(minutes: 1)),
            dateTo: dayStart.add(const Duration(minutes: 20)),
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'phone-1',
            sourceId: 'com.google.android.apps.fitness',
            sourceName: 'com.google.android.apps.fitness',
          ),
          // Yesterday Samsung Health point exists inside 24h window
          HealthDataPoint(
            uuid: 'shealth-yday-steps',
            value: NumericHealthValue(numericValue: 5009),
            type: HealthDataType.STEPS,
            unit: HealthDataUnit.COUNT,
            dateFrom: dayStart.subtract(const Duration(hours: 6)),
            dateTo: dayStart,
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'galaxy-watch',
            sourceId: 'com.sec.android.app.shealth',
            sourceName: 'com.sec.android.app.shealth',
          ),
        ],
      );

      final capturedPackages = <List<String>>[];
      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        aggregateMetricsProvider: (start, end, packageNames) async {
          capturedPackages.add(packageNames);
          final isSamsungOnly = packageNames.contains('com.sec.android.app.shealth');
          if (!start.isBefore(dayStart)) {
            return {
              'available': true,
              'steps': isSamsungOnly ? 0 : 5040,
              'strictSteps': isSamsungOnly ? 0 : 5040,
              'activeCalories': 0.0,
              'totalCalories': 0.0,
            };
          }
          return {
            'available': true,
            'steps': isSamsungOnly ? 5009 : 10049,
            'strictSteps': isSamsungOnly ? 5009 : 10049,
            'activeCalories': 220.0,
            'totalCalories': 1800.0,
          };
        },
      );

      final result = await google.readLatestSample(
        patientId: '20',
        preferredSourceKey: WearableSource.samsungHealth,
      );

      expect(result.success, isTrue);
      expect(result.sample?.source, WearableSource.samsungHealth);
      expect(result.sample?.steps, 0);
      expect(result.sample?.calories, 0);
      expect(capturedPackages, isNotEmpty);
      expect(
        capturedPackages.every(
          (pkgs) => pkgs.contains('com.sec.android.app.shealth'),
        ),
        isTrue,
      );
    },
  );

  test(
    'Cross-midnight multi-hour step dump is filtered via strictSteps and reported in sync message',
    () async {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final fakeHealth = _FakeHealth(
        initiallyGranted: {
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.SLEEP_SESSION,
        },
        points: [
          HealthDataPoint(
            uuid: 'today-hr',
            value: NumericHealthValue(numericValue: 73),
            type: HealthDataType.HEART_RATE,
            unit: HealthDataUnit.BEATS_PER_MINUTE,
            dateFrom: dayStart.add(const Duration(minutes: 5)),
            dateTo: dayStart.add(const Duration(minutes: 10)),
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'watch',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'today-cal',
            value: NumericHealthValue(numericValue: 1),
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: dayStart.add(const Duration(minutes: 5)),
            dateTo: dayStart.add(const Duration(minutes: 15)),
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'watch',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
          HealthDataPoint(
            uuid: 'today-sleep',
            value: NumericHealthValue(numericValue: 252),
            type: HealthDataType.SLEEP_SESSION,
            unit: HealthDataUnit.MINUTE,
            dateFrom: dayStart.subtract(const Duration(hours: 3)),
            dateTo: dayStart.add(const Duration(minutes: 12)),
            sourcePlatform: HealthPlatformType.googleHealthConnect,
            sourceDeviceId: 'watch',
            sourceId: '',
            sourceName: 'com.sec.android.app.shealth',
          ),
        ],
      );

      final google = GoogleHealthSyncService(
        health: fakeHealth,
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        aggregateMetricsProvider: (start, end, packageNames) async {
          return {
            'available': true,
            'steps': 5040,
            'strictSteps': 0,
            'crossMidnightRecords': 1,
            'longCrossMidnightRecords': 1,
            'strictStepRecords': 0,
            'activeCalories': 1.0,
            'totalCalories': 40.0,
            'stepsByOrigin': {
              'com.sec.android.app.shealth': 0,
              'com.google.android.apps.fitness': 5040,
            },
            'originLabels': {
              'com.sec.android.app.shealth': 'Samsung Health',
              'com.google.android.apps.fitness': 'Google Fit',
            },
          };
        },
      );

      final ingestion = _FakeIngestionClient();
      final service = WearableSyncService(
        ingestionClient: ingestion,
        googleHealthSyncService: google,
      );

      final result = await service.syncFromHealthConnect(patientId: '20');

      expect(result.success, isTrue);
      expect(ingestion.samples.single.steps, 0);
      expect(ingestion.samples.single.calories, 1);
      expect(ingestion.samples.single.heartRate, 73);
      expect(ingestion.samples.single.sleep, 4.2);
      expect(
        ingestion.samples.single.sourceMetadata['pre_midnight_filtered_steps'],
        5040,
      );
      expect(result.message, contains('excluded 5040 pre-midnight steps'));
      expect(
        result.message,
        contains('[HC steps: Samsung Health 0, Google Fit 5040]'),
      );
    },
  );
}

class _FakeHealth extends Health {
  _FakeHealth({
    Set<HealthDataType>? initiallyGranted,
    Set<HealthDataType>? grantedAfterRequest,
    List<HealthDataPoint>? points,
    this.aggregateStepsToday = 0,
  }) : _granted = Set<HealthDataType>.from(initiallyGranted ?? const {}),
       _grantedAfterRequest = grantedAfterRequest,
       _points = points ?? const [];

  final Set<HealthDataType> _granted;
  final Set<HealthDataType>? _grantedAfterRequest;
  final List<HealthDataPoint> _points;
  final int aggregateStepsToday;

  @override
  Future<void> configure() async {}

  @override
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() async =>
      HealthConnectSdkStatus.sdkAvailable;

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    return types.every(_granted.contains);
  }

  @override
  Future<bool> requestAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    final next = _grantedAfterRequest;
    if (next != null) {
      _granted.addAll(next);
    }
    return _granted.isNotEmpty;
  }

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    return _points.where((point) {
      return _granted.contains(point.type) &&
          types.contains(point.type) &&
          !point.dateTo.isBefore(startTime) &&
          !point.dateTo.isAfter(endTime);
    }).toList();
  }

  @override
  List<HealthDataPoint> removeDuplicates(List<HealthDataPoint> points) => points;

  @override
  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime, {
    bool includeManualEntry = true,
  }) async {
    return aggregateStepsToday;
  }
}

class _FakeIngestionClient implements WearableIngestionClient {
  final samples = <WearableSample>[];
  final workouts = <WearableWorkout>[];
  final workoutBatches = <List<WearableWorkout>>[];

  @override
  Future<WearableIngestionResult> ingest(WearableSample sample) async {
    samples.add(sample);
    return WearableIngestionResult(
      status: 'ingested',
      patientId: sample.patientId,
      acceptedMetrics: sample.acceptedMetrics,
      source: sample.source,
      timestamp: sample.timestamp.toIso8601String(),
      recordedOn: (sample.recordedOn ?? sample.timestamp).toIso8601String(),
    );
  }

  @override
  Future<WearableWorkoutIngestionResult> ingestWorkout(
    WearableWorkout workout,
  ) async {
    workouts.add(workout);
    return _workoutIngestionResult(workout);
  }

  @override
  Future<WearableWorkoutBatchIngestionResult> ingestWorkoutBatch(
    List<WearableWorkout> workouts,
  ) async {
    workoutBatches.add(workouts);
    return WearableWorkoutBatchIngestionResult(
      status: 'ingested',
      acceptedCount: workouts.length,
      ingestedCount: workouts.length,
      workouts: workouts.map(_workoutIngestionResult).toList(),
    );
  }
}

class _FakePlatformSyncService implements WearablePlatformSyncService {
  _FakePlatformSyncService({
    required this.source,
    required WearableSample sample,
  }) : _sample = sample,
       _message = null;

  _FakePlatformSyncService.failure({
    required this.source,
    required String message,
  }) : _sample = null,
       _message = message;

  @override
  final String source;

  final WearableSample? _sample;
  final String? _message;
  int readCount = 0;

  @override
  Future<WearableSourceReadResult> readLatestSample({
    required String patientId,
  }) async {
    readCount++;
    final sample = _sample;
    if (sample == null) {
      return WearableSourceReadResult.failure(
        source: source,
        message: _message ?? 'unavailable',
      );
    }
    return WearableSourceReadResult.success(sample);
  }
}

class _FakeWorkoutSyncService implements WearablePlatformWorkoutSyncService {
  _FakeWorkoutSyncService({
    required this.source,
    required List<WearableWorkout> workouts,
  }) : _workouts = workouts,
       _message = null;

  _FakeWorkoutSyncService.failure({
    required this.source,
    required String message,
  }) : _workouts = const [],
       _message = message;

  @override
  final String source;

  final List<WearableWorkout> _workouts;
  final String? _message;
  int readCount = 0;

  @override
  Future<WearableWorkoutReadResult> readRecentWorkouts({
    required String patientId,
  }) async {
    readCount++;
    final message = _message;
    if (message != null) {
      return WearableWorkoutReadResult.failure(
        source: source,
        message: message,
      );
    }
    return WearableWorkoutReadResult.success(
      source: source,
      workouts: _workouts,
    );
  }
}

WearableWorkout _testWorkout({String sourceWorkoutId = 'HK-1'}) {
  return WearableWorkout(
    patientId: '20',
    sourceProvider: WearableSource.appleHealth,
    sourceWorkoutId: sourceWorkoutId,
    workoutType: 'running',
    startTime: DateTime.parse('2026-06-20T10:00:00Z'),
    endTime: DateTime.parse('2026-06-20T10:30:00Z'),
    durationSeconds: 1800,
    distanceMeters: 5000,
  );
}

WearableWorkoutIngestionResult _workoutIngestionResult(
  WearableWorkout workout,
) {
  return WearableWorkoutIngestionResult(
    status: 'ingested',
    patientId: workout.patientId,
    sourceProvider: workout.sourceProvider,
    sourceWorkoutId: workout.sourceWorkoutId,
    workoutType: workout.workoutType,
    startTime: workout.startTime.toIso8601String(),
    endTime: workout.endTime.toIso8601String(),
    durationSeconds: workout.durationSeconds,
  );
}
