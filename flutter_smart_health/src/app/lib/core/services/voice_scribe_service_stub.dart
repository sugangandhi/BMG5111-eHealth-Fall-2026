typedef SpeechResultCallback = void Function(String finalResult, String interimResult);
typedef SpeechStatusCallback = void Function(String status, String message);
typedef AudioRecordingDoneCallback = void Function(String base64Audio);

class VoiceScribeService {
  static bool get isSupported => false;

  static void startListening({
    required SpeechResultCallback onResult,
    required SpeechStatusCallback onStatus,
  }) {
    onStatus('unsupported', 'Live microphone speech recognition is supported in Chrome or Edge web browser.');
  }

  static void stopListening() {}

  static void startRecordingAudio({required SpeechStatusCallback onStatus}) {
    onStatus('unsupported', 'Audio recording is supported in Chrome or Edge web browser.');
  }

  static void stopRecordingAudio({required AudioRecordingDoneCallback onDone}) {
    onDone('');
  }
}
