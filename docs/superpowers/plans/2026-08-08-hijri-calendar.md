# Hijri Date and Islamic Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show today's Hijri date and a countdown to the next major Islamic occasion on the Today screen, with a user-adjustable ±2 day offset in Settings.

**Architecture:** A dependency-free tabular (civil) Hijri converter in `lib/utils/`, a `const` events table in `lib/data/`, a `SharedPreferences`-backed offset service that publishes through a `ValueNotifier`, and one card widget. The Today screen wraps the card in a `ValueListenableBuilder` so changing the offset in Settings updates it immediately — necessary because `MainNavigation` keeps all five tabs alive, so `initState` never re-runs on tab switch.

**Tech Stack:** Flutter, Dart 3 (records, pattern-typed returns), `shared_preferences` (already a dependency), `flutter_test`. **No new package dependencies.**

**Design doc:** `docs/superpowers/specs/2026-08-08-hijri-calendar-design.md`

## Global Constraints

- **No new package dependencies.** Do not add `hijri`, `intl`, or anything else to `pubspec.yaml`.
- **Package name is `flutter_development`.** Test imports are `package:flutter_development/...`.
- **Western digits everywhere** (`8 صفر 1448`, not `٨ صفر ١٤٤٨`). The rest of the app already uses Western digits; matching it is the point.
- **Arabic UI strings, Egyptian Arabic code comments.** This matches every existing file in the repo.
- **Colors come from `context.palette`** (`AppPalette` `ThemeExtension`). Never write a literal `Color(...)` in a widget.
- **Spacing and radii come from `AppSpace` and `AppRadius`** in `lib/theme/app_theme.dart`.
- **`lib/utils/hijri_date.dart` must not import anything from `package:flutter`.** That is what makes it unit-testable without a widget harness.
- **The Today screen is LTR** (no `Directionality` wrapper around its list). Its cards get right alignment with `CrossAxisAlignment.end` and `textAlign: TextAlign.right`. The Settings screen *is* wrapped in `Directionality(textDirection: TextDirection.rtl)` — use `CrossAxisAlignment.start` there.
- **No new notification IDs.** `NotificationService` uses fixed IDs 1 and 2; this feature schedules nothing.
- **Do not touch `test/widget_test.dart`.** It is the unmodified Flutter template.
- **Commit after every task** using conventional commit prefixes (`feat:`, `test:`, `refactor:`).

## File Structure

| File | Responsibility |
|---|---|
| `lib/utils/hijri_date.dart` (new) | `HijriDate` value type, Gregorian↔Hijri arithmetic, Arabic name lists and formatters. Pure Dart. |
| `lib/data/islamic_events.dart` (new) | `IslamicEvent`, the `const` events table, `nextEvent()`. |
| `lib/services/hijri_prefs.dart` (new) | Reads/writes the day offset, publishes it via `ValueNotifier`. |
| `lib/widgets/hijri_date_card.dart` (new) | The Today-screen card. Pure presentation, no I/O. |
| `test/hijri_date_test.dart` (new) | Conversion and formatting tests. |
| `test/islamic_events_test.dart` (new) | `nextEvent()` tests. |
| `lib/main.dart` (modify) | One line: preload the stored offset before the first frame. |
| `lib/screens/today_screen.dart` (modify) | Insert the card between `_HeroPanel` and `_ResumeListeningCard`. |
| `lib/screens/settings_screen.dart` (modify) | New التقويم الهجري section with the ± control. |

## Reference: verified anchor values

Every number below was derived by hand from the tabular calendar and cross-checked in both directions **before** any code was written. Do not "fix" a failing test by changing these — if a test fails, the implementation is wrong.

| Gregorian (UTC) | Julian Day Number | Hijri |
|---|---|---|
| 622-07-19 | 1948440 | 1-01-01 (epoch) |
| 2026-06-16 | 2461208 | 1447-12-30 |
| 2026-06-17 | 2461209 | 1448-01-01 |
| 2026-07-16 | 2461238 | 1448-01-30 |
| 2026-07-17 | 2461239 | 1448-02-01 |
| 2026-08-08 | 2461261 | 1448-02-23 |
| 2027-02-08 | 2461445 | 1448-09-01 |

