import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/wearable_models.dart';

class MobileHealthScanSnapshot {
  final List<DetectedHealthApp> apps;
  final bool isWebMode;
  final TargetPlatform targetPlatform;
  final HealthConnectSdkStatus? healthConnectStatus;
  final List<String> activeHealthHubSources;

  const MobileHealthScanSnapshot({
    required this.apps,
    required this.isWebMode,
    required this.targetPlatform,
    this.healthConnectStatus,
    this.activeHealthHubSources = const [],
  });

  List<DetectedHealthApp> get installedApps =>
      apps.where((app) => app.installed).toList();

  DetectedHealthApp? get primaryInstalledApp =>
      installedApps.isNotEmpty ? installedApps.first : (apps.isNotEmpty ? apps.first : null);
}

class MobileHealthRegistryService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.example.smart_health_app/health_apps',
  );

  final MethodChannel _channel;
  final bool? _isWebOverride;
  final TargetPlatform? _platformOverride;
  final Future<HealthConnectSdkStatus?> Function()? _hcStatusReader;
  final Health _health;

  MobileHealthRegistryService({
    MethodChannel? channel,
    bool? isWebOverride,
    TargetPlatform? platformOverride,
    Future<HealthConnectSdkStatus?> Function()? hcStatusReader,
    Health? health,
  }) : _channel = channel ?? _defaultChannel,
       _isWebOverride = isWebOverride,
       _platformOverride = platformOverride,
       _hcStatusReader = hcStatusReader,
       _health = health ?? Health();

  bool get _isWeb => _isWebOverride ?? kIsWeb;
  TargetPlatform get _platform => _platformOverride ?? defaultTargetPlatform;

  Future<HealthConnectSdkStatus?> getAndroidHealthConnectStatus() async {
    if (_isWeb || _platform != TargetPlatform.android) return null;
    if (_hcStatusReader != null) return _hcStatusReader();
    try {
      await _health.configure();
      return await _health.getHealthConnectSdkStatus();
    } catch (_) {
      return HealthConnectSdkStatus.sdkUnavailable;
    }
  }

  Future<MobileHealthScanSnapshot> detectHealthApps({
    List<String> syncedSourceKeys = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasFitbitToken =
        (prefs.getString('fitbit_access_token') ?? '').trim().isNotEmpty;
    final syncedSet = syncedSourceKeys.map((e) => e.toLowerCase()).toSet();

    if (!_isWeb && _platform == TargetPlatform.android) {
      final hcStatus = await getAndroidHealthConnectStatus();
      final apps = await _detectAndroidInstalledApps(
        hcStatus: hcStatus,
        hasFitbitToken: hasFitbitToken,
        syncedSet: syncedSet,
      );
      return MobileHealthScanSnapshot(
        apps: apps,
        isWebMode: false,
        targetPlatform: _platform,
        healthConnectStatus: hcStatus,
        activeHealthHubSources: syncedSourceKeys,
      );
    }

    if (!_isWeb && _platform == TargetPlatform.iOS) {
      final apps = _iosApps(
        hasFitbitToken: hasFitbitToken,
        syncedSet: syncedSet,
      );
      return MobileHealthScanSnapshot(
        apps: apps,
        isWebMode: false,
        targetPlatform: _platform,
        activeHealthHubSources: syncedSourceKeys,
      );
    }

    // Web / Mobile Browser PWA or Desktop preview
    final apps = _webCompatibleApps(
      platform: _platform,
      hasFitbitToken: hasFitbitToken,
      syncedSet: syncedSet,
    );
    return MobileHealthScanSnapshot(
      apps: apps,
      isWebMode: _isWeb,
      targetPlatform: _platform,
      activeHealthHubSources: syncedSourceKeys,
    );
  }

  Future<bool> openHealthConnectSettings() async {
    if (_isWeb || _platform != TargetPlatform.android) return false;
    try {
      return (await _channel.invokeMethod<bool>('openHealthConnectSettings')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openInstalledApp(String packageName) async {
    if (_isWeb || _platform != TargetPlatform.android || packageName.isEmpty) {
      return false;
    }
    try {
      return (await _channel.invokeMethod<bool>('openApp', {
            'packageName': packageName,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> installHealthConnect() async {
    if (_isWeb || _platform != TargetPlatform.android) return;
    try {
      await _health.configure();
      await _health.installHealthConnect();
    } catch (_) {}
  }

  Future<List<DetectedHealthApp>> _detectAndroidInstalledApps({
    required HealthConnectSdkStatus? hcStatus,
    required bool hasFitbitToken,
    required Set<String> syncedSet,
  }) async {
    final hcReady = hcStatus == HealthConnectSdkStatus.sdkAvailable;
    final hcNote = hcReady
        ? 'Health Connect ready'
        : hcStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired
        ? 'Health Connect update needed'
        : 'Install Health Connect to sync';

    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'detectInstalledHealthApps',
      );
      if (raw != null && raw.isNotEmpty) {
        final parsed = raw
            .whereType<Map>()
            .map((entry) {
              final map = entry.cast<Object?, Object?>();
              final sourceKey =
                  map['sourceKey']?.toString() ?? WearableSource.healthConnect;
              final installed = map['installed'] == true;
              final supportsHc = map['supportsHealthConnect'] == true;
              final isFitbit = sourceKey == WearableSource.fitbit;
              final connected =
                  syncedSet.contains(sourceKey) || (isFitbit && hasFitbitToken);
              final statusNote = installed
                  ? (supportsHc
                        ? 'Detected on phone • $hcNote'
                        : 'Detected on phone • Export CSV/ZIP to sync')
                  : (isFitbit && hasFitbitToken
                        ? 'Connected via Fitbit Cloud'
                        : 'Not installed on this phone');
              return DetectedHealthApp(
                id: map['id']?.toString() ?? sourceKey,
                sourceKey: sourceKey,
                name: map['name']?.toString() ?? WearableSource.labelFor(sourceKey),
                packageName: map['packageName']?.toString() ?? '',
                installed: installed,
                connected: connected,
                supportsHealthConnect: supportsHc,
                supportsDirectWebOAuth: isFitbit,
                detectedDynamically: map['detectedDynamically'] == true,
                statusNote: statusNote,
              );
            })
            .toList()
          ..sort((a, b) {
            if (a.installed != b.installed) return a.installed ? -1 : 1;
            if (a.connected != b.connected) return a.connected ? -1 : 1;
            return a.name.compareTo(b.name);
          });
        return parsed;
      }
    } catch (_) {
      // Fall back safely when MethodChannel is unavailable (e.g. headless unit test)
    }

    return [
      DetectedHealthApp(
        id: 'samsung_health',
        sourceKey: WearableSource.samsungHealth,
        name: 'Samsung Health',
        packageName: 'com.sec.android.app.shealth',
        installed: true,
        connected: syncedSet.contains(WearableSource.samsungHealth),
        supportsHealthConnect: true,
        statusNote: hcNote,
      ),
      DetectedHealthApp(
        id: 'health_connect',
        sourceKey: WearableSource.healthConnect,
        name: 'Health Connect',
        packageName: 'com.google.android.apps.healthdata',
        installed: hcReady,
        connected: syncedSet.contains(WearableSource.healthConnect),
        supportsHealthConnect: true,
        statusNote: hcNote,
      ),
    ];
  }

  List<DetectedHealthApp> _iosApps({
    required bool hasFitbitToken,
    required Set<String> syncedSet,
  }) {
    return [
      DetectedHealthApp(
        id: 'apple_health',
        sourceKey: WearableSource.appleHealth,
        name: 'Apple Health',
        packageName: 'com.apple.Health',
        installed: true,
        connected: syncedSet.contains(WearableSource.appleHealth),
        supportsHealthConnect: true,
        statusNote: 'Apple HealthKit built-in on iOS',
      ),
      DetectedHealthApp(
        id: 'samsung_health',
        sourceKey: WearableSource.samsungHealth,
        name: 'Samsung Health',
        packageName: 'com.sec.ios.shealth',
        installed: syncedSet.contains(WearableSource.samsungHealth),
        connected: syncedSet.contains(WearableSource.samsungHealth),
        supportsHealthConnect: false,
        statusNote: 'Import Samsung Health export or pair via HealthKit',
      ),
      DetectedHealthApp(
        id: 'fitbit',
        sourceKey: WearableSource.fitbit,
        name: 'Fitbit',
        packageName: 'com.fitbit.FitbitMobile',
        installed: hasFitbitToken || syncedSet.contains(WearableSource.fitbit),
        connected: hasFitbitToken || syncedSet.contains(WearableSource.fitbit),
        supportsHealthConnect: true,
        supportsDirectWebOAuth: true,
        statusNote: hasFitbitToken
            ? 'Fitbit OAuth connected'
            : 'Connect via Fitbit OAuth or Apple HealthKit',
      ),
      DetectedHealthApp(
        id: 'garmin',
        sourceKey: WearableSource.garmin,
        name: 'Garmin Connect',
        packageName: 'com.garmin.connect.mobile',
        installed: syncedSet.contains(WearableSource.garmin),
        connected: syncedSet.contains(WearableSource.garmin),
        supportsHealthConnect: true,
        statusNote: 'Syncs via Apple HealthKit sharing',
      ),
    ];
  }

  List<DetectedHealthApp> _webCompatibleApps({
    required TargetPlatform platform,
    required bool hasFitbitToken,
    required Set<String> syncedSet,
  }) {
    final isAndroidBrowser = platform == TargetPlatform.android;
    final isIosBrowser = platform == TargetPlatform.iOS;

    final list = <DetectedHealthApp>[
      DetectedHealthApp(
        id: 'samsung_health',
        sourceKey: WearableSource.samsungHealth,
        name: 'Samsung Health',
        packageName: 'com.sec.android.app.shealth',
        installed: isAndroidBrowser,
        connected: syncedSet.contains(WearableSource.samsungHealth),
        supportsHealthConnect: true,
        statusNote: isAndroidBrowser
            ? 'Android browser detected • Upload CSV/ZIP export here or use Android APK for 1-tap Health Connect sync'
            : 'Upload Samsung Health CSV/ZIP export into your EHR',
      ),
      DetectedHealthApp(
        id: 'health_connect',
        sourceKey: WearableSource.healthConnect,
        name: 'Health Connect',
        packageName: 'com.google.android.apps.healthdata',
        installed: isAndroidBrowser,
        connected: syncedSet.contains(WearableSource.healthConnect),
        supportsHealthConnect: true,
        statusNote: isAndroidBrowser
            ? 'Bridges Samsung Health, Google Fit, Garmin, Oura, WHOOP & Strava on Android APK'
            : 'Android system hub (native Android app) or JSON export upload',
      ),
      DetectedHealthApp(
        id: 'apple_health',
        sourceKey: WearableSource.appleHealth,
        name: 'Apple Health',
        packageName: 'com.apple.Health',
        installed: isIosBrowser,
        connected: syncedSet.contains(WearableSource.appleHealth),
        supportsHealthConnect: true,
        statusNote: isIosBrowser
            ? 'iOS browser detected • Upload export.xml/ZIP here or use iOS app for live HealthKit'
            : 'Upload Apple Health export.xml / export.zip',
      ),
      DetectedHealthApp(
        id: 'fitbit',
        sourceKey: WearableSource.fitbit,
        name: 'Fitbit',
        packageName: 'com.fitbit.FitbitMobile',
        installed: hasFitbitToken,
        connected: hasFitbitToken || syncedSet.contains(WearableSource.fitbit),
        supportsHealthConnect: true,
        supportsDirectWebOAuth: true,
        statusNote: hasFitbitToken
            ? 'Connected via Fitbit Cloud OAuth'
            : 'Connect Fitbit Cloud OAuth or upload Fitbit CSV/JSON',
      ),
      DetectedHealthApp(
        id: 'garmin',
        sourceKey: WearableSource.garmin,
        name: 'Garmin / Strava / Oura / Zepp',
        packageName: 'com.garmin.android.apps.connectmobile',
        installed: isAndroidBrowser || isIosBrowser,
        connected: syncedSet.contains(WearableSource.garmin) ||
            syncedSet.contains(WearableSource.strava) ||
            syncedSet.contains(WearableSource.oura),
        supportsHealthConnect: true,
        statusNote: 'Syncs via Android Health Connect APK or CSV/JSON export upload',
      ),
    ];

    list.sort((a, b) {
      if (a.installed != b.installed) return a.installed ? -1 : 1;
      if (a.connected != b.connected) return a.connected ? -1 : 1;
      return 0;
    });
    return list;
  }
}
