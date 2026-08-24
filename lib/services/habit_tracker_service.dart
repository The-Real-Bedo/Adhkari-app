import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سجل النشاط الروحي ليوم واحد
class DailyActivity {
  final String date; // YYYY-MM-DD
  final bool morningDone;
  final bool eveningDone;
  final int tasbihCount;
  final int quranPages;

  const DailyActivity({
    required this.date,
    this.morningDone = false,
    this.eveningDone = false,
    this.tasbihCount = 0,
    this.quranPages = 0,
  });

  /// كثافة النشاط (من 0 إلى 4) لتلوين مربعات الـ Heatmap
  int get intensity {
    int score = 0;
    if (morningDone) score += 1;
    if (eveningDone) score += 1;
    if (tasbihCount >= 100) score += 1;
    if (quranPages >= 1) score += 1;
    return score.clamp(0, 4);
  }

  DailyActivity copyWith({
    bool? morningDone,
    bool? eveningDone,
    int? tasbihCount,
    int? quranPages,
  }) {
    return DailyActivity(
      date: date,
      morningDone: morningDone ?? this.morningDone,
      eveningDone: eveningDone ?? this.eveningDone,
      tasbihCount: tasbihCount ?? this.tasbihCount,
      quranPages: quranPages ?? this.quranPages,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'morningDone': morningDone,
        'eveningDone': eveningDone,
        'tasbihCount': tasbihCount,
        'quranPages': quranPages,
      };

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      date: json['date'] as String? ?? '',
      morningDone: json['morningDone'] as bool? ?? false,
      eveningDone: json['eveningDone'] as bool? ?? false,
      tasbihCount: json['tasbihCount'] as int? ?? 0,
      quranPages: json['quranPages'] as int? ?? 0,
    );
  }
}

/// خدمة تتبع العادات الروحانية وشبكة النشاط اليومي (Heatmap)
class HabitTrackerService {
  static const String _kKey = 'spiritual_habit_history';
  static const String _kBestStreakKey = 'spiritual_best_streak';

  static final ValueNotifier<Map<String, DailyActivity>> activityNotifier =
      ValueNotifier<Map<String, DailyActivity>>({});

  static String _todayKey() => DateTime.now().toString().split(' ')[0];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        final map = <String, DailyActivity>{};
        decoded.forEach((key, value) {
          map[key] = DailyActivity.fromJson(value as Map<String, dynamic>);
        });
        activityNotifier.value = map;
      } catch (e) {
        debugPrint('خطأ في تحميل سجل العادات: $e');
      }
    }
  }

  static Future<void> _save(Map<String, DailyActivity> map) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{};
    map.forEach((k, v) => encoded[k] = v.toJson());
    await prefs.setString(_kKey, jsonEncode(encoded));
  }

  static DailyActivity getTodayActivity() {
    final key = _todayKey();
    return activityNotifier.value[key] ?? DailyActivity(date: key);
  }

  /// تسجيل إتمام أذكار الصباح أو المساء
  static Future<void> logAzkarCompletion(String type) async {
    final key = _todayKey();
    final current = getTodayActivity();
    final updated = current.copyWith(
      morningDone: type == 'morning' ? true : current.morningDone,
      eveningDone: type == 'evening' ? true : current.eveningDone,
    );

    final map = Map<String, DailyActivity>.from(activityNotifier.value);
    map[key] = updated;
    activityNotifier.value = map;
    await _save(map);
    await _updateBestStreak();
  }

  /// تسجيل إضافة تسبيحات
  static Future<void> logTasbih(int count) async {
    if (count <= 0) return;
    final key = _todayKey();
    final current = getTodayActivity();
    final updated = current.copyWith(
      tasbihCount: current.tasbihCount + count,
    );

    final map = Map<String, DailyActivity>.from(activityNotifier.value);
    map[key] = updated;
    activityNotifier.value = map;
    await _save(map);
  }

  /// تسجيل قراءة صفحات قرآن
  static Future<void> logQuranPages(int pages) async {
    if (pages <= 0) return;
    final key = _todayKey();
    final current = getTodayActivity();
    final updated = current.copyWith(
      quranPages: current.quranPages + pages,
    );

    final map = Map<String, DailyActivity>.from(activityNotifier.value);
    map[key] = updated;
    activityNotifier.value = map;
    await _save(map);
  }

  /// حساب السلسلة المتتالية الحالية (Streak)
  static int calculateStreak() {
    final map = activityNotifier.value;
    int streak = 0;
    var checkDate = DateTime.now();

    while (true) {
      final key = checkDate.toString().split(' ')[0];
      final activity = map[key];

      // اليوم يعتبر مكتملاً لو قام المستخدم بأي نشاط ذِكر أو قراءة
      if (activity != null && activity.intensity > 0) {
        streak++;
        // حساب يومي بدل ساعات — عشان تغيير التوقيت الصيفي مايغلطش
        checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
      } else {
        // إذا كان اليوم هو اليوم الحالي ولسه في بدايته، نفحص أمس
        if (checkDate.toString().split(' ')[0] == _todayKey() && streak == 0) {
          checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
          continue;
        }
        break;
      }
    }
    return streak;
  }

  static Future<void> _updateBestStreak() async {
    final currentStreak = calculateStreak();
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_kBestStreakKey) ?? 0;
    if (currentStreak > best) {
      await prefs.setInt(_kBestStreakKey, currentStreak);
    }
  }

  static Future<int> getBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_kBestStreakKey) ?? 0;
    return math.max(best, calculateStreak());
  }

  /// توليد قائمة الأيام لآخر N أسابيع لشبكة الـ Heatmap
  static List<DateTime> getHeatmapDays({int weeks = 12}) {
    final days = <DateTime>[];
    final totalDays = weeks * 7;
    final today = DateTime.now();

    for (int i = totalDays - 1; i >= 0; i--) {
      // حساب يومي بدل ساعات — عشان تغيير التوقيت الصيفي مايغلطش
      days.add(DateTime(today.year, today.month, today.day - i));
    }
    return days;
  }
}
