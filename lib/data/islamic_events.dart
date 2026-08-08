import '../utils/hijri_date.dart';

/// مناسبة إسلامية بتتكرر كل سنة هجرية في نفس اليوم والشهر.
class IslamicEvent {
  /// شهر هجري 1..12
  final int month;

  /// يوم هجري
  final int day;

  final String nameAr;

  /// عدد أيام المناسبة. 1 للمناسبات اللي يوم واحد، و30 لرمضان عشان
  /// الكارت يقول "إنت في اليوم كذا" بدل ما يعدّ لحاجة عدّت.
  final int durationDays;

  const IslamicEvent({
    required this.month,
    required this.day,
    required this.nameAr,
    this.durationDays = 1,
  });
}

class IslamicEvents {
  static const List<IslamicEvent> all = [
    IslamicEvent(month: 1, day: 1, nameAr: 'رأس السنة الهجرية'),
    IslamicEvent(month: 1, day: 10, nameAr: 'يوم عاشوراء'),
    IslamicEvent(month: 9, day: 1, nameAr: 'أول رمضان', durationDays: 30),
    IslamicEvent(month: 10, day: 1, nameAr: 'عيد الفطر'),
    IslamicEvent(month: 12, day: 9, nameAr: 'يوم عرفة'),
    IslamicEvent(month: 12, day: 10, nameAr: 'عيد الأضحى'),
  ];
}

/// نتيجة [nextEvent]. المناسبة الشغالة دلوقتي بترجع بـ daysRemaining صفر
/// و dayInEvent من 1، والمناسبة اللي لسه جاية بترجع بـ dayInEvent صفر.
typedef NextEvent = ({IslamicEvent event, int daysRemaining, int dayInEvent});

/// أقرب مناسبة في [today] أو بعديها.
///
/// الفرق بيتحسب بأرقام الأيام اليوليانية مش بطرح أيام هجرية، عشان طول
/// الشهور بيتغيّر وحدود السنة بتعقّد الطرح من غير أي فايدة.
NextEvent nextEvent(HijriDate today) {
  final int todayJdn = today.toJdn();
  NextEvent? best;

  // سنتين كفاية: أسوأ حالة إن كل مناسبات السنة الحالية عدّت، فأقرب
  // واحدة تبقى أول مناسبة في السنة اللي بعدها.
  for (final int year in [today.year, today.year + 1]) {
    for (final IslamicEvent event in IslamicEvents.all) {
      final int startJdn = HijriDate(year, event.month, event.day).toJdn();
      final int endJdn = startJdn + event.durationDays - 1;
      if (todayJdn > endJdn) continue; // خلصت خلاص

      final bool started = todayJdn >= startJdn;
      final NextEvent candidate = (
        event: event,
        daysRemaining: started ? 0 : startJdn - todayJdn,
        dayInEvent: started ? todayJdn - startJdn + 1 : 0,
      );
      if (best == null || candidate.daysRemaining < best.daysRemaining) {
        best = candidate;
      }
    }
  }

  // أول محرم للسنة الجاية دايمًا بعد أي يوم في السنة الحالية، فالقيمة
  // دي مستحيل تفضل null.
  return best!;
}
