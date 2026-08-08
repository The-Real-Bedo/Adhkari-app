import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_development/utils/hijri_date.dart';

void main() {
  group('HijriDate.fromGregorian', () {
    test('epoch', () {
      expect(
        HijriDate.fromGregorian(DateTime.utc(622, 7, 19)),
        const HijriDate(1, 1, 1),
      );
    });

    test('known anchors', () {
      expect(
        HijriDate.fromGregorian(DateTime.utc(2026, 8, 8)),
        const HijriDate(1448, 2, 23),
      );
      expect(
        HijriDate.fromGregorian(DateTime.utc(2026, 6, 17)),
        const HijriDate(1448, 1, 1),
      );
      expect(
        HijriDate.fromGregorian(DateTime.utc(2027, 2, 8)),
        const HijriDate(1448, 9, 1),
      );
    });

    test('ignores the time of day', () {
      expect(
        HijriDate.fromGregorian(DateTime.utc(2026, 8, 8, 23, 59, 59)),
        const HijriDate(1448, 2, 23),
      );
    });

    test('month boundary: 30 Muharram is followed by 1 Safar', () {
      expect(
        HijriDate.fromGregorian(DateTime.utc(2026, 7, 16)),
        const HijriDate(1448, 1, 30),
      );
      expect(
        HijriDate.fromGregorian(DateTime.utc(2026, 7, 17)),
        const HijriDate(1448, 2, 1),
      );
    });

    test('year boundary: 30 Dhu al-Hijjah 1447 is followed by 1 Muharram 1448',
        () {
      expect(
        HijriDate.fromGregorian(DateTime.utc(2026, 6, 16)),
        const HijriDate(1447, 12, 30),
      );
      expect(
        HijriDate.fromGregorian(DateTime.utc(2026, 6, 17)),
        const HijriDate(1448, 1, 1),
      );
    });

    test('offset shifts the Hijri date by whole days', () {
      final base = DateTime.utc(2026, 8, 8);
      expect(
          HijriDate.fromGregorian(base, offset: 1), const HijriDate(1448, 2, 24));
      expect(HijriDate.fromGregorian(base, offset: -1),
          const HijriDate(1448, 2, 22));
      expect(
          HijriDate.fromGregorian(base, offset: 2), const HijriDate(1448, 2, 25));
    });
  });

  group('HijriDate.toGregorian', () {
    test('known anchors', () {
      expect(const HijriDate(1, 1, 1).toGregorian(), DateTime.utc(622, 7, 19));
      expect(
          const HijriDate(1448, 2, 23).toGregorian(), DateTime.utc(2026, 8, 8));
      expect(
          const HijriDate(1448, 9, 1).toGregorian(), DateTime.utc(2027, 2, 8));
    });

    test('round-trips across several years', () {
      var date = DateTime.utc(2024, 1, 1);
      final end = DateTime.utc(2030, 1, 1);
      while (date.isBefore(end)) {
        expect(HijriDate.fromGregorian(date).toGregorian(), date,
            reason: 'round-trip failed for $date');
        date = date.add(const Duration(days: 1));
      }
    });
  });

  group('HijriDate.toJdn', () {
    test('matches the reference Julian Day Numbers', () {
      expect(const HijriDate(1, 1, 1).toJdn(), 1948440);
      expect(const HijriDate(1447, 12, 30).toJdn(), 2461208);
      expect(const HijriDate(1448, 1, 1).toJdn(), 2461209);
      expect(const HijriDate(1448, 2, 23).toJdn(), 2461261);
      expect(const HijriDate(1448, 9, 1).toJdn(), 2461445);
    });
  });

  group('calendar shape', () {
    test('isLeapYear matches the 11 positions in the 30-year cycle', () {
      const leap = {2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29};
      for (var year = 1400; year < 1460; year++) {
        expect(HijriDate.isLeapYear(year), leap.contains(year % 30),
            reason: 'year $year');
      }
      expect(HijriDate.isLeapYear(1447), isTrue);
      expect(HijriDate.isLeapYear(1448), isFalse);
    });

    test('daysInMonth: odd months 30, even months 29', () {
      expect(HijriDate.daysInMonth(1448, 1), 30);
      expect(HijriDate.daysInMonth(1448, 2), 29);
      expect(HijriDate.daysInMonth(1448, 9), 30);
      expect(HijriDate.daysInMonth(1448, 11), 30);
    });

    test('daysInMonth: month 12 is 30 days only in a leap year', () {
      expect(HijriDate.daysInMonth(1447, 12), 30);
      expect(HijriDate.daysInMonth(1448, 12), 29);
    });
  });

  group('value semantics', () {
    test('equal dates compare equal and hash equal', () {
      expect(const HijriDate(1448, 2, 23), const HijriDate(1448, 2, 23));
      expect(const HijriDate(1448, 2, 23).hashCode,
          const HijriDate(1448, 2, 23).hashCode);
      expect(
          const HijriDate(1448, 2, 23) == const HijriDate(1448, 2, 24), isFalse);
    });
  });

  group('Arabic formatting', () {
    test('monthNameAr', () {
      expect(const HijriDate(1448, 1, 1).monthNameAr, 'محرم');
      expect(const HijriDate(1448, 2, 23).monthNameAr, 'صفر');
      expect(const HijriDate(1448, 9, 1).monthNameAr, 'رمضان');
      expect(const HijriDate(1448, 12, 9).monthNameAr, 'ذو الحجة');
    });

    test('formatAr uses Western digits', () {
      expect(const HijriDate(1448, 2, 23).formatAr(), '23 صفر 1448 هـ');
      expect(const HijriDate(1448, 9, 1).formatAr(), '1 رمضان 1448 هـ');
    });

    test('formatGregorianAr names the weekday and month', () {
      expect(formatGregorianAr(DateTime(2026, 8, 8)), 'السبت 8 أغسطس 2026');
      expect(formatGregorianAr(DateTime(2027, 2, 8)), 'الاثنين 8 فبراير 2027');
    });

    test('formatDaysAr follows Arabic number agreement', () {
      expect(formatDaysAr(1), 'يوم واحد');
      expect(formatDaysAr(2), 'يومين');
      expect(formatDaysAr(3), '3 أيام');
      expect(formatDaysAr(10), '10 أيام');
      expect(formatDaysAr(11), '11 يوم');
      expect(formatDaysAr(184), '184 يوم');
    });

    test('every name list has the right length', () {
      expect(hijriMonthNamesAr.length, 12);
      expect(gregorianMonthNamesAr.length, 12);
      expect(weekdayNamesAr.length, 7);
    });
  });
}
