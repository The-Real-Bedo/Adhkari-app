import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'habit_tracker_service.dart';

/// خطة ختمة القرآن الكريم المحسنة (604 صفحات المصحف الشريف)
class KhatmahPlan {
  static const int totalMushafPages = 604;

  final String title;
  final int targetDays;
  final DateTime startDate;
  final int currentPage;
  final String lastReadDate;
  final int pagesReadToday;

  const KhatmahPlan({
    this.title = 'ختمتي الحالية',
    required this.targetDays,
    required this.startDate,
    required this.currentPage,
    required this.lastReadDate,
    required this.pagesReadToday,
  });

  factory KhatmahPlan.defaultPlan() {
    return KhatmahPlan(
      title: 'ختمتي الحالية',
      targetDays: 30,
      startDate: DateTime.now(),
      currentPage: 0,
      lastReadDate: '',
      pagesReadToday: 0,
    );
  }

  /// الصفحات المستهدفة يومياً
  int get dailyPagesTarget =>
      (totalMushafPages / math.max(1, targetDays)).ceil();

  /// رقم اليوم الحالي من الخطة
  int get currentDayNumber {
    final diffDays = DateTime.now().difference(startDate).inDays;
    return (diffDays + 1).clamp(1, targetDays);
  }

  /// الأيام المتبقية
  int get remainingDays => math.max(0, targetDays - currentDayNumber);

  /// الصفحات المتبقية
  int get remainingPages => math.max(0, totalMushafPages - currentPage);

  /// الصفحات المتوقع الوصول إليها اليوم حسب الخطة الأصلية
  int get expectedPageForToday =>
      (currentDayNumber * dailyPagesTarget).clamp(1, totalMushafPages);

  /// الفارق بين ما قرأه والمفترض (موجب = متقدم، سالب = متأخر)
  int get paceDifference => currentPage - expectedPageForToday;

  /// نسبة الإنجاز الكلية
  double get overallProgress =>
      (currentPage / totalMushafPages).clamp(0.0, 1.0);

  /// نسبة إنجاز ورد اليوم
  double get todayProgress =>
      (pagesReadToday / math.max(1, dailyPagesTarget)).clamp(0.0, 1.0);

  /// هل اكتملت الختمة
  bool get isCompleted => currentPage >= totalMushafPages;

  /// بداية ونهاية ورد اليوم
  int get todayTargetStartPage {
    final start = math.max(1, currentPage + 1);
    return start.clamp(1, totalMushafPages);
  }

  int get todayTargetEndPage {
    final int targetDiff =
        math.max<int>(0, dailyPagesTarget - pagesReadToday);
    final int calculatedEnd = todayTargetStartPage + targetDiff - 1;
    final int end = math.min<int>(totalMushafPages, calculatedEnd);
    return math.max<int>(todayTargetStartPage, end);
  }

  KhatmahPlan copyWith({
    String? title,
    int? targetDays,
    DateTime? startDate,
    int? currentPage,
    String? lastReadDate,
    int? pagesReadToday,
  }) {
    return KhatmahPlan(
      title: title ?? this.title,
      targetDays: targetDays ?? this.targetDays,
      startDate: startDate ?? this.startDate,
      currentPage: currentPage ?? this.currentPage,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      pagesReadToday: pagesReadToday ?? this.pagesReadToday,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'targetDays': targetDays,
        'startDate': startDate.toIso8601String(),
        'currentPage': currentPage,
        'lastReadDate': lastReadDate,
        'pagesReadToday': pagesReadToday,
      };

  factory KhatmahPlan.fromJson(Map<String, dynamic> json) {
    return KhatmahPlan(
      title: json['title'] as String? ?? 'ختمتي الحالية',
      targetDays: json['targetDays'] as int? ?? 30,
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
          DateTime.now(),
      currentPage: json['currentPage'] as int? ?? 0,
      lastReadDate: json['lastReadDate'] as String? ?? '',
      pagesReadToday: json['pagesReadToday'] as int? ?? 0,
    );
  }
}

/// خدمة إدارة وتتبع ختمة القرآن الكريم
class KhatmahService {
  static const String _kKey = 'khatmah_plan_data';

  static final ValueNotifier<KhatmahPlan> planNotifier =
      ValueNotifier<KhatmahPlan>(KhatmahPlan.defaultPlan());

  static KhatmahPlan get currentPlan => planNotifier.value;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null) {
      try {
        final plan = KhatmahPlan.fromJson(jsonDecode(raw));
        _checkDailyReset(plan);
      } catch (e) {
        debugPrint('خطأ في قراءة خطة الختمة: $e');
      }
    }
  }

  static void _checkDailyReset(KhatmahPlan plan) {
    final today = DateTime.now().toString().split(' ')[0];
    if (plan.lastReadDate != today) {
      final updated = plan.copyWith(
        lastReadDate: today,
        pagesReadToday: 0,
      );
      planNotifier.value = updated;
      _save(updated);
    } else {
      planNotifier.value = plan;
    }
  }

  static Future<void> _save(KhatmahPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(plan.toJson()));
  }

  /// بدء ختمة جديدة
  static Future<void> startNewKhatmah({
    required int targetDays,
    String title = 'ختمتي الحالية',
  }) async {
    final today = DateTime.now().toString().split(' ')[0];
    final plan = KhatmahPlan(
      title: title,
      targetDays: targetDays,
      startDate: DateTime.now(),
      currentPage: 0,
      lastReadDate: today,
      pagesReadToday: 0,
    );
    planNotifier.value = plan;
    await _save(plan);
  }

  /// إعادة ضبط وتوزيع الصفحات المتبقية على الأيام المتبقية بذكاء
  static Future<void> rebalancePlan() async {
    final current = planNotifier.value;
    final remainingPages = current.remainingPages;
    final remainingDays = math.max(1, current.remainingDays);
    final newTargetDaily = (remainingPages / remainingDays).ceil();
    final newTotalDays = current.currentDayNumber +
        (remainingPages / math.max(1, newTargetDaily)).ceil();

    final updated = current.copyWith(
      targetDays: math.max(current.targetDays, newTotalDays),
    );
    planNotifier.value = updated;
    await _save(updated);
  }

  /// تحديث الصفحة التي وصل إليها القارئ
  static Future<void> updateCurrentPage(int newPage) async {
    final current = planNotifier.value;
    final clampedPage = newPage.clamp(0, KhatmahPlan.totalMushafPages);
    final diff = math.max(0, clampedPage - current.currentPage);
    final today = DateTime.now().toString().split(' ')[0];

    final updated = current.copyWith(
      currentPage: clampedPage,
      lastReadDate: today,
      pagesReadToday: (current.lastReadDate == today
              ? current.pagesReadToday
              : 0) +
          diff,
    );

    if (diff > 0) {
      HabitTrackerService.logQuranPages(diff);
    }

    planNotifier.value = updated;
    await _save(updated);
  }

  /// إتمام ورد اليوم دفعة واحدة
  static Future<void> completeTodayTarget() async {
    final current = planNotifier.value;
    final targetEnd = current.todayTargetEndPage;
    await updateCurrentPage(targetEnd);
  }

  /// إضافة عدد صفحات
  static Future<void> addPagesRead(int count) async {
    if (count <= 0) return;
    final current = planNotifier.value;
    await updateCurrentPage(current.currentPage + count);
  }
}
