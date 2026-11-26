import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Real native Android & iOS notifications for incoming WhatsApp messages and scheduled reminders.
class MaxAssistNotificationService {
  MaxAssistNotificationService._();
  static final MaxAssistNotificationService instance = MaxAssistNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _chatChannelId = 'maxassist_messages';
  static const String _chatChannelName = 'MaxAssist Messages';
  static const String _schedChannelId = 'maxassist_reminders';
  static const String _schedChannelName = 'MaxAssist Scheduled Reminders';

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: androidInit, iOS: iosInit);
      await _plugin.initialize(settings);

      // Request Android 13+ POST_NOTIFICATIONS runtime permission
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();

      // Request iOS alert/badge/sound permissions
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (e) {
      debugPrint('[MaxAssistNotificationService] init error: $e');
    }
  }

  Future<void> showIncomingMessageNotification({
    required String senderName,
    required String body,
  }) async {
    if (kIsWeb || body.trim().isEmpty) return;
    if (!_initialized) await initialize();
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannelId,
          _chatChannelName,
          channelDescription: 'Incoming WhatsApp messages in MaxAssist',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _plugin.show(id, senderName, body.trim(), details);
    } catch (e) {
      debugPrint('[MaxAssistNotificationService] show error: $e');
    }
  }

  Future<void> scheduleLocalReminder({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();
    try {
      final targetUtc = scheduledTime.toUtc();
      if (!targetUtc.isAfter(DateTime.now().toUtc())) return;
      final tzTime = tz.TZDateTime.from(targetUtc, tz.UTC);

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _schedChannelId,
          _schedChannelName,
          channelDescription: 'Scheduled MaxAssist WhatsApp reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      final id = targetUtc.millisecondsSinceEpoch.remainder(100000);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[MaxAssistNotificationService] schedule error: $e');
    }
  }
}
