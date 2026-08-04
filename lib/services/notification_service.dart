import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart'; // المكتبة الجديدة
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static String _currentTimeZone = 'UTC';

  static Future<void> init() async {
    tz.initializeTimeZones();

    // لقط المنطقة الزمنية الحقيقية للجهاز بشكل ديناميكي صحيح
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      _currentTimeZone = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(_currentTimeZone));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.local);
      } catch (_) {
        _currentTimeZone = 'UTC';
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {},
    );

    // طلب صلاحيات الإشعارات والمنبه الدقيق لأندرويد 13 و 14+
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_channel',
            'Daily Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_channel',
            'Daily Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  static Future<void> syncDailyRemindersFromSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final morningEnabled = prefs.getBool('reminder_morning_enabled') ?? true;
    final eveningEnabled = prefs.getBool('reminder_evening_enabled') ?? true;

    await cancelNotification(1);
    await cancelNotification(2);

    if (morningEnabled) {
      await scheduleDailyNotification(
        id: 1,
        title: "أَذْكَار الصَّبَاحِ ☀️",
        body: "ابدأ يومك بوِرد الصباح وذِكر الله",
        hour: prefs.getInt('reminder_morning_hour') ?? 6,
        minute: prefs.getInt('reminder_morning_minute') ?? 0,
      );
    }

    if (eveningEnabled) {
      await scheduleDailyNotification(
        id: 2,
        title: "أَذْكَار المَسَاءِ 🌙",
        body: "اختم يومك بوِرد المساء وطمأنينة الذكر",
        hour: prefs.getInt('reminder_evening_hour') ?? 17,
        minute: prefs.getInt('reminder_evening_minute') ?? 0,
      );
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.Location location = tz.getLocation(_currentTimeZone);
    final tz.TZDateTime now = tz.TZDateTime.now(location);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}