Leap positions in the 30-year cycle: `{2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29}`.
`1447 % 30 == 7` → leap (355 days). `1448 % 30 == 8` → common (354 days).
2026-08-08 is a Saturday (`DateTime(2026, 8, 8).weekday == 6`).

---

### Task 1: Hijri conversion core

**Files:**
- Create: `lib/utils/hijri_date.dart`
- Test: `test/hijri_date_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class HijriDate` with `const HijriDate(int year, int month, int day)`, fields `year`/`month`/`day`, `factory HijriDate.fromJdn(int jdn)`, `factory HijriDate.fromGregorian(DateTime date, {int offset = 0})`, `int toJdn()`, `DateTime toGregorian()` (returns UTC), `static bool isLeapYear(int hijriYear)`, `static int daysInMonth(int hijriYear, int month)`, plus `==` / `hashCode` / `toString`.

- [ ] **Step 1: Write the failing test**

Create `test/hijri_date_test.dart`:

```dart
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
      expect(HijriDate.fromGregorian(base, offset: 1),
          const HijriDate(1448, 2, 24));
      expect(HijriDate.fromGregorian(base, offset: -1),
          const HijriDate(1448, 2, 22));
      expect(HijriDate.fromGregorian(base, offset: 2),
          const HijriDate(1448, 2, 25));
    });
  });

  group('HijriDate.toGregorian', () {
    test('known anchors', () {
      expect(const HijriDate(1, 1, 1).toGregorian(), DateTime.utc(622, 7, 19));
      expect(const HijriDate(1448, 2, 23).toGregorian(),
          DateTime.utc(2026, 8, 8));
      expect(const HijriDate(1448, 9, 1).toGregorian(),
          DateTime.utc(2027, 2, 8));
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
      expect(const HijriDate(1448, 2, 23) == const HijriDate(1448, 2, 24),
          isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```
flutter test test/hijri_date_test.dart
```

Expected: compile failure — `Target of URI doesn't exist: 'package:flutter_development/utils/hijri_date.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/utils/hijri_date.dart`:

```dart
/// تحويل بين الميلادي والهجري بالتقويم الهجري الجدولي (المدني).
///
/// الملف ده رياضيات صافية — مفيش أي import من Flutter، عشان يتاخد له
/// unit test من غير ما نشغّل widget harness.
library;

/// رقم اليوم اليولياني لأول محرم سنة 1 هـ (16 يوليو 622 ميلادي يولياني).
const int _hijriEpochJdn = 1948440;

/// مواقع السنين الكبيسة جوّه دورة الـ30 سنة. السنة الكبيسة 355 يوم
/// والعادية 354.
const Set<int> _leapPositions = {2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29};

/// تاريخ هجري بقيمة ثابتة — مقارنة بالقيمة مش بالمرجع.
class HijriDate {
  final int year;
  final int month; // 1..12
  final int day; // 1..30

  const HijriDate(this.year, this.month, this.day);

  /// من رقم اليوم اليولياني — خوارزمية الكويت للتقويم الجدولي.
  factory HijriDate.fromJdn(int jdn) {
    int l = jdn - _hijriEpochJdn + 10632;
    final int n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final int j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final int month = (24 * l) ~/ 709;
    final int day = l - (709 * month) ~/ 24;
    final int year = 30 * n + j - 30;
    return HijriDate(year, month, day);
  }

  /// بيستعمل اليوم والشهر والسنة بس، والوقت بيتجاهل.
  ///
  /// [offset] بيزحزح التاريخ الهجري بأيام كاملة: +1 يعني الهجري يبقى
  /// متقدّم يوم عن الحساب الجدولي. الزحزحة بتتم على رقم اليوم اليولياني
  /// مش على DateTime، فالتوقيت الصيفي مالوش أي تأثير هنا.
  factory HijriDate.fromGregorian(DateTime date, {int offset = 0}) =>
      HijriDate.fromJdn(
        _gregorianToJdn(date.year, date.month, date.day) + offset,
      );

