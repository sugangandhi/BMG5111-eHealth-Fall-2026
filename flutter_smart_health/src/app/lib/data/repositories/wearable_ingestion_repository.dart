import 'dart:convert';

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

abstract class WearableExportClient {
  Future<WearableExportImportResult> importExportFile({
    required String patientId,
    required String filename,
    required List<int> bytes,
    String? provider,
  });
}

class WearableIngestionRepository
    implements WearableIngestionClient, WearableExportClient {
  final ApiClient _client;

  WearableIngestionRepository({ApiClient? client})
    : _client = client ??
          ApiClient(baseUrlProvider: () => ApiConfig.backendBaseUrl);

  @override
  Future<WearableIngestionResult> ingest(WearableSample sample) async {
    final decoded = await _client.postJson(
      '/wearables/ingest',
      sample.toJson(),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Backend returned an unexpected response.');
    }
    return WearableIngestionResult.fromJson(decoded);
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

  @override
  Future<WearableExportImportResult> importExportFile({
    required String patientId,
    required String filename,
    required List<int> bytes,
    String? provider,
  }) async {
    final decoded = await _client.postJson('/wearables/import-export', {
      'patient_id': patientId,
      'filename': filename,
      'content_base64': base64Encode(bytes),
      if (provider != null && provider.trim().isNotEmpty) 'provider': provider,
    });
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Backend returned an unexpected response.');
    }
    return WearableExportImportResult.fromJson(decoded);
  }
}
