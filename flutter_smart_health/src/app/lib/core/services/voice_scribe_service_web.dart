// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

typedef SpeechResultCallback = void Function(String finalResult, String interimResult);
typedef SpeechStatusCallback = void Function(String status, String message);
typedef AudioRecordingDoneCallback = void Function(String base64Audio);

class VoiceScribeService {
  static bool get isSupported {
    try {
      return js.context.hasProperty('clinicalVoice');
    } catch (_) {
      return false;
    }
  }

  static void startListening({
    required SpeechResultCallback onResult,
    required SpeechStatusCallback onStatus,
  }) {
    if (!isSupported) {
      onStatus('unsupported', 'Web voice recognition is not supported in this browser.');
      return;
    }
    try {
      final voice = js.context['clinicalVoice'];
      voice.callMethod('startListening', [
        js.allowInterop((dynamic finalResult, dynamic interimResult) {
          onResult(finalResult?.toString() ?? '', interimResult?.toString() ?? '');
        }),
        js.allowInterop((dynamic status, dynamic message) {
          onStatus(status?.toString() ?? '', message?.toString() ?? '');
        }),
      ]);
    } catch (e) {
      onStatus('error', e.toString());
    }
  }

  static void stopListening() {
    if (!isSupported) return;
    try {
      final voice = js.context['clinicalVoice'];
      voice.callMethod('stopListening');
    } catch (_) {}
  }

  static void startRecordingAudio({required SpeechStatusCallback onStatus}) {
    if (!isSupported) {
      onStatus('unsupported', 'Microphone recording not supported.');
      return;
    }
    try {
      final voice = js.context['clinicalVoice'];
      voice.callMethod('startRecordingAudio', [
        js.allowInterop((dynamic status, dynamic message) {
          onStatus(status?.toString() ?? '', message?.toString() ?? '');
        }),
      ]);
    } catch (e) {
      onStatus('error', e.toString());
    }
  }

  static void stopRecordingAudio({required AudioRecordingDoneCallback onDone}) {
    if (!isSupported) {
      onDone('');
      return;
    }
    try {
      final voice = js.context['clinicalVoice'];
      voice.callMethod('stopRecordingAudio', [
        js.allowInterop((dynamic base64Audio) {
          onDone(base64Audio?.toString() ?? '');
        }),
      ]);
    } catch (_) {
      onDone('');
    }
  }
}
