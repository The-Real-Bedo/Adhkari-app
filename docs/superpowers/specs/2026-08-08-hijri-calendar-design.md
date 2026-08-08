# Hijri Date and Islamic Events — Design

**Date:** 2026-08-08
**Project:** Adhkari (`flutter_development`)
**Status:** Awaiting review

## Summary

Add the Hijri (Islamic lunar) date to the app, along with a countdown to the next
major Islamic occasion. The date appears on the Today screen and adapts to a
user-configurable day offset set in Settings.

The feature is self-contained: no network access, no new permissions, and no new
package dependency. It touches two existing screens and adds four new files.

## Goals

1. Show today's Hijri date in Arabic on the Today screen, alongside the Gregorian date.
2. Show which Islamic month we are currently in.
3. Show the next major Islamic occasion and how many days remain until it.
4. Let the user shift the Hijri date by −2 to +2 days to match their local moon sighting.
5. Introduce the repository's first real unit test suite, covering the conversion.

## Non-Goals

These are deliberately excluded from this spec. Each may become its own project later.

- **A month-grid calendar screen.** The countdown card covers the stated need. A
  browsable calendar is a separate screen with its own navigation and layout work.
- **Fasting-day marking** (Mondays, Thursdays, the white days 13–15). These are
  recurring monthly markers whose natural home is the calendar grid above, not the
  events list. Note: an earlier sketch of this design listed the white days in the
  events data file; they are dropped here to match the agreed scope.
- **Fasting reminders / notifications.** No new notification IDs are allocated.
- **Laylat al-Qadr.** Its date is not fixed by consensus, so pinning it to a specific
  night would assert a position the app should not take.
- **Prayer times and Qibla.** Separate features, separate specs.

## Background: why the date needs an offset

The Hijri calendar in civil use is *tabular* — months alternate 30 and 29 days on a
fixed 30-year cycle. Real Islamic months begin on local sighting of the crescent, so
the tabular date can differ from the observed date by one day, and the direction of
that difference varies by country and by month.

Every serious Hijri implementation therefore exposes a user adjustment. This design
persists a single integer offset, clamped to the range −2…+2, which covers the
observed spread.

## Architecture

Four new files, two modified. The layering matches the existing codebase: pure data
and logic at the bottom, a thin `SharedPreferences` service in the middle, widgets on
top reading through `context.palette`.

```
lib/utils/hijri_date.dart        pure math, no Flutter import
lib/data/islamic_events.dart     const event table
lib/services/hijri_prefs.dart    offset read/write
lib/widgets/hijri_date_card.dart Today-screen card
```

```
main.dart              modified — one line, preload the stored offset
today_screen.dart      modified — insert card
settings_screen.dart   modified — offset adjustment control
```

### `lib/utils/hijri_date.dart`

A pure value type plus the conversion arithmetic. No `package:flutter` import, which
is what makes it testable without a widget harness.

```dart
class HijriDate {
  final int year;
  final int month;   // 1..12
  final int day;     // 1..30

  const HijriDate(this.year, this.month, this.day);

  /// Converts a Gregorian date. [offset] shifts the result by whole days:
  /// +1 makes the Hijri date one day later than the tabular value.
  factory HijriDate.fromGregorian(DateTime date, {int offset = 0});

  /// Inverse of [fromGregorian] with offset 0.
  DateTime toGregorian();

  String get monthNameAr;
  String formatAr();          // "١٥ رمضان ١٤٤٧ هـ" style, see Number formatting
  static bool isLeapYear(int hijriYear);
  static int daysInMonth(int hijriYear, int month);
}
```

**Algorithm.** The tabular (civil) Islamic calendar:

- Epoch: Julian Day Number 1948440, corresponding to 16 July 622 CE (Julian), the
  civil epoch variant.
- Leap years are years 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, and 29 of each 30-year
  cycle. A leap year has 355 days; a common year 354.
- Odd-numbered months have 30 days, even-numbered months 29, except month 12, which
  has 30 days in a leap year.

Conversion runs Gregorian → Julian Day Number → Hijri, and the reverse for
`toGregorian()`. Working through JDN avoids special-casing the Gregorian leap rules
twice.

**Offset semantics.** `fromGregorian(d, offset: n)` is defined as converting
`d.add(Duration(days: n))`. Stating it this way removes the ambiguity of "does +1
move the Hijri date forward or the Gregorian date forward" — it moves the Hijri
date forward. `toGregorian()` is the exact inverse only at offset 0; this asymmetry
is intentional and documented in the code, since the offset is a display correction
rather than part of the calendar's definition.

**Time zone.** Conversion uses the date components of the `DateTime` passed in and
ignores the time of day. Callers pass `DateTime.now()`, which is local time, so the
date rolls over at the device's local midnight. The Hijri day formally begins at
sunset, but honouring that would require the sunset time and therefore a location
permission, which this feature is designed not to need.

