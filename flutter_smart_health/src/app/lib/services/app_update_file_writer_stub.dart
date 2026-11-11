import 'dart:async';

Future<String> writeStreamToFile({
  required String path,
  required Stream<List<int>> stream,
  required int contentLength,
  void Function(double progress)? onProgress,
}) {
  throw UnsupportedError('APK downloads are only supported on Android.');
}
