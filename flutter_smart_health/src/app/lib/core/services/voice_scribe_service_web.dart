import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'voice_scribe_types.dart';
import 'voice_transcription_client.dart';

export 'voice_scribe_types.dart';

class VoiceScribeService {
  static final VoiceTranscriptionClient _transcriber =
      VoiceTranscriptionClient();

  static JSObject? _clinicalVoiceObject() {
    try {
      if (!globalContext.has('clinicalVoice')) return null;
      final candidate = globalContext['clinicalVoice'];
      if (candidate == null || !candidate.isA<JSObject>()) return null;
      return candidate as JSObject;
    } catch (_) {
      return null;
    }
  }

  static String _jsToString(JSAny? value) {
    if (value == null) return '';
    if (value.isA<JSString>()) return (value as JSString).toDart;
    return value.dartify()?.toString() ?? '';
  }

  static bool get isSupported => _clinicalVoiceObject() != null;

  static void startListening({
    required SpeechResultCallback onResult,
    required SpeechStatusCallback onStatus,
  }) {
    final voice = _clinicalVoiceObject();
    if (voice == null) {
      onStatus(
        'unsupported',
        'Microphone voice input is unavailable in this browser session.',
      );
      return;
    }
    try {
      final resultCb = ((JSAny? finalResult, JSAny? interimResult) {
        onResult(_jsToString(finalResult), _jsToString(interimResult));
      }).toJS;
      final statusCb = ((JSAny? status, JSAny? message) {
        onStatus(_jsToString(status), _jsToString(message));
      }).toJS;
      final audioCb = ((JSAny? base64Audio, JSAny? filename) {
        final rawAudio = _jsToString(base64Audio);
        final rawName = _jsToString(filename);
        unawaited(
          _transcribeWebAudio(
            rawAudio,
            rawName.isNotEmpty ? rawName : 'recording.webm',
            onResult,
            onStatus,
          ),
        );
      }).toJS;

      voice.callMethodVarArgs('startListening'.toJS, [
        resultCb,
        statusCb,
        audioCb,
      ]);
    } catch (e) {
      onStatus('error', e.toString());
    }
  }

  static Future<void> _transcribeWebAudio(
    String base64Audio,
    String filename,
    SpeechResultCallback onResult,
    SpeechStatusCallback onStatus,
  ) async {
    try {
      final text = await _transcriber.transcribeBase64Audio(
        base64Audio: base64Audio,
        filename: filename,
      );
      if (text.isNotEmpty) {
        onResult(text, '');
        onStatus('stopped', '');
      } else {
        onStatus(
          'error',
          'Could not transcribe speech. Please try speaking closer to the microphone.',
        );
      }
    } catch (e) {
      onStatus('error', 'Voice transcription failed: $e');
    }
  }

  static void stopListening() {
    final voice = _clinicalVoiceObject();
    if (voice == null) return;
    try {
      voice.callMethod('stopListening'.toJS);
    } catch (_) {}
  }

  static void startRecordingAudio({required SpeechStatusCallback onStatus}) {
    final voice = _clinicalVoiceObject();
    if (voice == null) {
      onStatus('unsupported', 'Microphone recording not supported.');
      return;
    }
    try {
      final statusCb = ((JSAny? status, JSAny? message) {
        onStatus(_jsToString(status), _jsToString(message));
      }).toJS;
      voice.callMethod('startRecordingAudio'.toJS, statusCb);
    } catch (e) {
      onStatus('error', e.toString());
    }
  }

  static void stopRecordingAudio({required AudioRecordingDoneCallback onDone}) {
    final voice = _clinicalVoiceObject();
    if (voice == null) {
      onDone('');
      return;
    }
    try {
      final doneCb = ((JSAny? base64Audio) {
        onDone(_jsToString(base64Audio));
      }).toJS;
      voice.callMethod('stopRecordingAudio'.toJS, doneCb);
    } catch (_) {
      onDone('');
    }
  }
}
