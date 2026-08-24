import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../utils/hijri_date.dart';
import 'habit_tracker_service.dart';
import 'hijri_prefs.dart';
import 'prayer_times_service.dart';

/// خدمة تحديث ومزامنة بيانات ويدجت الشاشة الرئيسية (Android & iOS Widgets)
class HomeWidgetService {
  static const String androidPrayerWidgetName = 'AdhkariPrayerWidget';
  static const String iOSPrayerWidgetName = 'AdhkariPrayerWidget';

  /// تحديث بيانات الويدجت الشاملة (الصلاة القادمة، التاريخ الهجري، الذكر اليومي)
  static Future<void> updateAll() async {
    try {
      final now = DateTime.now();

      // 1. التاريخ الهجري
      final offset = HijriPrefs.offsetNotifier.value;
      final hijri = HijriDate.fromGregorian(now, offset: offset);
      final hijriFormatted = hijri.formatAr();
      await HomeWidget.saveWidgetData<String>('hijri_date', hijriFormatted);

      // 2. مواقيت الصلاة القادمة
      final location = await PrayerTimesService.cachedLocation();
      if (location != null) {
        final times = PrayerTimesService.timesFor(location);
        final next = times.nextPrayer();
        final nextTime = times.timeOf(next);

        if (nextTime != null) {
          final prayerName = prayerNamesAr[next] ?? '';
          final h = nextTime.hour == 0
              ? 12
              : (nextTime.hour > 12 ? nextTime.hour - 12 : nextTime.hour);
          final m = nextTime.minute.toString().padLeft(2, '0');
          final period = nextTime.hour < 12 ? 'ص' : 'م';
          final timeFormatted = '$h:$m $period';

          await HomeWidget.saveWidgetData<String>(
            'next_prayer_name',
            prayerName,
          );
          await HomeWidget.saveWidgetData<String>(
            'next_prayer_time',
            timeFormatted,
          );
        }
      }

      // 3. التقدم في الأذكار والتسبيح
      final activity = HabitTrackerService.getTodayActivity();
      await HomeWidget.saveWidgetData<int>(
        'tasbih_count',
        activity.tasbihCount,
      );
      await HomeWidget.saveWidgetData<bool>(
        'morning_done',
        activity.morningDone,
      );
      await HomeWidget.saveWidgetData<bool>(
        'evening_done',
        activity.eveningDone,
      );

      // إرسال إشارة التحديث للنظام
      await HomeWidget.updateWidget(
        name: androidPrayerWidgetName,
        iOSName: iOSPrayerWidgetName,
      );
    } catch (e) {
      debugPrint('خطأ أثناء تحديث بيانات الويدجت: $e');
    }
  }
}
