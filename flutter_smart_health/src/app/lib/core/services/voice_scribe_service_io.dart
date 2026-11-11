import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'voice_scribe_types.dart';
import 'voice_transcription_client.dart';

export 'voice_scribe_types.dart';

/// Native mobile voice dictation bridge using Android SpeechRecognizer with
/// automatic MediaRecorder + Whisper transcription fallback.
class VoiceScribeService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.smart_health_app/voice_scribe',
  );

  static bool _handlerRegistered = false;
  static SpeechResultCallback? _onResult;
  static SpeechStatusCallback? _onStatus;
  static VoiceTranscriptionClient _transcriber = VoiceTranscriptionClient();

  static bool get isSupported => Platform.isAndroid;

  static void setTranscriptionClientForTesting(VoiceTranscriptionClient client) {
    _transcriber = client;
  }

  static void _ensureHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      final map = args is Map ? args : const <dynamic, dynamic>{};
      switch (call.method) {
        case 'onSpeechResult':
          final finalText = map['finalResult']?.toString() ?? '';
          final interimText = map['interimResult']?.toString() ?? '';
          _onResult?.call(finalText, interimText);
          break;
        case 'onSpeechStatus':
          final status = map['status']?.toString() ?? '';
          final message = map['message']?.toString() ?? '';
          _onStatus?.call(status, message);
          break;
        case 'onAudioCaptured':
          final base64Audio = map['base64']?.toString() ?? '';
          final filename = map['filename']?.toString() ?? 'voice_note.m4a';
          await _handleCapturedAudio(base64Audio, filename);
          break;
      }
    });
  }

  static Future<void> _handleCapturedAudio(
    String base64Audio,
    String filename,
  ) async {
    try {
      final text = await _transcriber.transcribeBase64Audio(
        base64Audio: base64Audio,
        filename: filename,
      );
      if (text.isNotEmpty) {
        _onResult?.call(text, '');
        _onStatus?.call('stopped', '');
      } else {
        _onStatus?.call(
          'error',
          'No speech could be transcribed. Please speak clearly near the mic.',
        );
      }
    } catch (e) {
      _onStatus?.call('error', 'Voice transcription failed: $e');
    }
  }

  static void startListening({
    required SpeechResultCallback onResult,
    required SpeechStatusCallback onStatus,
  }) {
    _ensureHandler();
    _onResult = onResult;
    _onStatus = onStatus;
    unawaited(_invokeStartListening(onStatus));
  }

  static Future<void> _invokeStartListening(
    SpeechStatusCallback onStatus,
  ) async {
    try {
      await _channel.invokeMethod('startListening');
    } on MissingPluginException {
      onStatus(
        'unsupported',
        'Native microphone dictation is currently supported on Android and Web browsers.',
      );
    } catch (e) {
      onStatus('error', e.toString());
    }
  }

  static void stopListening() {
    _ensureHandler();
    unawaited(
      _channel.invokeMethod('stopListening').catchError((_) => null),
    );
  }

  static void startRecordingAudio({required SpeechStatusCallback onStatus}) {
    onStatus(
      'unsupported',
      'Direct audio clip recording is handled automatically by voice dictation.',
    );
  }

  static void stopRecordingAudio({required AudioRecordingDoneCallback onDone}) {
    onDone('');
  }
}
