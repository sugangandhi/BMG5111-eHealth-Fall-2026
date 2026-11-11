import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/wearable_models.dart';

abstract class WearableIngestionClient {
  Future<WearableIngestionResult> ingest(WearableSample sample);
  Future<WearableWorkoutIngestionResult> ingestWorkout(WearableWorkout workout);
  Future<WearableWorkoutBatchIngestionResult> ingestWorkoutBatch(
    List<WearableWorkout> workouts,
  );
}

class WearableIngestionRepository implements WearableIngestionClient {
  final ApiClient _client;
  final ApiClient _cloudClient;

  WearableIngestionRepository({ApiClient? client, ApiClient? cloudClient})
    : _client = client ?? ApiClient(),
      _cloudClient =
          cloudClient ?? ApiClient(baseUrl: ApiConfig.ehospitalBaseUrl);

  @override
  Future<WearableIngestionResult> ingest(WearableSample sample) async {
    try {
      final decoded = await _client.postJson(
        '/wearables/ingest',
        sample.toJson(),
      );
      if (decoded is Map<String, dynamic>) {
        return WearableIngestionResult.fromJson(decoded);
      }
    } catch (_) {
      // Local backend unreachable (e.g. mobile device on 5G cellular network).
      // Seamlessly persist directly to central AWS App Runner eHospital cloud EHR.
      try {
        final payload = {
          'patient_id': sample.patientId,
          if (sample.heartRate != null) 'heart_rate': sample.heartRate,
          if (sample.steps != null) 'steps': sample.steps,
          if (sample.calories != null) 'calories': sample.calories,
          if (sample.sleep != null) 'sleep': sample.sleep,
          if (sample.stressScore != null) 'stress_score': sample.stressScore,
          'timestamp': sample.timestamp.toUtc().toIso8601String(),
        };
        await _cloudClient.postJson('/table/wearable_vitals', payload);
        return WearableIngestionResult(
          status: 'ingested',
          patientId: sample.patientId,
          acceptedMetrics: sample.acceptedMetrics,
          source: sample.source,
          timestamp: sample.timestamp.toUtc().toIso8601String(),
          recordedOn: DateTime.now().toUtc().toIso8601String(),
        );
      } catch (cloudErr) {
        throw ApiException('Failed to sync wearable vitals: $cloudErr');
      }
    }
    throw const ApiException('Backend returned an unexpected response.');
  }

  @override
  Future<WearableWorkoutIngestionResult> ingestWorkout(
    WearableWorkout workout,
  ) async {
    final decoded = await _client.postJson(
      '/wearables/workouts/ingest',
      workout.toJson(),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Backend returned an unexpected response.');
    }
    return WearableWorkoutIngestionResult.fromJson(decoded);
  }

  @override
  Future<WearableWorkoutBatchIngestionResult> ingestWorkoutBatch(
    List<WearableWorkout> workouts,
  ) async {
    final decoded = await _client.postJson('/wearables/workouts/batch-ingest', {
      'workouts': workouts.map((workout) => workout.toJson()).toList(),
    });
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Backend returned an unexpected response.');
    }
    return WearableWorkoutBatchIngestionResult.fromJson(decoded);
  }
}
