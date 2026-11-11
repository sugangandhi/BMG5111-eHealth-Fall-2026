import 'voice_scribe_types.dart';

export 'voice_scribe_types.dart';

class VoiceScribeService {
  static bool get isSupported => false;

  static void startListening({
    required SpeechResultCallback onResult,
    required SpeechStatusCallback onStatus,
  }) {
    onStatus(
      'unsupported',
      'Microphone dictation is unavailable on this platform.',
    );
  }

  static void stopListening() {}

  static void startRecordingAudio({required SpeechStatusCallback onStatus}) {
    onStatus(
      'unsupported',
      'Audio recording is unavailable on this platform.',
    );
  }

  static void stopRecordingAudio({required AudioRecordingDoneCallback onDone}) {
    onDone('');
  }
}
