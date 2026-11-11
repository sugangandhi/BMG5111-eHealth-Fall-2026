import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/wearable_models.dart';
import '../../../data/repositories/ehospital_repository.dart';
import '../../urgent_care/data/urgent_care_repository.dart';

class DashboardLiveSummary {
  const DashboardLiveSummary({
    this.isLiveSynced = false,
    this.wearableSourceLabel,
    this.heartRateBpm,
    this.bloodPressure,
    this.ecgStatus,
    this.vitalsHistoryCount = 0,
    this.stepsCount,
    this.caloriesCount,
    this.sleepHours,
    this.medicationsTotal = 0,
    this.medicationsTaken = 0,
    this.nextMedicationLabel,
    this.symptomsCount = 0,
    this.latestSymptomName,
    this.latestSymptomSeverity,
    this.latestBmi,
    this.latestBmiCategory,
    this.urgentCareQueuePosition,
    this.urgentCareWaitRange,
    this.urgentCareStatus,
  });

  final bool isLiveSynced;
  final String? wearableSourceLabel;
  final int? heartRateBpm;
  final String? bloodPressure;
  final String? ecgStatus;
  final int vitalsHistoryCount;
  final int? stepsCount;
  final int? caloriesCount;
  final double? sleepHours;
  final int medicationsTotal;
  final int medicationsTaken;
  final String? nextMedicationLabel;
  final int symptomsCount;
  final String? latestSymptomName;
  final int? latestSymptomSeverity;
  final double? latestBmi;
  final String? latestBmiCategory;
  final int? urgentCareQueuePosition;
  final String? urgentCareWaitRange;
  final String? urgentCareStatus;
}

class DashboardSummaryService {
  DashboardSummaryService({
    EHospitalRepository? ehospitalRepository,
    UrgentCareRepository? urgentCareRepository,
  }) : _ehospital = ehospitalRepository ?? EHospitalRepository(),
       _urgentCare = urgentCareRepository ?? UrgentCareRepository();

  final EHospitalRepository _ehospital;
  final UrgentCareRepository _urgentCare;

  static const _timeout = Duration(seconds: 4);

  Future<DashboardLiveSummary> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawId = prefs.get('patient_id')?.toString().trim();
    final patientId = (rawId != null && rawId.isNotEmpty) ? rawId : '1';

    final medSummary = _readMedications(prefs, patientId);
    final symptomSummary = _readSymptoms(prefs, patientId);
    final bmi = prefs.getDouble('latest_bmi_$patientId');
    final bmiCategory = prefs.getString('latest_bmi_category_$patientId');
    final activeVisitId = prefs.getInt('urgent_care.active_visit_id');

    final ecgFuture = _safeFetchTable('ecg', patientId);
    final vitalsHistoryFuture = _safeFetchTable('vitals_history', patientId);
    final wearableFuture = _safeFetchTable('wearable_vitals', patientId);
    final urgentCareFuture = _safeFetchUrgentCare(activeVisitId);

    final results = await Future.wait<dynamic>([
      ecgFuture,
      vitalsHistoryFuture,
      wearableFuture,
      urgentCareFuture,
    ]);

    final ecgList = results[0] as List<dynamic>;
    final vhList = results[1] as List<dynamic>;
    final wearableList = results[2] as List<dynamic>;
    final urgentStatus = results[3];

    String? ecgStatus;
    if (ecgList.isNotEmpty) {
      ecgList.sort(
        (a, b) => (b['recorded_on'] ?? '').toString().compareTo(
          (a['recorded_on'] ?? '').toString(),
        ),
      );
      ecgStatus = ecgList.first['ecg_result']?.toString();
    }

    int? heartRate;
    String? bloodPressure;
    if (vhList.isNotEmpty) {
      vhList.sort(
        (a, b) => (b['recorded_on'] ?? '').toString().compareTo(
          (a['recorded_on'] ?? '').toString(),
        ),
      );
      final latest = vhList.first;
      heartRate = _asIntOrNull(latest['heart_rate']);
      final bp = latest['blood_pressure']?.toString().trim();
      if (bp != null && bp.isNotEmpty) {
        bloodPressure = bp;
      }
    }

