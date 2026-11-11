typedef SpeechResultCallback = void Function(
  String finalResult,
  String interimResult,
);
typedef SpeechStatusCallback = void Function(String status, String message);
typedef AudioRecordingDoneCallback = void Function(String base64Audio);
