import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_health_app/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('checkForUpdate flags newer remote Android build and skips web', () async {
    const channel = MethodChannel('test.app.updater/check');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getAppVersionInfo') {
            return {'versionName': '1.0.1', 'versionCode': 1};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.test/apk-version');
      return http.Response(
        jsonEncode({
          'available': true,
          'version_code': 12,
          'version_name': '1.0.12',
          'apk_url': 'https://example.test/app-release.apk',
          'release_notes': 'Automated release',
          'published_at': '2026-11-11T00:00:00Z',
        }),
        200,
      );
    });

    final androidService = AppUpdateService(
      channel: channel,
      client: client,
      isWebOverride: false,
      platformOverride: TargetPlatform.android,
      baseUrlOverride: 'https://example.test',
    );
    final check = await androidService.checkForUpdate();
    expect(check.installed.versionCode, 1);
    expect(check.remoteVersionCode, 12);
    expect(check.isUpdateAvailable, isTrue);

    final webService = AppUpdateService(
      channel: channel,
      client: client,
      isWebOverride: true,
      platformOverride: TargetPlatform.android,
      baseUrlOverride: 'https://example.test',
    );
    final webCheck = await webService.checkForUpdate();
    expect(webCheck.isUpdateAvailable, isFalse);
  });

  test('downloadAndInstallUpdate downloads APK and invokes native FileProvider installer', () async {
    const channel = MethodChannel('test.app.updater/install');
    final tempDir = await Directory.systemTemp.createTemp('apk_update_test_');
    addTearDown(() => tempDir.delete(recursive: true));

    String? installedPath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'canRequestPackageInstalls':
              return true;
            case 'getUpdatesDir':
              return tempDir.path;
            case 'installApk':
              installedPath = (call.arguments as Map)['path'] as String?;
              return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final client = MockClient((request) async {
      return http.Response.bytes([80, 75, 3, 4], 200);
    });

    final service = AppUpdateService(
      channel: channel,
      client: client,
      isWebOverride: false,
      platformOverride: TargetPlatform.android,
      baseUrlOverride: 'https://example.test',
    );
    const check = AppUpdateCheckResult(
      installed: AppVersionInfo(versionName: '1.0.1', versionCode: 1),
      remoteAvailable: true,
      remoteVersionName: '1.0.12',
      remoteVersionCode: 12,
      apkUrl: 'https://example.test/app-release.apk',
      releaseNotes: '',
      publishedAt: '',
      isUpdateAvailable: true,
    );

    final result = await service.downloadAndInstallUpdate(check);
    expect(result.started, isTrue);
    expect(installedPath, isNotNull);
    expect(await File(installedPath!).readAsBytes(), [80, 75, 3, 4]);
  });
}
