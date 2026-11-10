import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_health_app/data/models/wearable_models.dart';
import 'package:smart_health_app/features/devices/widgets/detected_health_apps_panel.dart';
import 'package:smart_health_app/services/mobile_health_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WearableSource maps Android/iOS package names to canonical keys', () {
    expect(
      WearableSource.fromSourceIdentifier('com.sec.android.app.shealth'),
      WearableSource.samsungHealth,
    );
    expect(
      WearableSource.fromSourceIdentifier('com.garmin.android.apps.connectmobile'),
      WearableSource.garmin,
    );
    expect(
      WearableSource.fromSourceIdentifier('com.fitbit.FitbitMobile'),
      WearableSource.fitbit,
    );
    expect(
      WearableSource.fromSourceIdentifier('com.strava'),
      WearableSource.strava,
    );
    expect(
      WearableSource.fromSourceIdentifier('com.ouraring.oura'),
      WearableSource.oura,
    );
    expect(
      WearableSource.fromSourceIdentifier('com.apple.Health'),
      WearableSource.appleHealth,
    );
    expect(WearableSource.labelFor(WearableSource.samsungHealth), 'Samsung Health');
  });

  test('MobileHealthRegistryService detects installed & dynamic Android apps', () async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('test.health.apps/channel');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'detectInstalledHealthApps') {
            return [
              {
                'id': 'samsung_health',
                'sourceKey': 'samsung_health',
                'name': 'Samsung Health',
                'packageName': 'com.sec.android.app.shealth',
                'installed': true,
                'supportsHealthConnect': true,
                'detectedDynamically': false,
              },
              {
                'id': 'garmin',
                'sourceKey': 'garmin',
                'name': 'Garmin Connect',
                'packageName': 'com.garmin.android.apps.connectmobile',
                'installed': false,
                'supportsHealthConnect': true,
                'detectedDynamically': false,
              },
              {
                'id': 'com.custom.partner',
                'sourceKey': 'health_connect',
                'name': 'Custom Cardio Tracker',
                'packageName': 'com.custom.partner',
                'installed': true,
                'supportsHealthConnect': true,
                'detectedDynamically': true,
              },
            ];
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final service = MobileHealthRegistryService(
      channel: channel,
      isWebOverride: false,
      platformOverride: TargetPlatform.android,
      hcStatusReader: () async => HealthConnectSdkStatus.sdkAvailable,
    );

    final snapshot = await service.detectHealthApps(
      syncedSourceKeys: const [WearableSource.samsungHealth],
    );

    expect(snapshot.installedApps.map((e) => e.name), containsAll([
      'Samsung Health',
      'Custom Cardio Tracker',
    ]));
    expect(snapshot.apps.first.name, anyOf('Custom Cardio Tracker', 'Samsung Health'));
    final samsung = snapshot.apps.firstWhere(
      (a) => a.sourceKey == WearableSource.samsungHealth,
    );
    expect(samsung.connected, isTrue);
    expect(samsung.installed, isTrue);
    expect(snapshot.healthConnectStatus, HealthConnectSdkStatus.sdkAvailable);
  });

  test('MobileHealthRegistryService surfaces Android PWA apps in browser mode', () async {
    SharedPreferences.setMockInitialValues({});
    final service = MobileHealthRegistryService(
      isWebOverride: true,
      platformOverride: TargetPlatform.android,
    );

    final snapshot = await service.detectHealthApps();
    expect(snapshot.isWebMode, isTrue);
    expect(
      snapshot.apps.first.sourceKey,
      WearableSource.samsungHealth,
    );
    expect(
      snapshot.apps.any((a) => a.sourceKey == WearableSource.healthConnect),
      isTrue,
    );
  });

  testWidgets('DetectedHealthAppsPanel renders detected apps and fires callbacks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DetectedHealthApp? syncedApp;
    var importTapped = false;

    const samsung = DetectedHealthApp(
      id: 'samsung_health',
      sourceKey: WearableSource.samsungHealth,
      name: 'Samsung Health',
      packageName: 'com.sec.android.app.shealth',
      installed: true,
      connected: true,
      supportsHealthConnect: true,
      statusNote: 'Detected on phone • Health Connect ready',
    );
    const snapshot = MobileHealthScanSnapshot(
      apps: [samsung],
      isWebMode: false,
      targetPlatform: TargetPlatform.android,
      healthConnectStatus: HealthConnectSdkStatus.sdkAvailable,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DetectedHealthAppsPanel(
              snapshot: snapshot,
              loading: false,
              busy: false,
              activeSyncSource: null,
              lastActionMessage: null,
              onRefreshScan: () {},
              onSyncApp: (app) => syncedApp = app,
              onOpenApp: (_) {},
              onOpenHealthConnectSettings: () {},
              onConnectFitbit: () {},
              onImportExportFile: () => importTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Detected Mobile Health Apps'), findsOneWidget);
    expect(find.text('Samsung Health'), findsOneWidget);
    expect(find.text('SYNCED'), findsOneWidget);

    await tester.tap(find.text('Sync'));
    await tester.pump();
    expect(syncedApp?.sourceKey, WearableSource.samsungHealth);

    await tester.tap(
      find.text('Import Samsung / Apple / Fitbit Export (CSV, XML, ZIP)'),
    );
    await tester.pump();
    expect(importTapped, isTrue);
  });
}
