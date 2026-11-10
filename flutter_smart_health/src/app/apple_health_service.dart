import 'package:health/health.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppleHealthService {
  static final _health = Health();

  static Future<Map<String, dynamic>> getLatestVitals() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final start = now.subtract(const Duration(hours: 24));

    final types = [
      HealthDataType.HEART_RATE,
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_ASLEEP,
    ];

    bool granted = await _health.requestAuthorization(types);
    if (!granted) throw Exception("Health permission not granted");

    // Query exact daily deduplicated steps
    int steps = 0;
    try {
      final totalSteps = await _health.getTotalStepsInInterval(midnight, now);
      if (totalSteps != null && totalSteps >= 0) steps = totalSteps;
    } catch (_) {}

    final data = await _health.getHealthDataFromTypes(
      types: types,
      startTime: start,
      endTime: now,
    );

    double totalHeartRate = 0;
    int heartRateCount = 0;
    double? latestHeartRate;
    DateTime? latestHeartRateTime;
    double calories = 0;
    double sleep = 0;
    int fallbackSteps = 0;

    for (var d in data) {
      final value = (d.value is NumericHealthValue)
          ? (d.value as NumericHealthValue).numericValue
          : (d.value is num ? (d.value as num).toDouble() : 0.0);

      switch (d.type) {
        case HealthDataType.HEART_RATE:
          totalHeartRate += value;
          heartRateCount++;
          if (latestHeartRateTime == null || d.dateTo.isAfter(latestHeartRateTime)) {
            latestHeartRateTime = d.dateTo;
            latestHeartRate = value.toDouble();
          }
          break;
        case HealthDataType.STEPS:
          if (d.dateFrom.isAfter(midnight)) fallbackSteps += value.round();
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          if (d.dateFrom.isAfter(midnight)) calories += value;
          break;
        case HealthDataType.SLEEP_ASLEEP:
          sleep += value;
          break;
        default:
          break;
      }
    }

    if (steps == 0 && fallbackSteps > 0) steps = fallbackSteps;
    final finalHeartRate = (latestHeartRate ?? (heartRateCount > 0 ? (totalHeartRate / heartRateCount) : 0)).round();

    final vitals = {
      "heart_rate": finalHeartRate,
      "steps": steps,
      "calories": calories.round(),
      "sleep": (sleep / 60).round(),
      "timestamp": DateTime.now().toIso8601String(),
      "recorded_on": DateTime.now().toIso8601String(),
    };

    await uploadVitals(vitals);
    return vitals;
  }

  static Future<void> uploadVitals(Map<String, dynamic> vitals) async {
    const api =
        'https://aetab8pjmb.us-east-1.awsapprunner.com/table/wearable_vitals';

    try {
      final prefs = await SharedPreferences.getInstance();
      final patientId = prefs.getInt("patient_id");
      if (patientId == null) {
        print(" Upload skipped: no patient_id (user not logged in)");
        return;
      }
      vitals['patient_id'] = patientId;

      final res = await http.post(
        Uri.parse(api),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(vitals),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        print(" Uploaded vitals successfully");
      } else {
        print(" Upload failed: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      print(" Upload error: $e");
    }
  }
}
