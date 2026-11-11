import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/wearable_models.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/e_hospital_service.dart';
import '../../../services/health_export_picker.dart';
import '../../../services/mobile_health_registry_service.dart';
import '../../../services/wearable_sync_service.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/app_theme.dart';
import '../../sleep/widgets/sleep_analysis_view.dart';
import '../presentation/vitals_styles.dart';
import '../widgets/vitals_clinical_reference_card.dart';
import '../widgets/vitals_disclaimer_banner.dart';
import '../widgets/vitals_metric_chart_card.dart';
import '../widgets/vitals_metric_tab_row.dart';
import '../widgets/vitals_range_filter.dart';
import '../widgets/vitals_sync_banner.dart';
import '../widgets/vitals_warning_banner.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  List<FlSpot> stepSpots = [];
  List<FlSpot> calorieSpots = [];
  List<FlSpot> heartRateSpots = [];
  List<FlSpot> sleepSpots = [];
  List<FlSpot> stressSpots = [];
  List<String> timeLabels = [];
  bool isLoading = true;
  int selectedIndex = 0;
  String currentPatientId = "";
  List<dynamic> _rawFilteredData = [];
  List<dynamic> _rangedFilteredData = [];
  int _rangeDays = 0; // 7, 14, 30, 0 = All
  String? _ecgResult;
  double _liveBaselineHR = 72.0;
  String _liveBaselineBP = "120/80";
  bool _hasZeroHR = false;

  // Multi-platform mobile health sync state
  bool _syncingHealth = false;
  String? _lastSyncStatus;
  final WearableSyncService _wearableSyncService = WearableSyncService();
  final MobileHealthRegistryService _healthRegistry =
      MobileHealthRegistryService();
  List<DetectedHealthApp> _detectedApps = const [];
  String? _lastWearableSource;

  // AI summaries keyed by tab index (0=Steps,1=Cal,2=HR,3=Sleep)
  final Map<int, String?> _aiSummaries = {};
  bool _aiGenerating = false;
  final Set<int> _annotatedStressIndices = {};

  String get _clinicalECG => _ecgResult ?? "Unknown";

  static const _tabs = [
    VitalsMetricTabData(
      icon: Icons.directions_walk,
      label: "Steps",
      color: Colors.blue,
    ),
    VitalsMetricTabData(
      icon: Icons.local_fire_department,
      label: "Calories",
      color: Colors.orange,
    ),
    VitalsMetricTabData(
      icon: Icons.favorite_border,
      label: "Heart Rate",
      color: Colors.red,
    ),
    VitalsMetricTabData(
      icon: Icons.bedtime_outlined,
      label: "Sleep",
      color: Color(0xFF4F46E5),
    ),
    VitalsMetricTabData(
      icon: Icons.psychology_outlined,
      label: "Stress",
      color: Color(0xFFC2185B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _detectHealthApps();
  }

  Future<void> _detectHealthApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final synced = prefs.getStringList('synced_wearable_sources') ?? const [];
      final lastSource = prefs.getString('last_wearable_source');
      final snap = await _healthRegistry.detectHealthApps(
        syncedSourceKeys: synced,
      );
      if (mounted) {
        setState(() {
          _detectedApps = snap.apps;
          _lastWearableSource = lastSource;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    // Use prefs.get() to handle patient_id stored as either int or String
    final Object? rawId = prefs.get("patient_id");
    final String searchId = (rawId != null && rawId.toString().trim().isNotEmpty) ? rawId.toString().trim() : "1";

    String? ecgResult;
    try {
      final ecgList = await EHospitalService.fetchTable(
        "ecg",
        patientId: searchId,
      );
      if (ecgList.isNotEmpty) {
        ecgList.sort(
          (a, b) => (b["recorded_on"] ?? "").compareTo(a["recorded_on"] ?? ""),
        );
        ecgResult = ecgList.first["ecg_result"]?.toString();
      }
    } catch (_) {}

    double liveHR = 72.0;
    String liveBP = "120/80";
    try {
      final vhList = await EHospitalService.fetchTable(
        "vitals_history",
        patientId: searchId,
      );
      if (vhList.isNotEmpty) {
        vhList.sort(
          (a, b) => (b["recorded_on"] ?? "").toString().compareTo(
            (a["recorded_on"] ?? "").toString(),
          ),
        );
        final latest = vhList.first;
        final hrVal = latest["heart_rate"];
        final bpVal = latest["blood_pressure"];
        if (hrVal != null)
          liveHR = (hrVal is num)
              ? hrVal.toDouble()
              : double.tryParse(hrVal.toString()) ?? 72.0;
        if (bpVal != null && bpVal.toString().isNotEmpty)
          liveBP = bpVal.toString();
      }
    } catch (_) {}

    List<dynamic> filteredData = [];
    try {
      final List<dynamic> rawData = await EHospitalService.fetchTable(
        "wearable_vitals",
        patientId: searchId,
      );
      filteredData = rawData
          .where(
            (item) => item is Map && item['patient_id']?.toString() == searchId,
          )
          .toList();
      filteredData.sort((a, b) {
        final ta = _parseWearableTimestamp(a)?.toUtc();
        final tb = _parseWearableTimestamp(b)?.toUtc();
        if (ta != null && tb != null) {
          final cmp = ta.compareTo(tb);
          if (cmp != 0) return cmp;
        }
        return _timestampOf(a).compareTo(_timestampOf(b));
      });
    } catch (_) {}

    if (mounted) {
      setState(() {
        currentPatientId = searchId;
        _ecgResult = ecgResult;
        _liveBaselineHR = liveHR;
        _liveBaselineBP = liveBP;
        _rawFilteredData = filteredData;
        isLoading = false;
      });
      _applyRange(triggerAI: true);
    }
  }

  void _applyRange({bool triggerAI = false}) {
    final latest = _latestWearableTimestamp(_rawFilteredData);
    final anchor = latest ?? DateTime.now();
    final cutoff = _rangeDays > 0
        ? anchor.subtract(Duration(days: _rangeDays))
        : DateTime(2000);

    final ranged = _rawFilteredData.where((d) {
      try {
        final ts = _parseWearableTimestamp(d);
        return ts == null || !ts.isBefore(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();

    List<FlSpot> sSpots = [],
        cSpots = [],
        hrSpots = [],
        slSpots = [],
        stSpots = [];
    List<String> labels = [];
    bool hasZero = false;
    final annotated = <int>{};

    for (int i = 0; i < ranged.length; i++) {
      final d = ranged[i];
      final s = double.tryParse(d['steps'].toString()) ?? 0.0;
      final c = double.tryParse(d['calories'].toString()) ?? 0.0;
      final hr = double.tryParse(d['heart_rate'].toString()) ?? 0.0;
      final sl = double.tryParse(d['sleep'].toString()) ?? 0.0;
      final stress = double.tryParse(d['stress_score'].toString()) ?? 0.0;
      if (hr == 0.0) hasZero = true;
      sSpots.add(FlSpot(i.toDouble(), s));
      cSpots.add(FlSpot(i.toDouble(), c));
      hrSpots.add(FlSpot(i.toDouble(), hr));
      slSpots.add(FlSpot(i.toDouble(), sl));
      stSpots.add(FlSpot(i.toDouble(), stress));
      if ((d['annotation'] ?? '').toString().trim().isNotEmpty) {
        annotated.add(i);
      }
      final ts = _parseWearableTimestamp(d);
      labels.add(
        ts == null ? "" : DateFormat('MM/dd HH:mm').format(ts.toLocal()),
      );
    }

    if (mounted) {
      setState(() {
        stepSpots = sSpots;
        calorieSpots = cSpots;
        heartRateSpots = hrSpots;
        sleepSpots = slSpots;
        stressSpots = stSpots;
        _rangedFilteredData = ranged;
        timeLabels = labels;
        _annotatedStressIndices
          ..clear()
          ..addAll(annotated);
        _hasZeroHR = hasZero;
        if (triggerAI) {
          _aiSummaries.clear();
          _aiGenerating = false;
        }
      });
      if (triggerAI) _generateAllSummaries();
    }
  }

  // AI summaries
  Future<void> _generateAllSummaries() async {
    if (mounted)
      setState(() {
        _aiGenerating = true;
        _aiSummaries.clear();
      });

    await BackendApiService.syncModelStatus();

    const tabNames = ["Steps", "Active Calories", "Heart Rate", "Sleep"];
    const units = ["steps", "kcal", "bpm", "hrs"];
    const normalRanges = [
      "5,000-15,000 steps/day",
      "300-800 kcal/day",
      "60-100 bpm",
      "7-9 hrs/night",
    ];

    final allSpots = [stepSpots, calorieSpots, heartRateSpots, sleepSpots];

    for (int i = 0; i < 4; i++) {
      final spots = allSpots[i];
      final nonZero = spots.map((s) => s.y).where((v) => v > 0).toList();
      final latest = spots.isNotEmpty ? spots.last.y : 0.0;
      final avg = nonZero.isNotEmpty
          ? nonZero.reduce((a, b) => a + b) / nonZero.length
          : 0.0;
      final max = nonZero.isNotEmpty
          ? nonZero.reduce((a, b) => a > b ? a : b)
          : 0.0;
      final zeroCount = spots.length - nonZero.length;
      final hrNote = i == 2 && _liveBaselineHR > 0
          ? "\n- Clinical baseline HR from hospital records: ${_liveBaselineHR.toInt()} bpm"
          : "";

      try {
        final response = await BackendApiService.vitalsSummary(
          patientId: currentPatientId,
          metric: tabNames[i],
          latest: latest,
          average: avg,
          peak: max,
          zeroCount: zeroCount,
          totalCount: spots.length,
          unit: units[i],
          healthyRange: normalRanges[i],
          clinicalNote: hrNote.trim().isEmpty ? null : hrNote.trim(),
        );
        if (mounted) setState(() => _aiSummaries[i] = response.trim());
      } catch (_) {
        if (mounted)
          setState(
            () => _aiSummaries[i] =
                "Unable to generate insight for ${tabNames[i]}.",
          );
      }
    }

    if (mounted) setState(() => _aiGenerating = false);
  }

  Future<void> _generateStressAnalysis() async {
    if (_aiGenerating || currentPatientId.isEmpty) return;
    setState(() {
      _aiGenerating = true;
      _aiSummaries.remove(4);
    });
    try {
      final text = await BackendApiService.stressAnalysis(
        patientId: currentPatientId,
      );
      if (mounted) setState(() => _aiSummaries[4] = text.trim());
    } catch (e) {
      if (mounted) {
        setState(
          () => _aiSummaries[4] = 'Unable to generate stress insight: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _aiGenerating = false);
    }
  }

  void _onStressSpotTap(int index) {
    if (index < 0 || index >= _rangedFilteredData.length) return;
    final row = _rangedFilteredData[index];
    if (row is! Map) return;
    final vitalId = row['vital_id'];
    if (vitalId == null) return;
    final controller = TextEditingController(
      text: (row['annotation'] ?? '').toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stress annotation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What was happening around this time?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save note'),
                onPressed: () async {
                  final text = controller.text.trim();
                  await EHospitalService.updateStressAnnotation(
                    vitalId: vitalId,
                    annotation: text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setState(() {
                      row['annotation'] = text;
                      if (text.isEmpty) {
                        _annotatedStressIndices.remove(index);
                      } else {
                        _annotatedStressIndices.add(index);
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stress note saved')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Universal Mobile Health Sync (Samsung Health, Health Connect, Apple Health, Fitbit, etc.)
  Future<void> _syncFromMobileHealth({String? preferredSourceKey}) async {
    final providerLabel = preferredSourceKey != null
        ? WearableSource.labelFor(preferredSourceKey)
        : 'mobile health app';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Syncing $providerLabel data...'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    setState(() {
      _syncingHealth = true;
      _lastSyncStatus = null;
    });

    try {
      final targetPid = (currentPatientId.trim().isNotEmpty) ? currentPatientId.trim() : "1";
      final result = await _wearableSyncService.syncPlatformHealth(
        patientId: targetPid,
        preferredSourceKey: preferredSourceKey,
      );

      var message = result.message;
      if (result.success) {
        try {
          final uploadedStress = await _wearableSyncService
              .syncRecentStressFromPlatformHealth(patientId: targetPid);
          if (uploadedStress > 0) {
            message = '${result.message} Stress: $uploadedStress hrs.';
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _syncingHealth = false;
          _lastSyncStatus = message;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: result.success ? Colors.green : null,
            ),
          );
        if (result.success) {
          _loadData();
          _detectHealthApps();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _syncingHealth = false;
          _lastSyncStatus = "Sync error: $e";
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$providerLabel sync error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  Future<void> _importExportFromVitals({String? providerHint}) async {
    setState(() {
      _syncingHealth = true;
      _lastSyncStatus = null;
    });
    try {
      final targetPid = (currentPatientId.trim().isNotEmpty) ? currentPatientId.trim() : "1";
      final result = await pickAndImportHealthExport(
        syncService: _wearableSyncService,
        patientId: targetPid,
        providerHint: providerHint,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() => _syncingHealth = false);
        return;
      }
      final providerLabel = WearableSource.labelFor(result.detectedProvider);
      final msg =
          'Synced ${result.recordsIngested} day(s) from $providerLabel (${result.acceptedMetrics.join(", ")}).';
      setState(() {
        _syncingHealth = false;
        _lastSyncStatus = msg;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      _loadData();
      _detectHealthApps();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncingHealth = false;
        _lastSyncStatus = 'Import error: $e';
      });
    }
  }

  void _handleSheetAppAction(DetectedHealthApp app) {
    if (kIsWeb && !app.connected && !app.supportsDirectWebOAuth) {
      _importExportFromVitals(providerHint: app.sourceKey);
      return;
    }
    _syncFromMobileHealth(preferredSourceKey: app.sourceKey);
  }

  void _showHealthAppSyncSheet() {
    final apps = _detectedApps;
    DetectedHealthApp? primaryApp;
    if (_lastWearableSource != null) {
      for (final app in apps) {
        if (app.sourceKey == _lastWearableSource &&
            app.sourceKey != 'health_connect' &&
            app.sourceKey != 'apple_health') {
          primaryApp = app;
          break;
        }
      }
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect & Sync Mobile Health Apps',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Real connections only: sync natively on Android APK / iOS HealthKit, connect Fitbit Cloud, or import exported CSV/XML/ZIP files.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.sync_rounded, color: AppColors.primary, size: 20),
                ),
                title: Text(
                  primaryApp != null
                      ? 'Sync ${primaryApp.name} (Primary)'
                      : 'Sync Real Connected Source',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  primaryApp != null
                      ? 'Locked to ${primaryApp.name} only (avoids mixing other apps)'
                      : 'Health Connect (Android APK), HealthKit (iOS), or Fitbit OAuth',
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _syncFromMobileHealth(
                      preferredSourceKey: primaryApp?.sourceKey,
                    );
                  },
                  child: const Text('Sync'),
                ),
              ),
              if (apps.isNotEmpty) ...[
                const Divider(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView(
                    shrinkWrap: true,
                    children: (apps.any((a) => a.installed)
                            ? apps.where((a) => a.installed)
                            : apps)
                        .map((app) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primarySoft,
                          child: Icon(
                            app.installed
                                ? Icons.check_circle_outline
                                : Icons.watch_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          app.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          app.statusNote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleSheetAppAction(app);
                          },
                          child: Text(app.connected || !kIsWeb ? 'Sync' : 'Upload'),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.upload_file_rounded, color: AppColors.primary),
                title: const Text(
                  'Import Health Data Export',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Samsung Health, Google Fit, Apple Health or Fitbit (.csv, .xml, .json, .zip)',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _importExportFromVitals();
                },
              ),
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.manage_search_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Inspect Health Connect Records',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'See exact steps & calories each app currently holds in Health Connect',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showHealthConnectInspector();
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.devices_outlined, color: AppColors.primary),
                title: const Text(
                  'Open Full Health Apps Hub',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/devices');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHealthConnectInspector() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final results = await Future.wait<Map<String, dynamic>?>([
      _healthRegistry.diagnoseHealthConnect().catchError((_) => null),
      _healthRegistry
          .aggregateHealthMetrics(
            startTime: dayStart,
            endTime: now,
            packageNames: const <String>[],
          )
          .catchError((_) => null),
    ]);
    if (!mounted) return;
    final diag = results[0] ?? const <String, dynamic>{};
    final agg = results[1] ?? const <String, dynamic>{};

    final stepsByOrigin = agg['stepsByOrigin'] is Map
        ? agg['stepsByOrigin'] as Map
        : const {};
    final originLabels = agg['originLabels'] is Map
        ? agg['originLabels'] as Map
        : const {};
    final samples = agg['stepRecordSamples'] is List
        ? agg['stepRecordSamples'] as List
        : const [];
    final records24h = diag['records24hCount'] ?? 0;
    final records29d = diag['records29dCount'] ?? 0;
    final missingPerms = diag['missingCorePermissions'] is List
        ? (diag['missingCorePermissions'] as List).join(', ')
        : '';

    final originLines = stepsByOrigin.isEmpty
        ? 'No app step records in Health Connect today yet.'
        : stepsByOrigin.entries
              .map((e) {
                final pkg = e.key.toString();
                final label = originLabels[pkg]?.toString() ?? pkg;
                return '• $label ($pkg): ${e.value} steps';
              })
              .join('\n');

    final sampleLines = samples.isEmpty
        ? 'No step interval records for today.'
        : samples.map((s) => '• $s').join('\n');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Health Connect Live Data (Today)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Window: ${DateFormat('MM/dd HH:mm').format(dayStart)} -> ${DateFormat('HH:mm').format(now)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                'OS Totals (all apps): ${agg['steps'] ?? '-'} steps\n'
                'Strict post-midnight: ${agg['strictSteps'] ?? '-'} steps\n'
                'Active Calories: ${agg['activeCalories'] is num ? (agg['activeCalories'] as num).toStringAsFixed(1) : '-'} kcal\n'
                'Total Calories (incl. resting BMR): ${agg['totalCalories'] is num ? (agg['totalCalories'] as num).toStringAsFixed(1) : '-'} kcal\n'
                'HC Records (24h / 29d): $records24h / $records29d',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              if (missingPerms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Missing permissions: $missingPerms',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Steps by Source App:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(originLines, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              const Text(
                'Raw StepsRecord Intervals Today:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(sampleLines, style: const TextStyle(fontSize: 11.5)),
              const SizedBox(height: 10),
              const Text(
                'Tip: Samsung Health syncs Watch/phone totals to Health Connect periodically (not every second). Opening Samsung Health Home and pulling down to refresh pushes latest steps into Health Connect.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                _healthRegistry.openInstalledApp('com.sec.android.app.shealth'),
            child: const Text('Open Samsung Health'),
          ),
          TextButton(
            onPressed: () => _healthRegistry.openHealthConnectSettings(),
            child: const Text('HC Permissions'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Log Vitals to eHospital
  void _showLogVitalsSheet() {
    final l10n = context.l10n;
    final hrCtrl = TextEditingController();
    final stCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final slCtrl = TextEditingController();
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.upload_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.logVitalsTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        l10n.wearableVitalsEndpointLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _logField(
                      hrCtrl,
                      l10n.heartRateBpmLabel,
                      Icons.favorite_border,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _logField(
                      stCtrl,
                      l10n.stepsInputLabel,
                      Icons.directions_walk,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _logField(
                      calCtrl,
                      l10n.caloriesInputLabel,
                      Icons.local_fire_department_outlined,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _logField(
                      slCtrl,
                      l10n.sleepHoursInputLabel,
                      Icons.bedtime_outlined,
                      Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    sending ? l10n.sendingButton : l10n.sendToEHospitalButton,
                  ),
                  onPressed: sending
                      ? null
                      : () async {
                          final hr = int.tryParse(hrCtrl.text.trim()) ?? 0;
                          final st = int.tryParse(stCtrl.text.trim()) ?? 0;
                          final cal = int.tryParse(calCtrl.text.trim()) ?? 0;
                          final sl = int.tryParse(slCtrl.text.trim()) ?? 0;
                          if (hr == 0 && st == 0 && cal == 0 && sl == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.enterAtLeastOneValue),
                              ),
                            );
                            return;
                          }
                          setS(() => sending = true);
                          await _wearableSyncService.uploadManual(
                            patientId: currentPatientId,
                            heartRate: hr,
                            steps: st,
                            calories: cal,
                            sleep: sl,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.vitalsSavedMessage),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData(); // refresh chart
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    Color color,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return VitalsDisclaimerBanner(text: context.l10n.trendDisclaimer);
  }

  String _timestampOf(dynamic item) {
    if (item is! Map) return "";
    return (item['timestamp'] ?? item['recorded_on'] ?? "").toString();
  }

  DateTime? _parseWearableTimestamp(dynamic item) {
    final value = _timestampOf(item);
    if (value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  DateTime? _latestWearableTimestamp(List<dynamic> rows) {
    DateTime? latest;
    for (final row in rows) {
      final ts = _parseWearableTimestamp(row);
      if (ts == null) continue;
      if (latest == null || ts.isAfter(latest)) latest = ts;
    }
    return latest;
  }

  Widget _buildSyncBanner() {
    return VitalsSyncBanner(
      syncing: _syncingHealth,
      status: _lastSyncStatus,
      syncingLabel: context.l10n.syncingAppleWatch,
      onDismiss: () => setState(() => _lastSyncStatus = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vitalSignsTitle),
        actions: [
          // Health Apps & Devices Hub
          IconButton(
            icon: const Icon(Icons.devices_outlined),
            tooltip: l10n.deviceManagerTooltip,
            onPressed: () => Navigator.pushNamed(context, "/devices"),
          ),
          // Open detected health apps sync sheet or sync active platform hub
          _syncingHealth
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: l10n.syncFromAppleWatchTooltip,
                  onPressed: _showHealthAppSyncSheet,
                ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.logVitalsManuallyTooltip,
            onPressed: _showLogVitalsSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _syncingHealth ? null : _showHealthAppSyncSheet,
        backgroundColor: AppColors.primary,
        icon: _syncingHealth
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.health_and_safety_rounded, color: Colors.white),
        label: Text(
          _syncingHealth ? l10n.syncingShort : l10n.syncAppleWatchButton,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? const LoadingStateView()
          : SingleChildScrollView(
              padding: VitalsStyles.bodyPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDisclaimerBanner(),
                  _buildSyncBanner(),
                  _buildClinicalCard(),
                  const SizedBox(height: 24),
                  _buildTabRow(),
                  const SizedBox(height: 12),
                  _buildRangeFilter(),
                  const SizedBox(height: 16),
                  _buildChartCard(),
                  if (selectedIndex == 3) ...[
                    const SizedBox(height: 16),
                    const SleepAnalysisView(),
                  ],
                  if (selectedIndex == 4) ...[
                    const SizedBox(height: 16),
                    _buildStressActions(),
                    const SizedBox(height: 16),
                    _buildStressTrendCard(),
                  ],
                  const SizedBox(height: 16),
                  if (_hasZeroHR) _buildWarningBanner(),
                ],
              ),
            ),
    );
  }

  // Clinical Reference Card
  Widget _buildClinicalCard() {
    Color ecgColor;
    switch (_clinicalECG.toLowerCase()) {
      case "abnormal":
        ecgColor = Colors.red;
        break;
      case "borderline":
        ecgColor = Colors.orange;
        break;
      default:
        ecgColor = Colors.green;
    }

    final l10n = context.l10n;
    return VitalsClinicalReferenceCard(
      title: l10n.clinicalReferenceTitle,
      sourceLabel: l10n.eHospitalSourceLabel,
      stats: [
        VitalsClinicalStatData(
          label: l10n.ecgShortLabel,
          value: _clinicalECG,
          icon: Icons.show_chart,
          color: ecgColor,
        ),
        VitalsClinicalStatData(
          label: l10n.heartRateTitle,
          value: '${_liveBaselineHR.toInt()} BPM',
          icon: Icons.favorite,
          color: Colors.redAccent,
        ),
        VitalsClinicalStatData(
          label: l10n.bloodPressureLabel,
          value: _liveBaselineBP,
          icon: Icons.water_drop_outlined,
          color: Colors.lightBlueAccent,
        ),
      ],
    );
  }

  // Time range filter
  Widget _buildRangeFilter() {
    const options = [
      VitalsRangeOption(label: "7D", days: 7),
      VitalsRangeOption(label: "14D", days: 14),
      VitalsRangeOption(label: "30D", days: 30),
      VitalsRangeOption(label: "All", days: 0),
    ];
    return VitalsRangeFilter(
      selectedDays: _rangeDays,
      options: options,
      onSelected: (days) {
        if (_rangeDays == days) return;
        setState(() {
          _rangeDays = days;
          _aiSummaries.clear();
        });
        _applyRange(triggerAI: true);
      },
    );
  }

  // Custom pill tab row
  Widget _buildTabRow() {
    return VitalsMetricTabRow(
      selectedIndex: selectedIndex,
      tabs: _tabs,
      onSelected: (index) => setState(() => selectedIndex = index),
    );
  }

  // Chart card
  Widget _buildChartCard() {
    final l10n = context.l10n;
    // Per-metric config
    const units = ["steps", "kcal", "bpm", "hrs", "score"];
    const maxYs = [20000.0, 800.0, 160.0, 12.0, 100.0];
    const normalMins = [5000.0, 300.0, 60.0, 7.0, 0.0];
    const normalMaxs = [15000.0, 600.0, 100.0, 9.0, 40.0];
    final descriptions = [
      l10n.stepsMetricDescription,
      l10n.caloriesMetricDescription,
      l10n.heartRateMetricDescription,
      l10n.sleepMetricDescription,
      'Estimated 0-100 wellness stress score from HRV, resting heart rate, and respiratory rate.',
    ];
    final dataNotes = [
      "",
      "",
      l10n.clinicalBaselineNote,
      l10n.wearableSleepMissingNote,
      'Tap a stress point to add context. Lower scores generally indicate calmer readings.',
    ];

    final tab = _tabs[selectedIndex];
    final spots = [
      stepSpots,
      calorieSpots,
      heartRateSpots,
      sleepSpots,
      stressSpots,
    ][selectedIndex];
    final unit = units[selectedIndex];
    final normalMin = normalMins[selectedIndex];
    final normalMax = normalMaxs[selectedIndex];

    return VitalsMetricChartCard(
      tab: tab,
      spots: spots,
      timeLabels: timeLabels,
      selectedIndex: selectedIndex,
      unit: unit,
      maxY: maxYs[selectedIndex],
      normalMin: normalMin,
      normalMax: normalMax,
      description: descriptions[selectedIndex],
      dataNote: dataNotes[selectedIndex],
      liveBaselineHeartRate: _liveBaselineHR,
      aiText: _aiSummaries[selectedIndex],
      aiGenerating: _aiGenerating,
      aiInsightLabel: l10n.aiInsightLabel,
      generatingLabel: l10n.generatingInsight,
      emptyInsightLabel: l10n.syncDataToGenerateInsight,
      normalRangeLabel: l10n.normalRangeLabel,
      latestLabel: l10n.latestMetricLabel,
      averageLabel: l10n.averageMetricLabel,
      minLabel: l10n.minMetricLabel,
      maxLabel: l10n.maxMetricLabel,
      noDataLabel: l10n.noDataStatusLabel,
      lowLabel: l10n.lowStatusLabel,
      highLabel: l10n.highStatusLabel,
      normalLabel: l10n.normalStatusLabel,
      onSpotTap: selectedIndex == 4 ? _onStressSpotTap : null,
      annotatedIndices: selectedIndex == 4 ? _annotatedStressIndices : const {},
    );
  }

  Widget _buildStressActions() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _aiGenerating ? null : _generateStressAnalysis,
        icon: _aiGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_outlined),
        label: Text(_aiGenerating ? 'Analyzing stress...' : 'Analyze stress'),
      ),
    );
  }

  Widget _buildStressTrendCard() {
    final trend = _buildStressTrend();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: VitalsStyles.metricCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-day stress trend',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (trend.isEmpty)
            const Text(
              'No recent stress scores yet.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: trend
                  .map(
                    (point) => Chip(
                      label: Text(
                        '${point.$1}: ${point.$2.toStringAsFixed(0)}',
                      ),
                      backgroundColor: _tabs[4].color.withValues(alpha: 0.08),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  List<(String, double)> _buildStressTrend() {
    final byDay = <String, List<double>>{};
    for (final row in _rawFilteredData) {
      if (row is! Map) continue;
      final value = double.tryParse(row['stress_score'].toString());
      final ts = _parseWearableTimestamp(row);
      if (value == null || value <= 0 || ts == null) continue;
      final day = DateFormat('E').format(ts.toLocal());
      byDay.putIfAbsent(day, () => []).add(value);
    }
    return byDay.entries.map((entry) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return (entry.key, avg);
    }).toList();
  }

  Widget _buildWarningBanner() {
    return VitalsWarningBanner(text: context.l10n.vitalsSyncIssue);
  }
}
