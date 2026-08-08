import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_development/data/islamic_events.dart';
import 'package:flutter_development/utils/hijri_date.dart';

void main() {
  group('IslamicEvents.all', () {
    test('holds the six occasions in Hijri order', () {
      expect(IslamicEvents.all.map((e) => e.nameAr).toList(), [
        'رأس السنة الهجرية',
        'يوم عاشوراء',
        'أول رمضان',
        'عيد الفطر',
        'يوم عرفة',
        'عيد الأضحى',
      ]);
    });

    test('only Ramadan spans more than one day', () {
      for (final event in IslamicEvents.all) {
        expect(event.durationDays, event.nameAr == 'أول رمضان' ? 30 : 1,
            reason: event.nameAr);
      }
    });
  });

  group('nextEvent', () {
    test('an upcoming occasion counts down', () {
      // 23 صفر 1448 = 2026-08-08، وأول رمضان 1448 = 2027-02-08.
      final result = nextEvent(const HijriDate(1448, 2, 23));
      expect(result.event.nameAr, 'أول رمضان');
      expect(result.daysRemaining, 184);
      expect(result.dayInEvent, 0);
    });

    test('the day before an occasion returns 1 day remaining', () {
      final result = nextEvent(const HijriDate(1448, 8, 29));
      expect(result.event.nameAr, 'أول رمضان');
      expect(result.daysRemaining, 1);
      expect(result.dayInEvent, 0);
    });

    test('the day of an occasion returns 0 remaining and day 1', () {
      final result = nextEvent(const HijriDate(1448, 9, 1));
      expect(result.event.nameAr, 'أول رمضان');
      expect(result.daysRemaining, 0);
      expect(result.dayInEvent, 1);
    });

    test('a date inside Ramadan returns Ramadan, not the following Eid', () {
      final middle = nextEvent(const HijriDate(1448, 9, 15));
      expect(middle.event.nameAr, 'أول رمضان');
      expect(middle.daysRemaining, 0);
      expect(middle.dayInEvent, 15);

      final last = nextEvent(const HijriDate(1448, 9, 30));
      expect(last.event.nameAr, 'أول رمضان');
      expect(last.dayInEvent, 30);
    });

    test('Ramadan ends and Eid al-Fitr takes over on 1 Shawwal', () {
      final result = nextEvent(const HijriDate(1448, 10, 1));
      expect(result.event.nameAr, 'عيد الفطر');
      expect(result.daysRemaining, 0);
      expect(result.dayInEvent, 1);
    });

    test('picks the nearest of several upcoming occasions', () {
      final result = nextEvent(const HijriDate(1448, 1, 2));
      expect(result.event.nameAr, 'يوم عاشوراء');
      expect(result.daysRemaining, 8);
    });

    test('wraps to the next Hijri year once everything has passed', () {
      // 11 ذو الحجة 1448، بعد عيد الأضحى. 1448 سنة عادية = 354 يوم.
      final result = nextEvent(const HijriDate(1448, 12, 11));
      expect(result.event.nameAr, 'رأس السنة الهجرية');
      expect(result.daysRemaining, 19);
      expect(result.dayInEvent, 0);
    });

    test('never returns a negative countdown, for any day of a year', () {
      final startJdn = const HijriDate(1448, 1, 1).toJdn();
      final endJdn = const HijriDate(1449, 1, 1).toJdn();
      for (var jdn = startJdn; jdn < endJdn; jdn++) {
        final date = HijriDate.fromJdn(jdn);
        final result = nextEvent(date);
        expect(result.daysRemaining, greaterThanOrEqualTo(0), reason: '$date');
        expect(result.dayInEvent, greaterThanOrEqualTo(0), reason: '$date');
      }
    });
  });
}
