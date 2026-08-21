import 'package:adhkari/data/islamic_events.dart';
import 'package:adhkari/theme/app_theme.dart';
import 'package:adhkari/utils/hijri_date.dart';
import 'package:adhkari/widgets/hijri_date_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// الاختبار ده كان بيرندر `Scaffold(body: Text('أذكاري'))` ويتأكد إن النص
/// موجود — يعني كان بيختبر فلاتر نفسها مش التطبيق. دلوقتي بيختبر widget
/// حقيقي من التطبيق.
///
/// اخترنا [HijriDateCard] لأنه مبيعملش أي I/O ولا بيعتمد على plugin،
/// فينفع يتختبر من غير mocks لـ SharedPreferences أو audio_service.
void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppThemeData.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );

  group('HijriDateCard', () {
    testWidgets('بيعرض التاريخ الهجري والميلادي', (tester) async {
      const hijri = HijriDate(1448, 2, 23);
      final gregorian = DateTime(2026, 8, 8); // السبت
      final upcoming = nextEvent(hijri);

      await tester.pumpWidget(
        wrap(
          HijriDateCard(
            hijri: hijri,
            gregorian: gregorian,
            nextEvent: upcoming.event,
            daysRemaining: upcoming.daysRemaining,
            dayInEvent: upcoming.dayInEvent,
          ),
        ),
      );

      expect(find.text('23 صفر 1448 هـ'), findsOneWidget);
      expect(find.text('السبت 8 أغسطس 2026'), findsOneWidget);
    });

    testWidgets('المناسبة الشغالة بتقول اليوم الكام مش "باقي صفر يوم"', (
      tester,
    ) async {
      // 15 رمضان — جوّه مناسبة مدتها 30 يوم
      const hijri = HijriDate(1448, 9, 15);
      final upcoming = nextEvent(hijri);

      await tester.pumpWidget(
        wrap(
          HijriDateCard(
            hijri: hijri,
            gregorian: DateTime(2027, 2, 20),
            nextEvent: upcoming.event,
            daysRemaining: upcoming.daysRemaining,
            dayInEvent: upcoming.dayInEvent,
          ),
        ),
      );

      expect(find.text('أول رمضان — اليوم 15'), findsOneWidget);
      expect(find.textContaining('باقي'), findsNothing);
    });

    testWidgets('الدوس على الكارت بينده onTap', (tester) async {
      const hijri = HijriDate(1448, 2, 23);
      final upcoming = nextEvent(hijri);
      var taps = 0;

      await tester.pumpWidget(
        wrap(
          HijriDateCard(
            hijri: hijri,
            gregorian: DateTime(2026, 8, 8),
            nextEvent: upcoming.event,
            daysRemaining: upcoming.daysRemaining,
            dayInEvent: upcoming.dayInEvent,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('23 صفر 1448 هـ'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('context.palette', () {
    testWidgets('مبيرميش لو الثيم مفيهوش AppPalette', (tester) async {
      // قبل الإصلاح كان `extension<AppPalette>()!` بيرمي null-check error
      // في أي شجرة الثيم بتاعها مش بتاعنا.
      late AppPalette resolved;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              resolved = context.palette;
              return const SizedBox.shrink();
            },
          ),
          theme: ThemeData.light(), // ثيم فلاتر العادي — من غير الامتداد
        ),
      );

      expect(tester.takeException(), isNull);
      expect(resolved.primary, AppPalette.light.primary);
    });

    testWidgets('بترجع اللوحة الداكنة مع الثيم الداكن', (tester) async {
      late AppPalette resolved;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              resolved = context.palette;
              return const SizedBox.shrink();
            },
          ),
          theme: ThemeData.dark(),
        ),
      );

      expect(resolved.primary, AppPalette.dark.primary);
    });
  });
}
