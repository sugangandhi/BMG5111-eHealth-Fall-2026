import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/ehospital_models.dart';

class AuthRepository {
  static const supportedIdentities = <String>[
    'Admin',
    'Patient',
    'Doctor',
    'Clinic',
    'PharmaAdmin',
    'Pharma',
    'ClinicalReasoning',
  ];

  final ApiClient _client;

  AuthRepository({ApiClient? client})
    : _client = client ??
          ApiClient(baseUrlProvider: () => ApiConfig.backendBaseUrl);

  Future<AuthLoginResult> loginWithEmail(
    String email,
    String password, {
    String selectedOption = 'Patient',
  }) async {
    try {
      final decoded = await _client.postJson('/login', {
        'email': email,
        'password': password,
        'selectedOption': selectedOption,
      });
      if (decoded is Map) {
        final user = EHospitalUser.fromJson(Map<String, dynamic>.from(decoded));
        if (user.email.isEmpty) {
          return AuthLoginResult.rejected;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('patient_identity', user.selectedOption);
        await prefs.setString('patient_email', user.email);
        await prefs.setString('patient_username', user.username);
        if (user.patientId == null) {
          await prefs.remove('patient_id');
          return const AuthLoginResult(
            authenticated: true,
            hasPatientSession: false,
          );
        }
        await prefs.setInt('patient_id', user.patientId!);
        return const AuthLoginResult(
          authenticated: true,
          hasPatientSession: true,
        );
      }
      return AuthLoginResult.rejected;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 404) {
        return AuthLoginResult.rejected;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendWhatsAppOtp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final decoded = await _client.postJson('/api/auth/whatsapp/send-otp', {
      'phone': cleanPhone,
    });
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return {'success': false, 'error': 'Unexpected response from server'};
  }

  Future<AuthLoginResult> loginWithWhatsAppOtp(
    String phone,
    String code, {
    String selectedOption = 'Patient',
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final decoded = await _client.postJson('/api/auth/whatsapp/verify-otp', {
        'phone': cleanPhone,
        'code': code.trim(),
        'selectedOption': selectedOption,
      });

      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        final user = EHospitalUser.fromJson(data);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('patient_identity', user.selectedOption);
        await prefs.setString('patient_email', user.email);
        await prefs.setString('patient_username', user.username);
        await prefs.setString('patient_phone', cleanPhone);

        if (user.patientId == null) {
          await prefs.remove('patient_id');
          return const AuthLoginResult(
            authenticated: true,
            hasPatientSession: false,
          );
        }

        await prefs.setInt('patient_id', user.patientId!);
        return const AuthLoginResult(
          authenticated: true,
          hasPatientSession: true,
        );
      }
      return AuthLoginResult.rejected;
    } on ApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401 || error.statusCode == 404) {
        return AuthLoginResult.rejected;
      }
      rethrow;
    }
  }

  Future<int?> getLoggedInPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('patient_id');
  }

  Future<String?> getLoggedInPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('patient_phone');
  }

  Future<String?> getLoggedInIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('patient_identity');
  }
}
