import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_times_service.dart';

/// تنبيهات أذكار الصباح والمساء + تنبيهات مواقيت الصلاة.
///
/// القنوات هنا منفصلة عن قناة مشغل القرآن ([kQuranChannelId] في
/// quran_audio_handler.dart) عشان المستخدم يقدر يكتم واحدة من غير التانية
/// من إعدادات النظام.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// معرّفات التنبيهات — أرقام ثابتة مسمّاة بدل أرقام سايبة في الكود
  static const int morningReminderId = 1;
  static const int eveningReminderId = 2;
  static const int fridayReminderId = 3;
  static const int postPrayerReminderBase = 200;

  static const String _dailyChannelId = 'com.adhkari.app.daily_reminders';
  static const String _dailyChannelName = 'تنبيهات الأذكار اليومية';
  static const String _dailyChannelDescription =
      'تنبيه بورد الصباح والمساء في الوقت اللي تختاره';

  static const String _fridayChannelId = 'com.adhkari.app.friday_reminders';
  static const String _fridayChannelName = 'تنبيهات يوم الجمعة';
  static const String _fridayChannelDescription =
      'تنبيه بسورة الكهف والصلاة على النبي ﷺ يوم الجمعة';

  static const String _prayerChannelId = 'com.adhkari.app.prayer_times';
  static const String _prayerChannelName = 'تنبيهات مواقيت الصلاة';
  static const String _prayerChannelDescription =
      'تنبيه عند دخول وقت كل صلاة';

  // مفاتيح التفضيلات
  static const String kMorningEnabled = 'reminder_morning_enabled';
  static const String kMorningMode = 'reminder_morning_mode'; // 'fixed', 'after_fajr', 'sunrise'
  static const String kMorningHour = 'reminder_morning_hour';
  static const String kMorningMinute = 'reminder_morning_minute';

  static const String kEveningEnabled = 'reminder_evening_enabled';
  static const String kEveningMode = 'reminder_evening_mode'; // 'fixed', 'after_asr', 'before_maghrib'
  static const String kEveningHour = 'reminder_evening_hour';
  static const String kEveningMinute = 'reminder_evening_minute';

  static const String kFridayEnabled = 'reminder_friday_enabled';
  static const String kPostPrayerAthkarEnabled = 'reminder_post_prayer_enabled';
  static const String kPrayerEnabled = 'prayer_notifications_enabled';

  static const int defaultMorningHour = 6;
  static const int defaultEveningHour = 17;

  /// تنبيهات الصلاة بتاخد نطاق أرقام مستقل تمامًا عن 1 و 2
  static const int prayerIdBase = 100;

  /// بنجدول أسبوع قدام، فلو المستخدم مافتحش التطبيق كام يوم التنبيهات
  /// تفضل شغالة
  static const int prayerDaysAhead = 7;

  static int _prayerId(int dayOffset, int prayerIndex) =>
      prayerIdBase + (dayOffset * 10) + prayerIndex;

  static Future<void> init() async {
    tz.initializeTimeZones();
    await _resolveLocalTimeZone();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // لازم نهيّأ iOS/macOS كمان. من غير الجزء ده التنبيهات مبتشتغلش خالص
    // على الأيفون: الصلاحية مبتتطلبش والتنبيه المجدول مبيتسلّمش.
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        );

    await _notificationsPlugin.initialize(initializationSettings);

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  /// بنظبط منطقة الجهاز الزمنية في مكان واحد: [tz.local].
  ///
  /// قبل كده كان فيه متغير منفصل بيتقرا منه وقت الجدولة، ولو
  /// `FlutterTimezone` فشلت كان يفضل 'UTC' بينما `setLocalLocation`
  /// بتتظبط على حاجة تانية — فتنبيه 6 صباحًا كان بيرن 8 أو 9 في القاهرة.
  static Future<void> _resolveLocalTimeZone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      return;
    } catch (_) {
      // اسم المنطقة مش معروف أو مش موجود في قاعدة البيانات — نكمّل تحت
    }

    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static String get localTimeZoneName => tz.local.name;

  static NotificationDetails _dailyDetails() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _dailyChannelId,
      _dailyChannelName,
      channelDescription: _dailyChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static NotificationDetails _prayerDetails() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _prayerChannelId,
      _prayerChannelName,
      channelDescription: _prayerChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static NotificationDetails _fridayDetails() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _fridayChannelId,
      _fridayChannelName,
      channelDescription: _fridayChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    for (final mode in const [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          _nextInstanceOfTime(hour, minute),
          _dailyDetails(),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        return;
      } catch (_) {
        // نجرّب الوضع اللي بعده
      }
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  static Future<void> syncDailyRemindersFromSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final morningEnabled = prefs.getBool(kMorningEnabled) ?? true;
    final eveningEnabled = prefs.getBool(kEveningEnabled) ?? true;

    await cancelNotification(morningReminderId);
    await cancelNotification(eveningReminderId);
    for (int d = 0; d < 7; d++) {
      await cancelNotification(10 + d);
      await cancelNotification(20 + d);
    }

    final location = await PrayerTimesService.cachedLocation();
    final now = DateTime.now();

    if (morningEnabled) {
      final mode = prefs.getString(kMorningMode) ?? 'fixed';
      int hour = prefs.getInt(kMorningHour) ?? defaultMorningHour;
      int minute = prefs.getInt(kMorningMinute) ?? 0;

      if (mode == 'fixed' || location == null) {
        await scheduleDailyNotification(
          id: morningReminderId,
          title: 'أَذْكَار الصَّبَاحِ ☀️',
          body: 'ابدأ يومك بوِرد الصباح وذِكر الله',
          hour: hour,
          minute: minute,
        );
      } else {
        for (int d = 0; d < 7; d++) {
          final targetDate = now.add(Duration(days: d));
          final times = PrayerTimesService.timesFor(location, date: targetDate);
          DateTime t;
          if (mode == 'after_fajr') {
            t = times.fajr.add(const Duration(minutes: 15));
          } else {
            t = times.sunrise;
          }
          if (t.isBefore(now)) continue;
          try {
            await _notificationsPlugin.zonedSchedule(
              10 + d,
              'أَذْكَار الصَّبَاحِ ☀️',
              'ابدأ يومك بوِرد الصباح وذِكر الله',
              tz.TZDateTime.from(t, tz.local),
              _dailyDetails(),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          } catch (_) {}
        }
      }
    }

    if (eveningEnabled) {
      final mode = prefs.getString(kEveningMode) ?? 'fixed';
      int hour = prefs.getInt(kEveningHour) ?? defaultEveningHour;
      int minute = prefs.getInt(kEveningMinute) ?? 0;

      if (mode == 'fixed' || location == null) {
        await scheduleDailyNotification(
          id: eveningReminderId,
          title: 'أَذْكَار المَسَاءِ 🌙',
          body: 'اختم يومك بوِرد المساء وطمأنينة الذكر',
          hour: hour,
          minute: minute,
        );
      } else {
        for (int d = 0; d < 7; d++) {
          final targetDate = now.add(Duration(days: d));
          final times = PrayerTimesService.timesFor(location, date: targetDate);
          DateTime t;
          if (mode == 'after_asr') {
            t = times.asr.add(const Duration(minutes: 10));
          } else {
            t = times.maghrib.subtract(const Duration(minutes: 30));
          }
          if (t.isBefore(now)) continue;
          try {
            await _notificationsPlugin.zonedSchedule(
              20 + d,
              'أَذْكَار المَسَاءِ 🌙',
              'اختم يومك بوِرد المساء وطمأنينة الذكر',
              tz.TZDateTime.from(t, tz.local),
              _dailyDetails(),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          } catch (_) {}
        }
      }
    }

    await syncFridayReminder();
  }

  /// مزامنة تذكير يوم الجمعة بسورة الكهف والصلاة على النبي ﷺ
  static Future<void> syncFridayReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(kFridayEnabled) ?? true;
    await cancelNotification(fridayReminderId);
    if (!enabled) return;

    final nextFriday = _nextInstanceOfDayAndTime(DateTime.friday, 9, 0);
    try {
      await _notificationsPlugin.zonedSchedule(
        fridayReminderId,
        'سورة الكهف والصلاة على النبي ﷺ 🌿',
        '«مَنْ قَرَأَ سُورَةَ الْكَهْفِ يَوْمَ الْجُمُعَةِ أَضَاءَ لَهُ مِنَ النُّورِ مَا بَيْنَ الْجُمُعَتَيْنِ»',
        nextFriday,
        _fridayDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }

  // ————— تنبيهات مواقيت الصلاة —————

  /// بتلغي كل تنبيهات الصلاة المجدولة في النطاق بتاعها.
  static Future<void> cancelPrayerNotifications() async {
    for (int d = 0; d < prayerDaysAhead; d++) {
      for (int i = 0; i < notifiablePrayers.length; i++) {
        await _notificationsPlugin.cancel(_prayerId(d, i));
      }
    }
  }

  /// بتجدول تنبيه لكل صلاة، لأسبوع قدام.
  ///
  /// مواقيت الصلاة بتتغير كل يوم، فمينفعش نستخدم التكرار اليومي بتاع
  /// النظام (`DateTimeComponents.time`) زي تنبيهات الأذكار — ده بيرن نفس
  /// الساعة كل يوم. بنجدول كل صلاة لوحدها كتنبيه لمرة واحدة، وبنعيد
  /// الجدولة من أول وجديد في كل مرة التطبيق يفتح.
  ///
  /// الشروق مستبعد لأنه مش صلاة ([notifiablePrayers]).
  static Future<void> syncPrayerNotifications() async {
    await cancelPrayerNotifications();

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(kPrayerEnabled) ?? false)) return;

    // بنستخدم الإحداثيات المحفوظة بس — مانطلبش صلاحية موقع من الخلفية
    final location = await PrayerTimesService.cachedLocation();
    if (location == null) return;

    final now = DateTime.now();

    for (int d = 0; d < prayerDaysAhead; d++) {
      final times = PrayerTimesService.timesFor(
        location,
        date: now.add(Duration(days: d)),
      );

      for (int i = 0; i < notifiablePrayers.length; i++) {
        final prayer = notifiablePrayers[i];
        final time = times.timeOf(prayer);

        // اللي فات النهارده مبيتجدولش
        if (time == null || !time.isAfter(now)) continue;

        try {
          await _notificationsPlugin.zonedSchedule(
            _prayerId(d, i),
            'حان الآن موعد صلاة ${prayerNamesAr[prayer]}',
            'أقم الصلاة، وأقبل على الله',
            tz.TZDateTime.from(time, tz.local),
            _prayerDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {
          // صلاحية المنبه الدقيق مرفوضة أو النظام وصل للحد الأقصى —
          // بنكمّل لباقي الصلوات بدل ما نوقف كله
        }
      }
    }
  }

  /// أقرب وقت جاي للساعة المطلوبة بتوقيت الجهاز.
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.Location location = tz.local;
    final tz.TZDateTime now = tz.TZDateTime.now(location);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // !isAfter بدل isBefore: لو الوقت المطلوب هو نفس اللحظة دي بالظبط
    // لازم نروح لبكرة، مش نجدول تنبيه في الماضي بفرق أجزاء من الثانية.
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// أقرب وقت جاي ليوم معين في الأسبوع (مثل الجمعة) وساعة محددة.
  static tz.TZDateTime _nextInstanceOfDayAndTime(
    int dayOfWeek,
    int hour,
    int minute,
  ) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
