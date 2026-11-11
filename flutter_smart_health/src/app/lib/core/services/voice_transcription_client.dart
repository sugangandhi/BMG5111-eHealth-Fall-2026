import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// Transcribes recorded Base64 audio using the backend Whisper endpoint.
class VoiceTranscriptionClient {
  VoiceTranscriptionClient({
    http.Client? client,
    String? baseUrlOverride,
  })  : _client = client ?? http.Client(),
        _baseUrlOverride = baseUrlOverride;

  final http.Client _client;
  final String? _baseUrlOverride;

  Future<String> transcribeBase64Audio({
    required String base64Audio,
    String filename = 'recording.webm',
  }) async {
    if (base64Audio.trim().isEmpty) return '';
    final baseUrl = _baseUrlOverride ?? ApiConfig.backendBaseUrl;
    if (baseUrl.trim().isEmpty) return '';

    final uri = Uri.parse('$baseUrl/api/assistant/voice-transcribe');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'audio_base64': base64Audio,
            'filename': filename,
            'transcribe_only': true,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError('Voice transcription failed (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['transcription']?.toString().trim() ?? '';
    }
    return '';
  }
}