**Month names.** A `const` list, in order: محرم، صفر، ربيع الأول، ربيع الآخر، جمادى
الأولى، جمادى الآخرة، رجب، شعبان، رمضان، شوال، ذو القعدة، ذو الحجة.

### `lib/data/islamic_events.dart`

A `const` table, following the pattern of `data/azkar_data.dart`.

```dart
class IslamicEvent {
  final int month;      // Hijri month, 1..12
  final int day;        // Hijri day
  final String nameAr;
  final int durationDays;   // 1 for single days; 30 for Ramadan
}
```

| Occasion | Hijri date | Arabic |
|---|---|---|
| Islamic New Year | 1 Muharram | رأس السنة الهجرية |
| Ashura | 10 Muharram | يوم عاشوراء |
| Start of Ramadan | 1 Ramadan | أول رمضان |
| Eid al-Fitr | 1 Shawwal | عيد الفطر |
| Day of Arafah | 9 Dhu al-Hijjah | يوم عرفة |
| Eid al-Adha | 10 Dhu al-Hijjah | عيد الأضحى |

Ramadan carries `durationDays: 30` so the card can say "you are in Ramadan" rather
than counting down to a day that has passed.

### Next-event computation

A function in the same file:

```dart
/// The next occasion on or after [today], with the whole days remaining.
/// Returns the first event of the following Hijri year if all of this
/// year's events have passed. An occasion whose span covers [today]
/// wins over any later one: `daysRemaining` is 0 and `dayInEvent` is
/// the 1-based day within the occasion. For a purely future occasion,
/// `dayInEvent` is 0.
({IslamicEvent event, int daysRemaining, int dayInEvent}) nextEvent(
  HijriDate today,
);
```

`dayInEvent` is what lets the card say "you are on day 15 of Ramadan" rather
than "Ramadan — 0 days remaining", which is why a multi-day occasion needs more
than a countdown.

Days remaining is computed by converting both the candidate event and today back to
Gregorian and subtracting, rather than by subtracting Hijri day numbers. Hijri
arithmetic would have to account for variable month lengths and the year boundary;
the Gregorian difference is a plain subtraction and is much harder to get wrong.

### `lib/services/hijri_prefs.dart`

Matches the shape of the existing `quran_prefs.dart`: a class of static methods over
`SharedPreferences`.

```dart
class HijriPrefs {
  static const String _kOffset = 'hijri_day_offset';
  static const int minOffset = -2;
  static const int maxOffset = 2;

  /// Current offset, published so screens rebuild when it changes.
  static final ValueNotifier<int> offsetNotifier = ValueNotifier<int>(0);

  static Future<int> load();                // reads, clamps, publishes
  static Future<void> setOffset(int value); // clamps, writes, publishes
}
```

Clamping on both read and write means a corrupted or out-of-range stored value
cannot produce a nonsensical date.

`main()` calls `HijriPrefs.load()` at startup, alongside the existing theme
preload, so the notifier holds the stored value before the first frame.

### `lib/widgets/hijri_date_card.dart`

A `StatelessWidget` taking the already-loaded values, so it performs no I/O of its
own — the same division of labour the Today screen already uses for its summary
cards.

```dart
class HijriDateCard extends StatelessWidget {
  final HijriDate hijri;
  final DateTime gregorian;
  final IslamicEvent nextEvent;
  final int daysRemaining;
  final int dayInEvent;
  final VoidCallback? onTap;   // opens Settings for the offset adjustment
}
```

Layout, right-aligned to match the surrounding RTL cards:

- Line 1, large: the Hijri date — `١٥ رمضان ١٤٤٧ هـ`
- Line 2, muted: the Gregorian date — `الجمعة ٨ أغسطس ٢٠٢٦`
- Divider (`p.border`)
- Line 3: `يوم عرفة — باقي ٢١ يوم`, with `p.accent` for the occasion name

During Ramadan, line 3 instead reads `رمضان — اليوم ١٥`.

Built from `AppCard`, `AppRadius`, `AppSpace`, and `context.palette` — no literal
colors, consistent with the rest of the codebase.

### Number formatting

The app currently renders numbers with Western digits (`$count / $target` in
`today_screen.dart`, `_TasbihGoalCard`). Arabic-Indic digits (٠١٢٣) would look more
at home in a Hijri date but would be inconsistent with every other screen.

**Decision:** use Western digits, matching the existing app. Digit style is a
whole-app question and changing it in one card would make the inconsistency worse,
not better. The sample strings above show Arabic-Indic digits only for readability
in this document.

Gregorian month and weekday names come from a small `const` Arabic list in
`hijri_date.dart`, not from `intl` — adding a localization package for twelve
strings is not worth the dependency.

## Screen integration

### Today screen

The card is self-contained. It is wrapped in a `ValueListenableBuilder` on
`HijriPrefs.offsetNotifier`, and the conversion runs inside the builder:

