import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/widgets.dart';
import '../../../data/models/wearable_models.dart';
import '../../../l10n/l10n.dart';
import '../../../services/e_hospital_service.dart';
import '../../../services/fitbit_service.dart';
import '../../../services/health_export_picker.dart';
import '../../../services/mobile_health_registry_service.dart';
import '../../../services/wearable_sync_service.dart';
import '../../../ui/ui.dart';
import '../models/patient_device.dart';
import '../presentation/device_styles.dart';
import '../widgets/detected_health_apps_panel.dart';
import '../widgets/device_info_banner.dart';
import '../widgets/device_section_label.dart';
import '../widgets/patient_device_card.dart';
import '../widgets/simulation_progress_panel.dart';

// Lists detected mobile health apps (Samsung Health, Health Connect, Apple Health,
// Fitbit, etc.), patient sync status, export file upload, and demo simulation.
class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  final MobileHealthRegistryService _registry = MobileHealthRegistryService();
  final WearableSyncService _wearableSyncService = WearableSyncService();

  bool _loading = true;
  bool _scanningApps = true;
  bool _actionBusy = false;
  String? _activeSyncSource;
  String? _actionMessage;
  bool _actionIsError = false;
  String _currentPatientId = '1';
  MobileHealthScanSnapshot? _scanSnapshot;
  String? _errorMsg;
  List<PatientDevice> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadPatients(),
      _scanDetectedHealthApps(),
    ]);
  }

  Future<void> _scanDetectedHealthApps() async {
    if (mounted) setState(() => _scanningApps = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final pid = (prefs.get('patient_id') ?? '1').toString().trim();
      final synced = prefs.getStringList('synced_wearable_sources') ?? const [];
      final snapshot = await _registry.detectHealthApps(
        syncedSourceKeys: synced,
      );
      if (!mounted) return;
      setState(() {
        _currentPatientId = pid.isEmpty ? '1' : pid;
        _scanSnapshot = snapshot;
        _scanningApps = false;
      });
    } catch (_) {
      if (mounted) setState(() => _scanningApps = false);
    }
  }

  Future<void> _syncFromApp(DetectedHealthApp app) async {
    if (_actionBusy) return;
    setState(() {
      _actionBusy = true;
      _activeSyncSource = app.sourceKey;
      _actionMessage = 'Syncing ${app.name}...';
      _actionIsError = false;
    });

    try {
      final result = await _wearableSyncService.syncFromDetectedApp(
        patientId: _currentPatientId,
        app: app,
      );
      if (result.success) {
        await _wearableSyncService.syncRecentStressFromPlatformHealth(
          patientId: _currentPatientId,
        );
      }
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _activeSyncSource = null;
        _actionMessage = result.message;
        _actionIsError = !result.success;
      });
      await Future.wait([
        _loadPatients(),
        _scanDetectedHealthApps(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _activeSyncSource = null;
        _actionMessage = '${app.name} sync error: $e';
        _actionIsError = true;
      });
    }
  }

  Future<void> _openHealthConnectPermissions() async {
    final opened = await _registry.openHealthConnectSettings();
    if (!opened) {
      await _registry.installHealthConnect();
    }
    if (mounted) {
      await _scanDetectedHealthApps();
    }
  }

  Future<void> _openInstalledApp(DetectedHealthApp app) async {
    final opened = await _registry.openInstalledApp(app.packageName);
    if (!opened && mounted) {
      setState(() {
        _actionMessage = 'Could not launch ${app.name} (${app.packageName}).';
        _actionIsError = true;
      });
    }
  }

  Future<void> _connectFitbit() async {
    await FitbitService.connectFitbit(context);
    if (mounted) {
      await _scanDetectedHealthApps();
    }
  }

  Future<void> _importHealthExport() async {
    if (_actionBusy) return;
    setState(() {
      _actionBusy = true;
      _actionMessage = null;
      _actionIsError = false;
    });
    try {
      final result = await pickAndImportHealthExport(
        syncService: _wearableSyncService,
        patientId: _currentPatientId,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() => _actionBusy = false);
        return;
      }
      final providerLabel = WearableSource.labelFor(result.detectedProvider);
      setState(() {
        _actionBusy = false;
        _actionMessage =
            'Synced ${result.recordsIngested} day(s) from $providerLabel (${result.acceptedMetrics.join(", ")}).';
        _actionIsError = false;
      });
      await Future.wait([
        _loadPatients(),
        _scanDetectedHealthApps(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _actionMessage = 'Import failed: $e';
        _actionIsError = true;
      });
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final results = await Future.wait([
        EHospitalService.fetchTable('users'),
        EHospitalService.fetchTable('wearable_vitals'),
      ]);

      final List<dynamic> users = results[0];
      final List<dynamic> vitals = results[1];
      final Map<String, String> latestSync = {};
      final Map<String, int> recordCounts = {};

      for (final vital in vitals) {
        final patientId = (vital['patient_id'] ?? '').toString();
        recordCounts[patientId] = (recordCounts[patientId] ?? 0) + 1;
        final timestamp = (vital['timestamp'] ?? vital['recorded_on'] ?? '')
            .toString();
        if (timestamp.isNotEmpty &&
            (!latestSync.containsKey(patientId) ||
                timestamp.compareTo(latestSync[patientId]!) > 0)) {
          latestSync[patientId] = timestamp;
        }
      }

      final l10n = context.l10n;
      final list =
          users.map((user) {
            final id = (user['user_id'] ?? user['patient_id'] ?? '').toString();
            final username = user['username'] as String? ?? '';
            return PatientDevice(
              patientId: id,
              name: username.isEmpty ? l10n.patientFallbackName(id) : username,
              email: user['email'] as String? ?? '',
              lastSync: latestSync[id],
              recordCount: recordCounts[id] ?? 0,
            );
          }).toList()..sort(
            (a, b) => (int.tryParse(a.patientId) ?? 0).compareTo(
              int.tryParse(b.patientId) ?? 0,
            ),
          );

      if (mounted) {
        setState(() {
          _patients = list;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = context.l10n.assistantErrorMessage(error.toString());
        });
      }
    }
  }

  void _simulateForPatient(PatientDevice patient) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SimulateDialog(patient: patient),
    ).then((_) => _loadPatients());
  }

  String _formatSync(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      final diff = DateTime.now().difference(dt);
      final l10n = context.l10n;
      if (diff.inMinutes < 1) return l10n.justNow;
      if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
      if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
      return l10n.daysAgo(diff.inDays);
    } catch (_) {
      return isoStr;
    }
  }

  Widget _patientCard(PatientDevice patient) {
    final l10n = context.l10n;
    final hasSynced = patient.lastSync != null;
    return PatientDeviceCard(
      patient: patient,
      statusLabel: hasSynced ? l10n.connectedStatus : l10n.noDataStatus,
      metadata: l10n.patientDeviceMeta(patient.patientId, patient.email),
      lastSyncLabel: hasSynced
          ? _formatSync(patient.lastSync!)
          : l10n.neverSynced,
      recordsLabel: patient.recordCount > 0
          ? l10n.recordsCount(patient.recordCount)
          : null,
      simulateLabel: l10n.simulateButton,
      onSimulate: () => _simulateForPatient(patient),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          AppSliverHeader(
            title: l10n.deviceManagerTitle,
            icon: Icons.watch_outlined,
          ),
          if (_loading)
            SliverStateView.loading()
          else if (_errorMsg != null)
            SliverStateView.error(message: _errorMsg!)
          else
            SliverPadding(
              padding: DeviceStyles.bodyPadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  DetectedHealthAppsPanel(
                    snapshot: _scanSnapshot,
                    loading: _scanningApps,
                    busy: _actionBusy,
                    activeSyncSource: _activeSyncSource,
                    lastActionMessage: _actionMessage,
                    lastActionError: _actionIsError,
                    onRefreshScan: _scanDetectedHealthApps,
                    onSyncApp: _syncFromApp,
                    onOpenApp: _openInstalledApp,
                    onOpenHealthConnectSettings: _openHealthConnectPermissions,
                    onConnectFitbit: _connectFitbit,
                    onImportExportFile: _importHealthExport,
                  ),
                  DeviceInfoBanner(
                    title: l10n.deviceInfoTitle,
                    body: l10n.deviceInfoBody,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DeviceSectionLabel(text: l10n.patientsInDb(_patients.length)),
                  const SizedBox(height: 10),
                  ..._patients.map(_patientCard),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// The dialog owns upload progress state, while the service boundary remains EHospitalService.
class _SimulateDialog extends StatefulWidget {
  final PatientDevice patient;

  const _SimulateDialog({required this.patient});

  @override
  State<_SimulateDialog> createState() => _SimulateDialogState();
}

class _SimulateDialogState extends State<_SimulateDialog> {
  int _progress = 0;
  bool _done = false;
  String? _error;
  static const int _total = 7;
  final WearableSyncService _wearableSyncService = WearableSyncService();

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  Future<void> _runSimulation() async {
    final rng = Random();
    try {
      for (int day = _total - 1; day >= 0; day--) {
        await _wearableSyncService.uploadSimulationSample(
          patientId: widget.patient.patientId,
          heartRate: 58 + rng.nextInt(43),
          steps: 4800 + rng.nextInt(10200),
          calories: 180 + rng.nextInt(421),
          sleep: 5 + rng.nextInt(4),
        );

        if (mounted) setState(() => _progress = _total - day);
        await Future.delayed(const Duration(milliseconds: 350));
      }

      if (mounted) setState(() => _done = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.radius(AppRadii.dialog),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: DeviceStyles.simulationIconDecoration,
            child: const Icon(
              Icons.watch_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.simulatingDataTitle,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.patientNameLabel(widget.patient.name),
            style: AppTypography.caption.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.appleHealthPipeline,
            style: AppTypography.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null)
            Text(_error!, style: DeviceStyles.simulationError)
          else
            SimulationProgressPanel(
              done: _done,
              progress: _progress,
              total: _total,
              statusText: _done
                  ? l10n.uploadCompleteMessage(_total)
                  : l10n.uploadingDayMessage(_progress, _total),
            ),
        ],
      ),
      actions: _error != null
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.closeButton),
              ),
            ]
          : null,
    );
  }
}
