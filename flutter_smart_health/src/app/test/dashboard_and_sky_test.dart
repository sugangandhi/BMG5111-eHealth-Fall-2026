import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_health_app/config/api_config.dart';
import 'package:smart_health_app/core/widgets/atmospheric_sky_background.dart';
import 'package:smart_health_app/data/repositories/ehospital_repository.dart';
import 'package:smart_health_app/features/dashboard/data/dashboard_summary_service.dart';
import 'package:smart_health_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:smart_health_app/features/dashboard/widgets/app_switcher_carousel.dart';
import 'package:smart_health_app/features/profile/screens/profile_screen.dart';
import 'package:smart_health_app/l10n/generated/app_localizations.dart';

class _FakeDashboardSummaryService extends DashboardSummaryService {
  _FakeDashboardSummaryService();

  @override
  Future<DashboardLiveSummary> load() async {
    return const DashboardLiveSummary(isLiveSynced: true, heartRateBpm: 72);
  }
}

class _FakeEHospitalRepository extends EHospitalRepository {
  _FakeEHospitalRepository(this.tables);

  final Map<String, List<dynamic>> tables;

  @override
  Future<List<dynamic>> fetchTable(String table, {String? patientId}) async {
    return tables[table] ?? const [];
  }
}

void main() {
  test('ApiConfig.normalizeBaseUrl formats Render, Cloudflare, and LAN hosts', () {
    expect(
      ApiConfig.normalizeBaseUrl('my-app.onrender.com/'),
      'https://my-app.onrender.com',
    );
    expect(
      ApiConfig.normalizeBaseUrl('https://my-app.onrender.com/'),
      'https://my-app.onrender.com',
    );
    expect(
      ApiConfig.normalizeBaseUrl('192.168.1.42'),
      'http://192.168.1.42:8080',
    );
    expect(
      ApiConfig.normalizeBaseUrl('192.168.1.42:9000'),
      'http://192.168.1.42:9000',
    );
  });

  test('DashboardSummaryService aggregates remote EHR and local preferences', () async {
    SharedPreferences.setMockInitialValues({
      'patient_id': '42',
      'latest_bmi_42': 23.4,
      'latest_bmi_category_42': 'Normal',
      'medications_42': jsonEncode([
        {'name': 'Metformin', 'time': '8:00 AM', 'takenToday': true},
        {'name': 'Atorvastatin', 'time': '8:00 PM', 'takenToday': false},
      ]),
      'symptoms_42': jsonEncode([
        {
          'name': 'Mild Headache',
          'severity': 2,
          'timestamp': '2026-11-10T01:00:00Z',
        },
      ]),
    });

    final service = DashboardSummaryService(
      ehospitalRepository: _FakeEHospitalRepository({
        'ecg': [
          {'recorded_on': '2026-11-10', 'ecg_result': 'Sinus Rhythm'},
        ],
        'vitals_history': [
          {
            'recorded_on': '2026-11-10',
            'heart_rate': 74,
            'blood_pressure': '118/76',
          },
        ],
        'wearable_vitals': [
          {
            'timestamp': '2026-11-10T01:30:00Z',
            'heart_rate': 75,
            'steps': 9100,
            'calories': 520,
            'sleep': 450,
          },
        ],
      }),
    );

    final summary = await service.load();
    expect(summary.isLiveSynced, isTrue);
    expect(summary.heartRateBpm, 74);
    expect(summary.bloodPressure, '118/76');
    expect(summary.ecgStatus, 'Sinus Rhythm');
    expect(summary.vitalsHistoryCount, 2);
    expect(summary.stepsCount, 9100);
    expect(summary.caloriesCount, 520);
    expect(summary.sleepHours, closeTo(7.5, 0.01));
    expect(summary.medicationsTotal, 2);
    expect(summary.medicationsTaken, 1);
    expect(summary.nextMedicationLabel, 'Atorvastatin (8:00 PM)');
    expect(summary.symptomsCount, 1);
    expect(summary.latestSymptomName, 'Mild Headache');
    expect(summary.latestSymptomSeverity, 2);
    expect(summary.latestBmi, closeTo(23.4, 0.01));
    expect(summary.latestBmiCategory, 'Normal');
  });

  testWidgets(
    'AppSwitcherCarousel removes top tag bar, expands card for mobile, binds live metrics, and cycles sky mood',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var moodCycles = 0;
      String? openedRoute;

      const summary = DashboardLiveSummary(
        isLiveSynced: true,
        heartRateBpm: 72,
        bloodPressure: '118/76',
        ecgStatus: 'Sinus Rhythm',
        vitalsHistoryCount: 15,
        stepsCount: 9200,
        caloriesCount: 510,
        sleepHours: 7.8,
        medicationsTotal: 3,
        medicationsTaken: 2,
        nextMedicationLabel: 'Lisinopril (9:00 PM)',
        symptomsCount: 1,
        latestSymptomName: 'Fatigue',
        latestSymptomSeverity: 2,
        latestBmi: 22.8,
        latestBmiCategory: 'Normal',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const AtmosphericSkyBackground(mood: SkyMood.daylight),
                AppSwitcherCarousel(
                  summary: summary,
                  skyMood: SkyMood.daylight,
                  onCycleSkyMood: () => moodCycles++,
                  onSelectApp: (route) => openedRoute = route,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Category filter name-tag chips are completely removed.
      expect(find.text('All (12)'), findsNothing);
      expect(find.text('Management (4)'), findsNothing);
      expect(find.text('Care & AI (3)'), findsNothing);
      expect(find.text('Daylight Sky'), findsNothing);

      // Card expands cleanly to fill the mobile viewport without overflowing.
      final cardSize = tester.getSize(
        find.descendant(
          of: find.byType(PageView),
          matching: find.byType(ClipRRect),
        ).first,
      );
      expect(cardSize.height, greaterThan(540));
      expect(tester.takeException(), isNull);

      // Live summary telemetry renders on the initial card.
      expect(find.text('Wearable Vitals'), findsOneWidget);
      expect(find.text('72 BPM'), findsOneWidget);
      expect(find.text('118/76'), findsOneWidget);

      await tester.tap(find.text('Wearable Vitals'));
      await tester.pump();
      expect(openedRoute, isNotNull);
      expect(openedRoute, isNotEmpty);

      // Horizontal swipe advances smoothly to the next module card.
      await tester.drag(find.byType(PageView), const Offset(-340, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      // Compact bottom-right SkyMood toggle cycles atmospheric themes.
      final skyToggle = find.byTooltip('Daylight Sky');
      expect(skyToggle, findsOneWidget);
      await tester.tap(skyToggle);
      await tester.pump();
      expect(moodCycles, 1);
    },
  );

  testWidgets(
    'PatientDashboard removes top Emergency SOS icon from AppBar and keeps switcher + Profile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PatientDashboard(summaryService: _FakeDashboardSummaryService()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.emergency_rounded), findsNothing);
      expect(find.byTooltip('Emergency SOS'), findsNothing);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'ProfileScreen exposes Emergency SOS Card and routes to /emergency',
    (tester) async {
      SharedPreferences.setMockInitialValues({'patient_id': 42});
      var openedEmergency = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/emergency': (_) {
              openedEmergency = true;
              return const Scaffold(body: Text('Emergency Screen'));
            },
          },
          home: ProfileScreen(
            fetchUsersTable: () async => [
              {
                'user_id': 42,
                'username': 'sugan',
                'email': 'sugan@example.com',
                'role': 'Patient',
                'status': 'Active',
                'created_on': '2026-01-01',
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emergencyTile = find.text('Emergency SOS Card');
      expect(emergencyTile, findsOneWidget);
      expect(find.text('Blood type, allergies, contact'), findsOneWidget);

      await tester.ensureVisible(emergencyTile);
      await tester.tap(emergencyTile);
      await tester.pumpAndSettle();

      expect(openedEmergency, isTrue);
      expect(find.text('Emergency Screen'), findsOneWidget);
    },
  );
}
