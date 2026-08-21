import 'package:flutter/material.dart';

import '../data/islamic_events.dart';
import '../theme/app_theme.dart';
import '../utils/hijri_date.dart';
import 'app_card.dart';

/// كارت التاريخ الهجري في شاشة "اليوم".
///
/// بياخد قيم جاهزة ومش بيعمل أي I/O — نفس تقسيم الشغل اللي الشاشة
/// بتستعمله مع باقي كروتها.
///
/// الكارت بيعرض شريط الأسبوع الحالي (السبت → الجمعة) وعليه علامة على
/// النهارده، وبيعرض المناسبة **بس لو احنا فيها فعلًا**. مفيش عدّ تنازلي:
/// "باقي 190 يوم لرمضان" مش معلومة المستخدم محتاجها كل يوم.
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

  /// حروف أيام الأسبوع من السبت للجمعة — ترتيب التقويم العربي.
  static const List<String> _weekLetters = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  /// سطر المناسبة، أو null لو مفيش مناسبة شغالة النهارده.
  ///
  /// [daysRemaining] بيساوي صفر بس لما المناسبة تكون بدأت خلاص (النهارده
  /// أو احنا في نصها)، فهو الشرط الوحيد اللي محتاجينه.
  String? get _eventLine {
    if (daysRemaining != 0) return null;
    if (nextEvent.durationDays > 1 && dayInEvent >= 1) {
      return '${nextEvent.nameAr} — اليوم $dayInEvent';
    }
    return '${nextEvent.nameAr} — النهارده';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final event = _eventLine;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ————— التاريخ —————
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: p.primary, size: 20),
              const SizedBox(width: AppSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hijri.formatAr(),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: p.text,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatGregorianAr(gregorian),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12.5, color: p.textMuted),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpace.md),
          Divider(color: p.border, height: 1),
          const SizedBox(height: AppSpace.md),

          // ————— شريط الأسبوع —————
          _WeekStrip(hijri: hijri, gregorian: gregorian),

          // ————— المناسبة، لو فيه واحدة النهارده —————
          if (event != null) ...[
            const SizedBox(height: AppSpace.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: AppRadius.pillR,
                  border: Border.all(color: p.accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 15, color: p.accent),
                    const SizedBox(width: 6),
                    Text(
                      event,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: p.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// سبعة أيام هجرية من سبت الأسبوع الحالي للجمعة، والنهارده معلّم عليه.
///
/// الأيام بتتحسب بأرقام اليوم اليوليانية مش بجمع وطرح على `day`، عشان
/// الأسبوع اللي بيعدّي على حدود الشهر (أو السنة) يطلع صح — طول الشهر
/// الهجري بيتغير، فـ `day + 1` ممكن يطلّع يوم 30 في شهر 29 يوم.
class _WeekStrip extends StatelessWidget {
  final HijriDate hijri;
  final DateTime gregorian;

  const _WeekStrip({required this.hijri, required this.gregorian});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // DateTime.weekday: الاثنين = 1 والأحد = 7، فالسبت = 6.
    // الصيغة دي بتطلّع عدد الأيام من سبت الأسبوع: السبت 0 والجمعة 6.
    final int daysSinceSaturday = (gregorian.weekday + 1) % 7;
    final int saturdayJdn = hijri.toJdn() - daysSinceSaturday;

    // الشريط بيلف RTL بنفسه عشان السبت يطلع على اليمين مهما كان اتجاه
    // الشاشة اللي جواها — الكارت بيتعرض في أكتر من مكان.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < 7; i++)
            _DayCell(
              letter: HijriDateCard._weekLetters[i],
              day: HijriDate.fromJdn(saturdayJdn + i).day,
              isToday: i == daysSinceSaturday,
              palette: p,
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String letter;
  final int day;
  final bool isToday;
  final AppPalette palette;

  const _DayCell({
    required this.letter,
    required this.day,
    required this.isToday,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          letter,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isToday ? p.primary : p.textFaint,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday ? p.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: isToday ? p.onPrimary : p.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
