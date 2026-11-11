import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_health_app/config/api_config.dart';
import 'package:smart_health_app/core/widgets/atmospheric_sky_background.dart';
import 'package:smart_health_app/data/repositories/ehospital_repository.dart';
import 'package:smart_health_app/features/dashboard/data/dashboard_layout_preferences.dart';
import 'package:smart_health_app/features/dashboard/data/dashboard_summary_service.dart';
import 'package:smart_health_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:smart_health_app/features/dashboard/widgets/app_switcher_carousel.dart';
import 'package:smart_health_app/features/dashboard/widgets/ask_ai_shortcut_pill.dart';
import 'package:smart_health_app/features/dashboard/widgets/dashboard_grid_card.dart';
import 'package:smart_health_app/features/dashboard/widgets/module_illustration_banner.dart';
import 'package:smart_health_app/features/profile/screens/profile_screen.dart';
import 'package:smart_health_app/features/settings/screens/settings_screen.dart';
import 'package:smart_health_app/l10n/generated/app_localizations.dart';
import 'package:smart_health_app/ui/app_colors.dart';

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

  test(
    'DashboardSummaryService sorts wearable timestamps chronologically across offsets and skips stress-only rows',
    () async {
      SharedPreferences.setMockInitialValues({'patient_id': '391'});

      final service = DashboardSummaryService(
        ehospitalRepository: _FakeEHospitalRepository({
          'ecg': const [],
          'vitals_history': const [],
          'wearable_vitals': [
            // Older row with lexicographically later wall-clock string
            {
              'timestamp': '2026-11-11T04:54:10+05:00', // 23:54Z yesterday
              'heart_rate': 73,
              'steps': 5009,
              'calories': 223,
              'sleep': null,
            },
            // Newer midnight reset row (00:33 EST = 05:33Z)
            {
              'timestamp': '2026-11-11T05:33:03.000Z',
              'heart_rate': 73,
              'steps': 0,
              'calories': 1,
              'sleep': 4.2,
            },
            // Latest stress-only bucket with null activity metrics
            {
              'timestamp': '2026-11-11T05:34:00.000Z',
              'respiratory_rate': 16.5,
              'stress_score': 32.0,
            },
          ],
        }),
      );

      final summary = await service.load();
      expect(summary.stepsCount, 0);
      expect(summary.caloriesCount, 1);
      expect(summary.sleepHours, closeTo(4.2, 0.01));
      expect(summary.heartRateBpm, 73);
    },
  );

  testWidgets(
    'AppSwitcherCarousel removes theme toggle, shows icon-only side arrows, binds live metrics, and navigates cards',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
                const AtmosphericSkyBackground(),
                AppSwitcherCarousel(
                  summary: summary,
                  onSelectApp: (route) => openedRoute = route,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Category filter name-tag chips and theme toggle are removed.
      expect(find.text('All (12)'), findsNothing);
      expect(find.text('Management (4)'), findsNothing);
      expect(find.text('Care & AI (3)'), findsNothing);
      expect(find.text('Daylight Sky'), findsNothing);
      expect(find.byTooltip('Daylight Sky'), findsNothing);
      expect(find.text('Prev'), findsNothing);
      expect(find.text('Next'), findsNothing);

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

      // Bottom left/right arrow icon buttons advance cleanly without text labels.
      final prevArrow = find.byIcon(Icons.chevron_left_rounded);
      final nextArrow = find.byIcon(Icons.chevron_right_rounded);
      expect(prevArrow, findsOneWidget);
      expect(nextArrow, findsOneWidget);

      await tester.tap(nextArrow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Vitals History'), findsOneWidget);

      await tester.tap(prevArrow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Wearable Vitals'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PatientDashboard removes top Emergency SOS and Grid icons and shows Ask AI shortcut + Profile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      var openedAssistant = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/assistant': (_) {
              openedAssistant = true;
              return const Scaffold(body: Text('Assistant Screen'));
            },
          },
          home: PatientDashboard(summaryService: _FakeDashboardSummaryService()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.emergency_rounded), findsNothing);
      expect(find.byTooltip('Emergency SOS'), findsNothing);
      expect(find.byIcon(Icons.grid_view_rounded), findsNothing);
      expect(find.byIcon(Icons.view_carousel_rounded), findsNothing);
      expect(find.byType(AskAiShortcutPill), findsOneWidget);
      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('dashboard-ask-ai-shortcut')));
      await tester.pumpAndSettle();

      expect(openedAssistant, isTrue);
      expect(find.text('Assistant Screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

  testWidgets(
    'PatientDashboard uses unified light canvas without dark sky or marketing banner',
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

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.bg);
      expect(find.byType(AtmosphericSkyBackground), findsNothing);
      expect(find.text('INTELLIGENT DIGITAL SOLUTION'), findsNothing);
      expect(find.byType(ModuleIllustrationBanner), findsWidgets);
      expect(find.byType(AppSwitcherCarousel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SettingsScreen moves Grid View Mode toggle into Settings and Home honors preference',
    (tester) async {
      SharedPreferences.setMockInitialValues({'patient_id': 42});

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final gridSwitchFinder = find.byKey(const Key('settings-grid-view-switch'));
      await tester.ensureVisible(gridSwitchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Grid View Mode'), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(tester.widget<Switch>(gridSwitchFinder).value, isFalse);

      await tester.tap(gridSwitchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(gridSwitchFinder).value, isTrue);
      expect(await DashboardLayoutPreferences.isGridViewEnabled(), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PatientDashboard(summaryService: _FakeDashboardSummaryService()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AppSwitcherCarousel), findsNothing);
      expect(find.byType(DashboardGridCard), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ModuleIllustrationBanner paints all 12 animated scenes cleanly across progress steps',
    (tester) async {
      for (final kind in DashboardModuleKind.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModuleIllustrationBanner(
                kind: kind,
                progress: 0.35,
                badgeText: kind.name,
                accentColor: AppColors.primary,
                backgroundColor: AppColors.primarySoft,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(kind.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Dashboard adapts synced health app source label and metrics dynamically',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'patient_id': '42',
        'last_wearable_source': 'fitbit',
      });
      final service = DashboardSummaryService(
        ehospitalRepository: _FakeEHospitalRepository({
          'ecg': const [],
          'vitals_history': const [],
          'wearable_vitals': [
            {
              'timestamp': '2026-11-11T07:00:00Z',
              'heart_rate': 68,
              'steps': 2410,
              'calories': 135,
              'source': 'fitbit',
            },
          ],
        }),
      );
      final fitbitSummary = await service.load();
      expect(fitbitSummary.wearableSourceLabel, 'Fitbit');
      expect(fitbitSummary.stepsCount, 2410);
      expect(fitbitSummary.heartRateBpm, 68);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppSwitcherCarousel(
              summary: fitbitSummary,
              onSelectApp: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Fitbit'), findsOneWidget);
      expect(find.text('68 BPM'), findsOneWidget);
      expect(find.text('2410 Steps'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All 12 AppSwitcherCarousel tabs render rich middle detail wells without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const summary = DashboardLiveSummary(
        isLiveSynced: true,
        wearableSourceLabel: 'Samsung Health',
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
            body: AppSwitcherCarousel(
              summary: summary,
              onSelectApp: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      const expectedHeadings = [
        'Live Telemetry Summary',
        'Recent Check-In Activity',
        'Cardio & Risk Screening',
        '7-Day Physiological Curve',
        'Sleep Stage Distribution',
        'Daily Dose Progress',
        'Comfort Severity Scale',
        'Daily 10,000-Step Goal',
        'Metabolic Range Reference',
        'Clinic Check-In Status',
        'Suggested Prompts',
        'Connected Platform Pipeline',
      ];

      for (int i = 0; i < expectedHeadings.length; i++) {
        expect(find.text(expectedHeadings[i]), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (i < expectedHeadings.length - 1) {
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 420));
        }
      }
    },
  );
}
