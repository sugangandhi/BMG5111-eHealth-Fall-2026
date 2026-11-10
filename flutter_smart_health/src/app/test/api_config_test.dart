import 'package:flutter_test/flutter_test.dart';
import 'package:smart_health_app/config/api_config.dart';

void main() {
  test('Gemini config validates API key clearly', () {
    if (ApiConfig.geminiApiKey.isEmpty) {
      expect(
        ApiConfig.requireGeminiConfig,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Missing GEMINI_API_KEY'),
          ),
        ),
      );
    } else {
      expect(ApiConfig.requireGeminiConfig, returnsNormally);
    }
  });

  test('default native backend URL targets live Render HTTPS service', () {
    expect(
      ApiConfig.backendBaseUrl,
      'https://bmg5111-ehealth-fall-2026-1.onrender.com',
    );
  });
}
