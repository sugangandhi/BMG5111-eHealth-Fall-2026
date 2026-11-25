import '../config/api_config.dart';
import '../core/network/api_client.dart';
import '../data/repositories/assistant_repository.dart';
import '../data/models/assistant_models.dart';

export '../core/network/api_exception.dart';

// Compatibility facade for screens that still call the old static service API.
// New code should prefer AssistantRepository directly.
class BackendApiService {
  static final AssistantRepository _repository = AssistantRepository();
  static final ApiClient _apiClient = ApiClient(baseUrlProvider: () => ApiConfig.backendBaseUrl);

  static Future<Map<String, dynamic>> doctorDispatchPatientMessage({
    required String patientPhone,
    required String message,
    String? patientName,
    int? patientId,
    String doctorName = "Dr. Sugan",
    String ownerId = "",
  }) async {
    final res = await _apiClient.postJson('/api/doctor/dispatch-patient-message', {
      'patient_phone': patientPhone,
      'message': message,
      'patient_name': patientName ?? 'Patient',
      'patient_id': patientId ?? 99211,
      'doctor_name': doctorName,
      'owner_id': ownerId,
    });
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> initializeWhatsAppChannel({
    required String patientPhone,
    String? patientName,
    String doctorName = "Dr. Sugan",
    String? welcomeMessage,
  }) async {
    final res = await _apiClient.postJson('/api/doctor/initialize-whatsapp-channel', {
      'patient_phone': patientPhone,
      'patient_name': patientName ?? 'Patient',
      'doctor_name': doctorName,
      'welcome_message': welcomeMessage,
    });
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> getDoctorWhatsAppConfig({
    String doctorId = 'Dr. Sugan',
  }) async {
    try {
      final res = await _apiClient.getJson(
        '/api/doctor/whatsapp-config?doctor_id=${Uri.encodeComponent(doctorId)}',
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {'configured': false, 'verified': false, 'whatsapp_phone': ''};
  }

  static Future<Map<String, dynamic>> requestDoctorWhatsAppOtp({
    required String phone,
    String doctorId = 'Dr. Sugan',
  }) async {
    try {
      final res = await _apiClient.postJson(
        '/api/doctor/whatsapp-config/request-otp',
        {'phone': phone, 'doctor_id': doctorId},
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
    return {'success': false, 'error': 'Unable to request verification code.'};
  }

  static Future<Map<String, dynamic>> verifyDoctorWhatsAppOtp({
    required String phone,
    required String code,
    String doctorId = 'Dr. Sugan',
  }) async {
    try {
      final res = await _apiClient.postJson(
        '/api/doctor/whatsapp-config/verify',
        {'phone': phone, 'code': code, 'doctor_id': doctorId},
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      return {'verified': false, 'error': 'Connection error: $e'};
    }
    return {'verified': false, 'error': 'Verification failed.'};
  }

  static Future<List<Map<String, dynamic>>> getDoctorScheduledTasks({
    String? patientPhone,
    String? ownerId,
  }) async {
    try {
      final params = <String>[];
      if (patientPhone != null && patientPhone.isNotEmpty) {
        params.add('patient_phone=${Uri.encodeComponent(patientPhone)}');
      }
      if (ownerId != null && ownerId.isNotEmpty) {
        params.add('owner_id=${Uri.encodeComponent(ownerId)}');
      }
      final q = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await _apiClient.getJson('/api/doctor/scheduled-tasks$q');
      if (res is Map && res['tasks'] is List) {
        return List<Map<String, dynamic>>.from(
          (res['tasks'] as List).map((t) => Map<String, dynamic>.from(t as Map)),
        );
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> createDoctorScheduledTask({
    required String patientPhone,
    required String patientName,
    required String messageText,
    required String scheduledForUtc,
    required String scheduledDisplay,
    String doctorName = 'Dr. Sugan',
    String ownerId = '',
  }) async {
    try {
      final res = await _apiClient.postJson('/api/doctor/scheduled-tasks', {
        'doctor_name': doctorName,
        'owner_id': ownerId,
        'patient_phone': patientPhone,
        'patient_name': patientName,
        'message_text': messageText,
        'scheduled_for_utc': scheduledForUtc,
        'scheduled_display': scheduledDisplay,
      });
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> parseAndScheduleDoctorTask({
    required String instruction,
    required String doctorName,
    String? defaultPatientPhone,
    String? defaultPatientName,
    String ownerId = '',
  }) async {
    try {
      final tzOffset = DateTime.now().timeZoneOffset.inMinutes;
      final res = await _apiClient.postJson(
        '/api/doctor/scheduled-tasks/parse-and-schedule',
        {
          'instruction': instruction,
          'doctor_name': doctorName,
          'owner_id': ownerId,
          'default_patient_phone': defaultPatientPhone ?? '',
          'default_patient_name': defaultPatientName ?? '',
          'timezone_offset_minutes': tzOffset,
        },
      );
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
    return {'success': false};
  }

  static Future<bool> cancelDoctorScheduledTask(int taskId) async {
    try {
      final res = await _apiClient.postJson('/api/doctor/scheduled-tasks/$taskId/cancel', {});
      return res is Map && res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> sendDoctorAiAgentCommand({
    required String instruction,
    required String doctorName,
    String ownerId = '',
    List<Map<String, String>> history = const [],
    List<Map<String, String>> contacts = const [],
  }) async {
    try {
      final tzOffset = DateTime.now().timeZoneOffset.inMinutes;
      final res = await _apiClient.postJson(
        '/api/doctor/ai-agent-command',
        {
          'instruction': instruction,
          'doctor_name': doctorName,
          'owner_id': ownerId,
          'timezone_offset_minutes': tzOffset,
          'history': history,
          'contacts': contacts,
        },
      );
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'reply': 'Connection error: $e'};
    }
    return {'success': false, 'reply': 'Unable to reach MaxAssist AI.'};
  }

  static Future<List<Map<String, dynamic>>> getDoctorPatients({
    String? ownerId,
  }) async {
    try {
      final q = (ownerId != null && ownerId.isNotEmpty)
          ? '?owner_id=${Uri.encodeComponent(ownerId)}'
          : '';
      final res = await _apiClient.getJson('/api/doctor/patients$q');
      if (res is Map && res['patients'] is List) {
        return List<Map<String, dynamic>>.from(
          (res['patients'] as List).map((p) => Map<String, dynamic>.from(p as Map)),
        );
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> createDoctorPatient({
    required String name,
    required String phone,
    String notes = '',
    String doctorName = 'Dr. Sugan',
    String ownerId = '',
  }) async {
    try {
      final res = await _apiClient.postJson('/api/doctor/patients', {
        'name': name,
        'phone': phone,
        'notes': notes,
        'doctor_name': doctorName,
        'owner_id': ownerId,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {'success': false};
  }

  static Future<List<Map<String, dynamic>>> getDoctorChatHistory(
    String phone, {
    String? ownerId,
  }) async {
    try {
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      final q = (ownerId != null && ownerId.isNotEmpty)
          ? '?owner_id=${Uri.encodeComponent(ownerId)}'
          : '';
      final res = await _apiClient.getJson('/api/doctor/chat-history/$clean$q');
      if (res is Map && res['messages'] is List) {
        return List<Map<String, dynamic>>.from(
          (res['messages'] as List).map((m) => Map<String, dynamic>.from(m as Map)),
        );
      }
    } catch (_) {}
    return [];
  }

  static Future<AssistantChatReply> assistantChat({
    required String patientId,
    required String message,
    List<AssistantConversationMessage> history = const [],
  }) {
    return _repository.chat(
      patientId: patientId,
      message: message,
      history: history,
    );
  }

  static Future<List<Map<String, dynamic>>> getAssistantHistory(String patientId) {
    return _repository.getHistory(patientId);
  }

  static Future<void> clearAssistantHistory(String patientId) {
    return _repository.clearHistory(patientId);
  }

  static Future<String> vitalsSummary({
    required String patientId,
    required String metric,
    required String unit,
    required String healthyRange,
    double? latest,
    double? average,
    double? peak,
    int zeroCount = 0,
    int totalCount = 0,
    String? clinicalNote,
  }) {
    return _repository.vitalsSummary(
      patientId: patientId,
      metric: metric,
      unit: unit,
      healthyRange: healthyRange,
      latest: latest,
      average: average,
      peak: peak,
      zeroCount: zeroCount,
      totalCount: totalCount,
      clinicalNote: clinicalNote,
    );
  }

  static Future<Map<String, String>> trendInsights({
    required String patientId,
    required Map<String, double> steps,
    required Map<String, double> calories,
    required Map<String, double> heartRate,
    required Map<String, double> sleep,
  }) {
    return _repository.trendInsights(
      patientId: patientId,
      steps: steps,
      calories: calories,
      heartRate: heartRate,
      sleep: sleep,
    );
  }

  static Future<String> stressAnalysis({required String patientId}) {
    return _repository.stressAnalysis(patientId: patientId);
  }

  static Future<String> insightsSummary({
    required String patientId,
    required List<String> insightTitles,
    double? corrStepsCalories,
    double? corrHrBp,
    int anomalyCount = 0,
    int mergedCount = 0,
  }) {
    return _repository.insightsSummary(
      patientId: patientId,
      insightTitles: insightTitles,
      corrStepsCalories: corrStepsCalories,
      corrHrBp: corrHrBp,
      anomalyCount: anomalyCount,
      mergedCount: mergedCount,
    );
  }

  static Future<String?> syncModelStatus() {
    return _repository.syncModelStatus();
  }
}
