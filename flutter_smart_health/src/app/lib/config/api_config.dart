import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static String? _customBackendBaseUrl;

  static void setBackendBaseUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _customBackendBaseUrl = null;
      return;
    }
    _customBackendBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_backend_base_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _customBackendBaseUrl = savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}
  }

  static Future<void> saveBackendBaseUrl(String? url) async {
    setBackendBaseUrl(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_customBackendBaseUrl == null) {
        await prefs.remove('custom_backend_base_url');
      } else {
        await prefs.setString('custom_backend_base_url', _customBackendBaseUrl!);
      }
    } catch (_) {}
  }
  static const String aiProvider = String.fromEnvironment(
    'AI_PROVIDER',
    defaultValue: 'ollama',
  );

  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-1.5-flash',
  );

  static const String ollamaBaseUrl = String.fromEnvironment(
    'OLLAMA_BASE_URL',
    defaultValue: 'http://127.0.0.1:11434',
  );
  static const String ollamaModel = String.fromEnvironment(
    'OLLAMA_MODEL',
    defaultValue: 'llama3.1:8b',
  );
  static const String defaultModelProvider = String.fromEnvironment(
    'AI_MODEL_PROVIDER',
    defaultValue: 'ollama',
  );
  static const String defaultModelName = String.fromEnvironment(
    'AI_MODEL_NAME',
    defaultValue: ollamaModel,
  );
  static const String defaultModelBaseUrl = String.fromEnvironment(
    'AI_MODEL_BASE_URL',
    defaultValue: ollamaBaseUrl,
  );

  static String get backendBaseUrl {
    const defined = String.fromEnvironment('BACKEND_BASE_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty) {
        return 'http://$host:8080';
      }
    }
    return 'http://127.0.0.1:8080';
  }

  static String get ehospitalBaseUrl {
    const defined = String.fromEnvironment('EHOSPITAL_BASE_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) {
      return backendBaseUrl;
    }
    return 'https://aetab8pjmb.us-east-1.awsapprunner.com';
  }

  static const String fitbitClientId = String.fromEnvironment(
    'FITBIT_CLIENT_ID',
  );
  static const String fitbitClientSecret = String.fromEnvironment(
    'FITBIT_CLIENT_SECRET',
  );

  static String get aiProviderLabel {
    switch (aiProvider.toLowerCase()) {
      case 'gemini':
        return 'Gemini';
      case 'ollama':
        return 'Local Llama';
      case 'backend':
        return 'Python Backend';
      default:
        return aiProvider;
    }
  }

  static void requireGeminiConfig() {
    if (geminiApiKey.trim().isEmpty) {
      throw StateError(
        'Missing GEMINI_API_KEY. Run Flutter with '
        '--dart-define=GEMINI_API_KEY=your_key or use AI_PROVIDER=ollama.',
      );
    }
  }

  static void requireFitbitConfig() {
    final missing = <String>[
      if (fitbitClientId.trim().isEmpty) 'FITBIT_CLIENT_ID',
      if (fitbitClientSecret.trim().isEmpty) 'FITBIT_CLIENT_SECRET',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing ${missing.join(', ')}. Run Flutter with the required '
        '--dart-define values before connecting Fitbit.',
      );
    }
  }
}
