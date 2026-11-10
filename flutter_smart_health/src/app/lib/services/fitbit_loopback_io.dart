import 'dart:io';

Future<String?> listenForOAuthCodeLoopback() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  try {
    await for (final HttpRequest req in server) {
      final code = req.uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(
            '<h2>Fitbit connected successfully! You can close this tab.</h2>',
          );
        await req.response.close();
        return code;
      }
      req.response
        ..statusCode = 400
        ..write('<h2>Fitbit connection failed.</h2>');
      await req.response.close();
    }
  } finally {
    await server.close();
  }
  return null;
}
