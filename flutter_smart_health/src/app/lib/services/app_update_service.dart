import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_update_file_writer.dart' as file_writer;

class AppVersionInfo {
  final String versionName;
  final int versionCode;

  const AppVersionInfo({
    required this.versionName,
    required this.versionCode,
  });

  String get displayLabel => 'v$versionName (build $versionCode)';
}

class AppUpdateCheckResult {
  final AppVersionInfo installed;
  final bool remoteAvailable;
  final String remoteVersionName;
  final int remoteVersionCode;
  final String? apkUrl;
  final String releaseNotes;
  final String publishedAt;
  final bool isUpdateAvailable;

  const AppUpdateCheckResult({
    required this.installed,
    required this.remoteAvailable,
    required this.remoteVersionName,
    required this.remoteVersionCode,
    required this.apkUrl,
    required this.releaseNotes,
    required this.publishedAt,
    required this.isUpdateAvailable,
  });
}

class AppUpdateInstallResult {
  final bool started;
  final bool permissionRequired;
  final String message;

  const AppUpdateInstallResult({
    required this.started,
    this.permissionRequired = false,
    required this.message,
  });
}

class AppUpdateService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.example.smart_health_app/app_updater',
  );

  final MethodChannel _channel;
  final http.Client _client;
  final bool? _isWebOverride;
  final TargetPlatform? _platformOverride;
  final String? _baseUrlOverride;

  AppUpdateService({
    MethodChannel? channel,
    http.Client? client,
    bool? isWebOverride,
    TargetPlatform? platformOverride,
    String? baseUrlOverride,
  }) : _channel = channel ?? _defaultChannel,
       _client = client ?? http.Client(),
       _isWebOverride = isWebOverride,
       _platformOverride = platformOverride,
       _baseUrlOverride = baseUrlOverride;

  bool get _isWeb => _isWebOverride ?? kIsWeb;
  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;
  bool get isAndroidNative => !_isWeb && _platform == TargetPlatform.android;

  Future<AppVersionInfo> getInstalledVersion() async {
    if (!isAndroidNative) {
      return const AppVersionInfo(versionName: '1.0.0', versionCode: 1);
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getAppVersionInfo',
      );
      if (raw != null) {
        return AppVersionInfo(
          versionName: raw['versionName']?.toString() ?? '1.0.0',
          versionCode: (raw['versionCode'] as num?)?.toInt() ?? 1,
        );
      }
    } catch (_) {}
    return const AppVersionInfo(versionName: '1.0.0', versionCode: 1);
  }

  Future<AppUpdateCheckResult> checkForUpdate() async {
    final installed = await getInstalledVersion();
    final baseUrl = _baseUrlOverride ?? ApiConfig.backendBaseUrl;
    if (!isAndroidNative || baseUrl.trim().isEmpty) {
      return AppUpdateCheckResult(
        installed: installed,
        remoteAvailable: false,
        remoteVersionName: installed.versionName,
        remoteVersionCode: installed.versionCode,
        apkUrl: null,
        releaseNotes: '',
        publishedAt: '',
        isUpdateAvailable: false,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/apk-version');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final available = decoded['available'] == true;
          final remoteCode = (decoded['version_code'] as num?)?.toInt() ?? 0;
          final remoteName =
              decoded['version_name']?.toString().trim() ?? '1.0.0';
          final apkUrl = decoded['apk_url']?.toString().trim();
          final hasNewer =
              available &&
              apkUrl != null &&
              apkUrl.isNotEmpty &&
              remoteCode > installed.versionCode;
          return AppUpdateCheckResult(
            installed: installed,
            remoteAvailable: available,
            remoteVersionName: remoteName,
            remoteVersionCode: remoteCode,
            apkUrl: apkUrl,
            releaseNotes: decoded['release_notes']?.toString() ?? '',
            publishedAt: decoded['published_at']?.toString() ?? '',
            isUpdateAvailable: hasNewer,
          );
        }
      }
    } catch (_) {}

    return AppUpdateCheckResult(
      installed: installed,
      remoteAvailable: false,
      remoteVersionName: installed.versionName,
      remoteVersionCode: installed.versionCode,
      apkUrl: null,
      releaseNotes: '',
      publishedAt: '',
      isUpdateAvailable: false,
    );
  }

  Future<AppUpdateInstallResult> downloadAndInstallUpdate(
    AppUpdateCheckResult check, {
    void Function(double progress)? onProgress,
  }) async {
    if (!isAndroidNative) {
      return const AppUpdateInstallResult(
        started: false,
        message: 'APK auto-update is only available on Android devices.',
      );
    }
    final apkUrl = check.apkUrl;
    if (apkUrl == null || apkUrl.isEmpty) {
      return const AppUpdateInstallResult(
        started: false,
        message: 'No APK download URL available for this release.',
      );
    }

    try {
      final canInstall =
          (await _channel.invokeMethod<bool>('canRequestPackageInstalls')) ??
          false;
      if (!canInstall) {
        await _channel.invokeMethod<bool>('openUnknownAppSourcesSettings');
        return const AppUpdateInstallResult(
          started: false,
          permissionRequired: true,
          message:
              'Allow "Install unknown apps" for eHospital in Android Settings, then tap Update Now again.',
        );
      }

      final updatesDir = await _channel.invokeMethod<String>('getUpdatesDir');
      if (updatesDir == null || updatesDir.isEmpty) {
        return const AppUpdateInstallResult(
          started: false,
          message: 'Unable to prepare cache folder for the APK download.',
        );
      }

      final request = http.Request('GET', Uri.parse(apkUrl));
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      if (streamed.statusCode != 200) {
        return AppUpdateInstallResult(
          started: false,
          message:
              'Failed to download APK (HTTP ${streamed.statusCode}).',
        );
      }

      final targetPath = '$updatesDir/ehospital-update-${check.remoteVersionCode}.apk';
      await file_writer.writeStreamToFile(
        path: targetPath,
        stream: streamed.stream,
        contentLength: streamed.contentLength ?? 0,
        onProgress: onProgress,
      );

      final launched =
          (await _channel.invokeMethod<bool>('installApk', {
            'path': targetPath,
          })) ??
          false;
      if (!launched) {
        return const AppUpdateInstallResult(
          started: false,
          message: 'Could not launch Android package installer for the downloaded APK.',
        );
      }
      return const AppUpdateInstallResult(
        started: true,
        message: 'Installer opened. Tap Update to finish upgrading eHospital.',
      );
    } catch (e) {
      return AppUpdateInstallResult(
        started: false,
        message: 'App update failed: $e',
      );
    }
  }
}
