import 'package:flutter/foundation.dart';

class ApiConfig {
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

  static String? _customBackendHost;

  static void setBackendHost(String host) {
    _customBackendHost = host.trim();
  }

  static String get backendBaseUrl {
    if (_customBackendHost != null && _customBackendHost!.isNotEmpty) {
      final host = _customBackendHost!;
      if (host.startsWith('http://') || host.startsWith('https://')) {
        return host;
      }
      if (host.contains('.trycloudflare.com') ||
          host.contains('.ngrok') ||
          host.contains('.loca.lt') ||
          (host.contains('.') && !RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(host))) {
        return 'https://$host';
      }
      final portPart = host.contains(':') ? '' : ':8080';
      return 'http://$host$portPart';
    }
    const defined = String.fromEnvironment('BACKEND_BASE_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.host.isNotEmpty) {
        final portPart = (uri.hasPort && uri.port != 80 && uri.port != 443) ? ':${uri.port}' : '';
        return '${uri.scheme}://${uri.host}$portPart';
      }
    }
    // Default to the Cloudflare live tunnel for universal mobile & APK access
    return 'https://saskatchewan-honolulu-event-captured.trycloudflare.com';
  }

  static String get ehospitalBaseUrl {
    const defined = String.fromEnvironment('EHOSPITAL_BASE_URL');
    if (defined.isNotEmpty) return defined;
    return backendBaseUrl;
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