  int toJdn() =>
      ((11 * year + 3) ~/ 30) +
      354 * year +
      30 * month -
      ((month - 1) ~/ 2) +
      day +
      _hijriEpochJdn -
      385;

  /// عكس [HijriDate.fromGregorian] عند offset صفر. بيرجّع UTC عشان
  /// المقارنة تبقى من غير لبس توقيت.
  DateTime toGregorian() => _jdnToGregorian(toJdn());

  static bool isLeapYear(int hijriYear) =>
      _leapPositions.contains(hijriYear % 30);

  static int daysInMonth(int hijriYear, int month) {
    if (month == 12) return isLeapYear(hijriYear) ? 30 : 29;
    return month.isOdd ? 30 : 29;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HijriDate &&
          other.year == year &&
          other.month == month &&
          other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'HijriDate($year-$month-$day)';
}

/// ميلادي إلى رقم يوم يولياني — Fliegel–Van Flandern.
///
/// الصيغة دي مبنية على قسمة بتقطع ناحية الصفر، وده اللي `~/` بيعمله في
/// Dart بالظبط. لو اتكتبت بـ floor بدل قطع، النتيجة هتغلط بيومين.
int _gregorianToJdn(int year, int month, int day) {
  final int a = (month - 14) ~/ 12;
  return (1461 * (year + 4800 + a)) ~/ 4 +
      (367 * (month - 2 - 12 * a)) ~/ 12 -
      (3 * ((year + 4900 + a) ~/ 100)) ~/ 4 +
      day -
      32075;
}

/// عكس [_gregorianToJdn].
DateTime _jdnToGregorian(int jdn) {
  int l = jdn + 68569;
  final int n = (4 * l) ~/ 146097;
  l = l - (146097 * n + 3) ~/ 4;
  final int i = (4000 * (l + 1)) ~/ 1461001;
  l = l - (1461 * i) ~/ 4 + 31;
  final int j = (80 * l) ~/ 2447;
  final int day = l - (2447 * j) ~/ 80;
  final int k = j ~/ 11;
  final int month = j + 2 - 12 * k;
  final int year = 100 * (n - 49) + i + k;
  return DateTime.utc(year, month, day);
}
```

- [ ] **Step 4: Run the test and verify it passes**

```
flutter test test/hijri_date_test.dart
flutter analyze
```

Expected: all tests pass, no new analyzer issues.

If an anchor fails, the bug is in the code, not the table. The two most likely causes: writing `(month - 14) / 12` with `floor()` semantics instead of `~/`, or getting the `- 385` term in `toJdn()` wrong.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/hijri_date.dart test/hijri_date_test.dart
git commit -m "feat: add tabular Hijri calendar conversion"
```

---

### Task 2: Arabic names and formatting

**Files:**
- Modify: `lib/utils/hijri_date.dart` (append the name lists and formatters, add two members to `HijriDate`)
- Test: `test/hijri_date_test.dart` (append a new group)

**Interfaces:**
- Consumes: `HijriDate` from Task 1.
- Produces: `String get monthNameAr` and `String formatAr()` on `HijriDate`; top-level `const List<String> hijriMonthNamesAr`, `gregorianMonthNamesAr`, `weekdayNamesAr`; top-level `String formatGregorianAr(DateTime date)` and `String formatDaysAr(int days)`.

- [ ] **Step 1: Write the failing test**

Append to `test/hijri_date_test.dart`, inside `main()`:

```dart
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
```

`DateTime(2026, 8, 8).weekday` is 6 (Saturday) and `DateTime(2027, 2, 8).weekday` is 1 (Monday) — both were checked against the Julian Day Number, not guessed.

- [ ] **Step 2: Run the test and verify it fails**

```
flutter test test/hijri_date_test.dart
```

Expected: compile failure — `The method 'formatGregorianAr' isn't defined`, `The getter 'monthNameAr' isn't defined for the class 'HijriDate'`, and similar.

- [ ] **Step 3: Write the implementation**

Add these two members inside `class HijriDate`, right after `daysInMonth`:

```dart
  String get monthNameAr => hijriMonthNamesAr[month - 1];

  /// "23 صفر 1448 هـ" — أرقام غربية زي باقي التطبيق.
  String formatAr() => '$day $monthNameAr $year هـ';
```

Append at the end of `lib/utils/hijri_date.dart`:

```dart
const List<String> hijriMonthNamesAr = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

const List<String> gregorianMonthNamesAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// `DateTime.weekday` في Dart بيبدأ من الاثنين = 1، فالليستة مترتبة كده.
const List<String> weekdayNamesAr = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// "السبت 8 أغسطس 2026".
String formatGregorianAr(DateTime date) =>
    '${weekdayNamesAr[date.weekday - 1]} ${date.day} '
    '${gregorianMonthNamesAr[date.month - 1]} ${date.year}';

/// عدّ الأيام بمطابقة العدد العربية: يوم واحد / يومين / 3 أيام / 11 يوم.
String formatDaysAr(int days) {
  if (days == 1) return 'يوم واحد';
  if (days == 2) return 'يومين';
  if (days >= 3 && days <= 10) return '$days أيام';
  return '$days يوم';
}
```

- [ ] **Step 4: Run the test and verify it passes**

```
flutter test test/hijri_date_test.dart
flutter analyze
```

Expected: all tests pass, no new analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/hijri_date.dart test/hijri_date_test.dart
git commit -m "feat: add Arabic Hijri and Gregorian date formatting"
```

---

### Task 3: Islamic events table and next-event lookup

**Files:**
- Create: `lib/data/islamic_events.dart`
- Test: `test/islamic_events_test.dart`

**Interfaces:**
- Consumes: `HijriDate` and `HijriDate.toJdn()` from Task 1.
- Produces: `class IslamicEvent` with named constructor parameters `{required int month, required int day, required String nameAr, int durationDays = 1}`; `class IslamicEvents` with `static const List<IslamicEvent> all`; `typedef NextEvent = ({IslamicEvent event, int daysRemaining, int dayInEvent})`; `NextEvent nextEvent(HijriDate today)`.

Contract for `nextEvent`, relied on by Tasks 5 and 6:
- An occasion whose span covers `today` wins over any later one.
- Upcoming occasion: `daysRemaining > 0`, `dayInEvent == 0`.
- Occasion running today: `daysRemaining == 0`, `dayInEvent >= 1` (1-based).
- If everything in the current Hijri year has passed, the first occasion of the next year is returned.

- [ ] **Step 1: Write the failing test**

Create `test/islamic_events_test.dart`:

```dart
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
      var date = const HijriDate(1448, 1, 1);
      final endJdn = const HijriDate(1449, 1, 1).toJdn();
      for (var jdn = date.toJdn(); jdn < endJdn; jdn++) {
        date = HijriDate.fromJdn(jdn);
        final result = nextEvent(date);
        expect(result.daysRemaining, greaterThanOrEqualTo(0), reason: '$date');
        expect(result.dayInEvent, greaterThanOrEqualTo(0), reason: '$date');
      }
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```
flutter test test/islamic_events_test.dart
```

Expected: compile failure — `Target of URI doesn't exist: 'package:flutter_development/data/islamic_events.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/data/islamic_events.dart`:

```dart
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
```

- [ ] **Step 4: Run the test and verify it passes**

```
flutter test
flutter analyze
```

Expected: both test files pass, no new analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/data/islamic_events.dart test/islamic_events_test.dart
git commit -m "feat: add Islamic events table and next-event lookup"
```

---

### Task 4: Offset preference service

**Files:**
- Create: `lib/services/hijri_prefs.dart`
- Modify: `lib/main.dart:1-26`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `HijriPrefs.offsetNotifier` (`static final ValueNotifier<int>`), `HijriPrefs.minOffset` (`-2`), `HijriPrefs.maxOffset` (`2`), `static Future<int> load()`, `static Future<void> setOffset(int value)`.

There is no test for this task. `SharedPreferences` needs a widget-test binding and a mock store, and the project has no such harness. The clamping logic is three lines with no branches worth defending; the tasks that matter are already covered.

- [ ] **Step 1: Write the service**

Create `lib/services/hijri_prefs.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إزاحة التاريخ الهجري بالأيام — التقويم الجدولي ممكن يفرق يوم عن رؤية
/// الهلال، والفرق ده بيختلف من بلد لبلد، فالمستخدم بيظبطه بنفسه.
///
/// القيمة منشورة في [offsetNotifier] عشان شاشة "اليوم" تتحدّث لحظياً لما
/// المستخدم يغيّرها من الإعدادات — التبويبات بتفضل حيّة فـ initState مش
/// بيتنده تاني عند التبديل بينها.
class HijriPrefs {
  static const String _kOffset = 'hijri_day_offset';