    int? steps;
    int? calories;
    double? sleepHours;
    String? latestRowSource;
    if (wearableList.isNotEmpty) {
      wearableList.sort((a, b) {
        final ra = (a['timestamp'] ?? a['recorded_on'] ?? '').toString();
        final rb = (b['timestamp'] ?? b['recorded_on'] ?? '').toString();
        final ta = DateTime.tryParse(ra)?.toUtc();
        final tb = DateTime.tryParse(rb)?.toUtc();
        if (ta != null && tb != null) {
          final cmp = tb.compareTo(ta);
          if (cmp != 0) return cmp;
        }
        return rb.compareTo(ra);
      });
      final latestWearable = wearableList.firstWhere(
        (row) =>
            row is Map &&
            (row['steps'] != null ||
                row['calories'] != null ||
                row['heart_rate'] != null ||
                row['sleep'] != null),
        orElse: () => wearableList.first,
      );
      heartRate ??= _asIntOrNull(latestWearable['heart_rate']);
      steps = _asIntOrNull(latestWearable['steps']);
      calories = _asIntOrNull(latestWearable['calories']);
      final rawSrc =
          (latestWearable is Map ? latestWearable['source'] : null)
              ?.toString()
              .trim();
      if (rawSrc != null && rawSrc.isNotEmpty) {
        latestRowSource = rawSrc;
      }
      final sleepRaw = latestWearable['sleep'];
      if (sleepRaw is num && sleepRaw > 0) {
        // Wearable tables may store minutes or hours depending on source.
        sleepHours = sleepRaw > 24 ? sleepRaw / 60.0 : sleepRaw.toDouble();
      }
    }

    final hasRemoteData = ecgList.isNotEmpty ||
        vhList.isNotEmpty ||
        wearableList.isNotEmpty ||
        urgentStatus != null;

    final wearableSourceLabel = _resolveSourceLabel(
      prefs.getString('last_wearable_source'),
      latestRowSource,
    );

    return DashboardLiveSummary(
      isLiveSynced: hasRemoteData,
      wearableSourceLabel: wearableSourceLabel,
      heartRateBpm: heartRate,
      bloodPressure: bloodPressure,
      ecgStatus: ecgStatus,
      vitalsHistoryCount: vhList.length + wearableList.length,
      stepsCount: steps,
      caloriesCount: calories,
      sleepHours: sleepHours,
      medicationsTotal: medSummary.total,
      medicationsTaken: medSummary.taken,
      nextMedicationLabel: medSummary.nextLabel,
      symptomsCount: symptomSummary.count,
      latestSymptomName: symptomSummary.latestName,
      latestSymptomSeverity: symptomSummary.latestSeverity,
      latestBmi: bmi,
      latestBmiCategory: bmiCategory,
      urgentCareQueuePosition: urgentStatus?.queueNumber,
      urgentCareWaitRange: urgentStatus?.estimatedWaitRange,
      urgentCareStatus: urgentStatus?.status,
    );
  }

  Future<List<dynamic>> _safeFetchTable(String table, String patientId) async {
    try {
      return await _ehospital
          .fetchTable(table, patientId: patientId)
          .timeout(_timeout);
    } catch (_) {
      return const [];
    }
  }

  Future<dynamic> _safeFetchUrgentCare(int? visitId) async {
    if (visitId == null) return null;
    try {
      return await _urgentCare.status(visitId).timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  ({int total, int taken, String? nextLabel}) _readMedications(
    SharedPreferences prefs,
    String patientId,
  ) {
    final raw = prefs.getString('medications_$patientId');
    if (raw == null || raw.isEmpty) {
      return (total: 0, taken: 0, nextLabel: null);
    }
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final taken = list.where((m) => m['takenToday'] == true).length;
      final untaken = list.where((m) => m['takenToday'] != true).toList();
      String? nextLabel;
      if (untaken.isNotEmpty) {
        final m = untaken.first;
        final name = m['name']?.toString().trim() ?? '';
        final time = m['time']?.toString().trim() ?? '';
        nextLabel = time.isNotEmpty ? '$name ($time)' : name;
      }
      return (total: list.length, taken: taken, nextLabel: nextLabel);
    } catch (_) {
      return (total: 0, taken: 0, nextLabel: null);
    }
  }

  ({int count, String? latestName, int? latestSeverity}) _readSymptoms(
    SharedPreferences prefs,
    String patientId,
  ) {
    final raw = prefs.getString('symptoms_$patientId');
    if (raw == null || raw.isEmpty) {
      return (count: 0, latestName: null, latestSeverity: null);
    }
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (list.isEmpty) {
        return (count: 0, latestName: null, latestSeverity: null);
      }
      list.sort(
        (a, b) => (b['timestamp'] ?? '').toString().compareTo(
          (a['timestamp'] ?? '').toString(),
        ),
      );
      final latest = list.first;
      return (
        count: list.length,
        latestName: latest['name']?.toString(),
        latestSeverity: _asIntOrNull(latest['severity']),
      );
    } catch (_) {
      return (count: 0, latestName: null, latestSeverity: null);
    }
  }

  static int? _asIntOrNull(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.round();
    if (val == null) return null;
    return double.tryParse(val.toString())?.round();
  }

  static String? _resolveSourceLabel(String? lastPref, String? latestRow) {
    final candidate = [lastPref, latestRow]
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (candidate.isEmpty) return null;
    final directLabel = WearableSource.labelFor(candidate);
    if (directLabel != candidate) return directLabel;
    final resolvedKey =
        WearableSource.fromSourceIdentifier(candidate, fallback: candidate);
    return WearableSource.labelFor(resolvedKey);
  }
}