```dart
ValueListenableBuilder<int>(
  valueListenable: HijriPrefs.offsetNotifier,
  builder: (context, offset, _) { /* convert and build the card */ },
)
```

Because the conversion is pure integer arithmetic with no I/O, it costs nothing to
recompute on rebuild, and the Hijri values therefore do not need to be threaded
through `_TodaySummary` or the existing `_loadSummary()` future. `_TodaySummary`
is left unchanged.

The card is inserted in the `ListView` between `_HeroPanel` and
`_ResumeListeningCard`, so the Hijri date sits directly under the greeting where the
eye lands first, and the listening card keeps its position immediately above the
progress row.

Tapping the card calls the existing `widget.openSettings` callback, which is already
wired through `MainNavigation`.

### Settings screen

A new section, placed after المظهر and before مواعيد التذكير, since it is a display
preference:

```
التقويم الهجري
┌──────────────────────────────────┐
│ تعديل التاريخ الهجري             │
│ ١٥ رمضان ١٤٤٧ هـ                 │
│         [ − ]   ٠   [ + ]        │
└──────────────────────────────────┘
```

Built from `SectionTitle` and `AppCard`. The − and + buttons are disabled at the
range ends rather than silently ignoring the tap. The preview line updates
immediately so the user can see which offset matches their local date, which is the
whole point of the control.

Saving follows the pattern already in `_SettingsScreenState`: write to
`SharedPreferences`, then show a `SnackBar`.

**Refresh coupling.** The Today screen loads its summary in `initState`, and
`MainNavigation` keeps all five tabs alive in a `List<Widget>`, so switching tabs
does not re-run `initState`. Without a signal, changing the offset in Settings would
leave the Today card showing the old date until the app restarted.

`HijriPrefs.offsetNotifier` is that signal: Settings writes through
`HijriPrefs.setOffset`, which updates the notifier, and the Today card rebuilds
immediately. A `ValueNotifier` on the service class matches how the app already
shares cross-screen state — `QuranAudioService` is a static singleton that screens
subscribe to in the same way. Adding a state-management package for one integer
would be out of proportion.

## Error handling

There is no I/O and no parsing in the conversion path, so there is no runtime failure
mode to handle:

- The conversion is total arithmetic over `int`. Every Gregorian date maps to exactly
  one Hijri date.
- A missing preference key returns the default of 0 via `?? 0`.
- A corrupted or out-of-range stored offset is clamped on read.
- `nextEvent` always returns a value, because the event table is non-empty and the
  search wraps to the following Hijri year.

The one boundary worth noting is dates far outside normal use — years before the
Hijri epoch produce meaningless results. The card only ever converts
`DateTime.now()`, so this cannot arise in the app; the tests document the behaviour
rather than the code defending against it.

## Testing

`test/hijri_date_test.dart` — the repository's first real test file. The existing
`test/widget_test.dart` is the unmodified Flutter template and is left alone.

Conversion tests:

- Known anchor dates convert correctly in both directions. Anchors are taken from
  the tabular civil calendar, and the expected values are computed independently
  before the code is written rather than read back out of the implementation.
- Round-trip: `HijriDate.fromGregorian(d).toGregorian()` returns `d` for a sweep of
  dates across several years.
- `isLeapYear` matches the 11-year set within a 30-year cycle.
- `daysInMonth` returns 30 for odd months, 29 for even months, and 30 for month 12
  in a leap year only.
- Month boundaries: the last day of a month is followed by day 1 of the next.
- Year boundaries: 30 Dhu al-Hijjah is followed by 1 Muharram of the next year.
- Offset: `offset: 1` produces the date one day after `offset: 0`, and `offset: -1`
  the day before.

Event tests:

- The day before an event returns that event with `daysRemaining == 1`.
- The day of an event returns it with `daysRemaining == 0`.
- A date after the last event of the Hijri year returns the first event of the next
  year, with a positive day count.
- A date inside Ramadan returns Ramadan, not the following Eid.

Widget tests are not planned. The card has no logic beyond formatting the values it
is handed, and the project has no widget-test infrastructure to build on.

## Verification

- `flutter analyze` reports no new issues.
- `flutter test` passes.
- Manual check on a running device: the Hijri date matches a known reference for the
  day; the offset control shifts it and survives an app restart.

## Implementation order

1. `hijri_date.dart` with its tests, written test-first. Nothing else depends on
   anything but this, and it is the only part where correctness is non-obvious.
2. `islamic_events.dart` and `nextEvent`, with tests.
3. `hijri_prefs.dart`.
4. `hijri_date_card.dart`.
5. Today screen integration.
6. Settings screen integration and the offset-changed notifier.

Steps 1 and 2 are pure and fully verifiable by `flutter test` alone. Steps 4 through
6 need a device or emulator to check visually.