  static const int minOffset = -2;
  static const int maxOffset = 2;

  static final ValueNotifier<int> offsetNotifier = ValueNotifier<int>(0);

  static int _clamp(int value) => value.clamp(minOffset, maxOffset);

  /// بتتنده مرة واحدة عند بداية التطبيق. بتقصّ القيمة المحفوظة كمان عشان
  /// قيمة قديمة أو تالفة ما تطلّعش تاريخ غلط.
  static Future<int> load() async {
    final prefs = await SharedPreferences.getInstance();
    final int value = _clamp(prefs.getInt(_kOffset) ?? 0);
    offsetNotifier.value = value;
    return value;
  }

  static Future<void> setOffset(int value) async {
    final int clamped = _clamp(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kOffset, clamped);
    offsetNotifier.value = clamped;
  }
}
```

- [ ] **Step 2: Preload the offset in `main()`**

In `lib/main.dart`, add the import alongside the existing ones:

```dart
import 'services/hijri_prefs.dart';
```

Then replace this block:

```dart
  // قراءة الثيم المحفوظ قبل بناء الواجهة لمنع ظهور وميض بلون مختلف
  final prefs = await SharedPreferences.getInstance();
  final bool initialDarkMode = prefs.getBool('theme_is_dark_mode') ?? true;

