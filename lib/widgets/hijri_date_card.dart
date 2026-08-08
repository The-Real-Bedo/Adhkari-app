import 'package:flutter/material.dart';

import '../data/islamic_events.dart';
import '../theme/app_theme.dart';
import '../utils/hijri_date.dart';
import 'app_card.dart';

/// كارت التاريخ الهجري في شاشة "اليوم".
///
/// بياخد قيم جاهزة ومش بيعمل أي I/O — نفس تقسيم الشغل اللي الشاشة
/// بتستعمله مع باقي كروتها.
class HijriDateCard extends StatelessWidget {
  final HijriDate hijri;
  final DateTime gregorian;
  final IslamicEvent nextEvent;
  final int daysRemaining;
  final int dayInEvent;

  /// بيفتح الإعدادات عشان المستخدم يظبط الإزاحة.
  final VoidCallback? onTap;

  const HijriDateCard({
    super.key,
    required this.hijri,
    required this.gregorian,
    required this.nextEvent,
    required this.daysRemaining,
    required this.dayInEvent,
    this.onTap,
  });

  /// سطر المناسبة. المناسبة اللي أكتر من يوم وشغالة دلوقتي بتقول إحنا في
  /// اليوم الكام، مش "باقي صفر يوم".
  String get _eventLine {
    if (nextEvent.durationDays > 1 && dayInEvent >= 1) {
      return '${nextEvent.nameAr} — اليوم $dayInEvent';
    }
    if (daysRemaining == 0) return '${nextEvent.nameAr} — النهارده';
    return '${nextEvent.nameAr} — باقي ${formatDaysAr(daysRemaining)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: p.primary, size: 20),
              const Spacer(),
              Text(
                hijri.formatAr(),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            formatGregorianAr(gregorian),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, color: p.textMuted),
          ),
          const SizedBox(height: AppSpace.md),
          Divider(color: p.border, height: 1),
          const SizedBox(height: AppSpace.md),
          Text(
            _eventLine,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: p.accent,
            ),
          ),
        ],
      ),
    );
  }
}
