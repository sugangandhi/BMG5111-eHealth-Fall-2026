import 'dart:io';

Future<String> writeStreamToFile({
  required String path,
  required Stream<List<int>> stream,
  required int contentLength,
  void Function(double progress)? onProgress,
}) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final sink = file.openWrite();
  var received = 0;
  try {
    await for (final chunk in stream) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress((received / contentLength).clamp(0.0, 1.0));
      }
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
  return file.path;
}