  runApp(AdhkariApp(initialDarkMode: initialDarkMode));
```

with:

```dart
  // قراءة الثيم المحفوظ قبل بناء الواجهة لمنع ظهور وميض بلون مختلف
  final prefs = await SharedPreferences.getInstance();
  final bool initialDarkMode = prefs.getBool('theme_is_dark_mode') ?? true;

  // إزاحة التاريخ الهجري كمان بتتقري قبل أول frame عشان الكارت ما يظهرش
  // بتاريخ غير مظبوط وبعدين يتغيّر قدام المستخدم
  await HijriPrefs.load();

  runApp(AdhkariApp(initialDarkMode: initialDarkMode));
```

- [ ] **Step 3: Verify it compiles and the app still starts**

```
flutter analyze
flutter test
```

Expected: no new analyzer issues, existing tests still pass.

- [ ] **Step 4: Commit**

```bash
git add lib/services/hijri_prefs.dart lib/main.dart
git commit -m "feat: persist and publish the Hijri day offset"
```

---

### Task 5: The Today-screen card widget

**Files:**
- Create: `lib/widgets/hijri_date_card.dart`

**Interfaces:**
- Consumes: `HijriDate`, `formatGregorianAr`, `formatDaysAr` (Task 1 and 2); `IslamicEvent` (Task 3); `AppCard` from `lib/widgets/app_card.dart`; `context.palette`, `AppSpace` from `lib/theme/app_theme.dart`.
- Produces: `class HijriDateCard extends StatelessWidget` with the named parameters `{Key? key, required HijriDate hijri, required DateTime gregorian, required IslamicEvent nextEvent, required int daysRemaining, required int dayInEvent, VoidCallback? onTap}`.

No widget test. The card has no logic beyond string selection, the project has no widget-test infrastructure, and the spec ruled widget tests out.

The Today screen is **not** wrapped in a `Directionality`, so this card follows the convention its neighbours use: `CrossAxisAlignment.end` and `textAlign: TextAlign.right` (see `_ProgressCard` and `_TasbihGoalCard` in `today_screen.dart`).

Note on naming: the card has a field called `nextEvent` while `islamic_events.dart` exports a top-level function of the same name. Inside the class body the field wins, which is what this widget wants — it never calls the function. Both names come straight from the design doc; do not rename either.

- [ ] **Step 1: Write the widget**

Create `lib/widgets/hijri_date_card.dart`:

```dart
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
```

- [ ] **Step 2: Verify it compiles**

```
flutter analyze
```

Expected: no new analyzer issues. The widget is unused at this point, which is fine — Task 6 wires it in.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/hijri_date_card.dart
git commit -m "feat: add the Hijri date card widget"
```

---

### Task 6: Today-screen integration

**Files:**
- Modify: `lib/screens/today_screen.dart:1-12` (imports) and `lib/screens/today_screen.dart:149-162` (the list children)

**Interfaces:**
- Consumes: `HijriDateCard` (Task 5), `HijriPrefs.offsetNotifier` (Task 4), `HijriDate.fromGregorian` (Task 1), `nextEvent` (Task 3).
- Produces: nothing for later tasks.

`_TodaySummary` is left alone. The conversion is pure integer arithmetic with no I/O, so recomputing it on every rebuild costs nothing and there is no reason to thread it through the summary future.

- [ ] **Step 1: Add the imports**

In `lib/screens/today_screen.dart`, add to the existing import block (keep it alphabetical within each group, matching the file's current style):

```dart
import '../data/islamic_events.dart';
import '../services/hijri_prefs.dart';
import '../utils/hijri_date.dart';
import '../widgets/hijri_date_card.dart';
```

- [ ] **Step 2: Insert the card into the list**

In `build()`, inside the `ListView` children, find:

```dart
                _HeroPanel(
                  streak: summary.streak,
                  openAzkar: widget.openAzkar,
                ),
                const SizedBox(height: 16),
```

and insert this immediately after that `SizedBox`, before the `_ResumeListeningCard` comment block:

```dart
                // التاريخ الهجري بيتحسب جوّه الـ builder — حساب صحيح خالص
                // من غير I/O، فمفيش داعي يعدّي على _TodaySummary. الـ
                // ValueListenableBuilder هو اللي بيخلي الكارت يتحدّث لحظياً
                // لما الإزاحة تتغيّر من الإعدادات، لأن التبويبات بتفضل حيّة
                // و initState مش بيتنده تاني.
                ValueListenableBuilder<int>(
                  valueListenable: HijriPrefs.offsetNotifier,
                  builder: (context, offset, _) {
                    final now = DateTime.now();
                    final hijri = HijriDate.fromGregorian(now, offset: offset);
                    final upcoming = nextEvent(hijri);
                    return HijriDateCard(
                      hijri: hijri,
                      gregorian: now,
                      nextEvent: upcoming.event,
                      daysRemaining: upcoming.daysRemaining,
                      dayInEvent: upcoming.dayInEvent,
                      onTap: widget.openSettings,
                    );
                  },
                ),
                const SizedBox(height: 12),
```

- [ ] **Step 3: Verify**

```
flutter analyze
flutter test
```

Expected: no new analyzer issues, all tests pass.

Then run the app and check the Today screen: the Hijri date sits directly under the greeting panel, above "تابع الاستماع", and tapping it opens Settings.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/today_screen.dart
git commit -m "feat: show the Hijri date on the Today screen"
```

---

### Task 7: Settings-screen offset control

**Files:**
- Modify: `lib/screens/settings_screen.dart:1-8` (imports), `:104-116` (insert the section after المظهر), and append a new private widget at the end of the file.

**Interfaces:**
- Consumes: `HijriPrefs` (Task 4), `HijriDate.fromGregorian` and `formatAr` (Tasks 1 and 2), `SectionTitle` and `AppCard` from `lib/widgets/app_card.dart`.
- Produces: nothing for later tasks.

This screen **is** wrapped in `Directionality(textDirection: TextDirection.rtl)`, so use `CrossAxisAlignment.start` here — the opposite of the Today card. That is not an inconsistency; it is what each screen's direction requires to left-pin text on the right edge.

- [ ] **Step 1: Add the import**

In `lib/screens/settings_screen.dart`:

```dart
import '../services/hijri_prefs.dart';
import '../utils/hijri_date.dart';
```

- [ ] **Step 2: Insert the section**

Find the end of the المظهر section in `build()`:

```dart
                  const SectionTitle('المظهر'),
                  AppCard(
                    child: _ThemeTile(
                      isDark: isDark,
                      onToggle: widget.toggleTheme,
                    ),
                  ),
                  const SizedBox(height: 20),
```

and insert immediately after it, before `const SectionTitle('مواعيد التذكير')`:

```dart
                  // ————— التقويم الهجري —————
                  const SectionTitle('التقويم الهجري'),
                  const _HijriOffsetCard(),
                  const SizedBox(height: 20),
```

- [ ] **Step 3: Add the widget**

Append to the end of `lib/screens/settings_screen.dart`:

```dart
/// ضبط إزاحة التاريخ الهجري.
///
/// التقويم الجدولي ممكن يسبق أو يتأخر يوم عن رؤية الهلال المحلية، فالكارت
/// ده بيخلي المستخدم يوفّق التاريخ على بلده. المعاينة بتتحدّث فوراً عشان
/// يشوف بعينه أي إزاحة هي الصح.
class _HijriOffsetCard extends StatelessWidget {
  const _HijriOffsetCard();

  Future<void> _change(BuildContext context, int delta) async {
    final int next = HijriPrefs.offsetNotifier.value + delta;
    await HijriPrefs.setOffset(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ إعدادات التقويم')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ValueListenableBuilder<int>(
      valueListenable: HijriPrefs.offsetNotifier,
      builder: (context, offset, _) {
        final hijri = HijriDate.fromGregorian(DateTime.now(), offset: offset);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تعديل التاريخ الهجري',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'لو التاريخ فارق عندك يوم، ظبّطه من هنا.',
                style: TextStyle(fontSize: 13, color: p.textMuted),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                hijri.formatAr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: p.primary,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: offset > HijriPrefs.minOffset
                        ? () => _change(context, -1)
                        : null,
                    icon: const Icon(Icons.remove),
                    tooltip: 'يوم أقل',
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      offset > 0 ? '+$offset' : '$offset',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: offset < HijriPrefs.maxOffset
                        ? () => _change(context, 1)
                        : null,
                    icon: const Icon(Icons.add),
                    tooltip: 'يوم أكتر',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

The buttons go disabled at the range ends rather than silently swallowing the tap — a dead button that looks alive reads as a bug.

`IconButton.outlined` needs Flutter 3.7 or newer. If `flutter analyze` reports it as undefined, the toolchain is older than that: swap both buttons for `OutlinedButton` with an `Icon` child and `style: OutlinedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(12))`. Everything else stays as written.

- [ ] **Step 4: Verify**

```
flutter analyze
flutter test
```

Expected: no new analyzer issues, all tests pass.

Then check on a device, in this order:
1. Settings shows التقويم الهجري between المظهر and مواعيد التذكير.
2. Pressing + shifts the preview date forward by one day; − shifts it back.
3. At +2 the + button is disabled; at −2 the − button is disabled.
4. Switch to the Today tab **without restarting** — the card shows the shifted date. This is the case the `ValueNotifier` exists for; if it fails, the notifier is not being updated.
5. Restart the app — the offset survives.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add the Hijri date offset control to Settings"
```

---

## Done when

- `flutter test` passes, including the two new test files.
- `flutter analyze` reports no new issues.
- The Today screen shows the Hijri date, the Gregorian date, and the next occasion.
- Changing the offset in Settings updates the Today card without a restart, and survives one.
- `pubspec.yaml` is unchanged.
