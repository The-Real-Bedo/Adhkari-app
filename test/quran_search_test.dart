import 'dart:convert';
import 'dart:io';

import 'package:adhkari/models/quran_models.dart';
import 'package:adhkari/screens/quran/mushaf_index_screen.dart';
import 'package:adhkari/screens/quran/surah_list_screen.dart';
import 'package:adhkari/services/quran_api_service.dart';
import 'package:adhkari/theme/app_theme.dart';
import 'package:adhkari/utils/arabic_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final suwar = [
    Surah(id: 1, name: 'الفاتحة', makkia: true),
    Surah(id: 2, name: 'البقرة', makkia: false),
    Surah(id: 12, name: 'يوسف', makkia: true),
  ];

  test('Arabic search normalizes Arabic and Persian digits', () {
    expect(normalizeArabic('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    expect(normalizeArabic('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    expect(normalizeArabic('  1٢۳  '), '123');
    expect(arabicContains('الأَعْرَاف', 'الاعراف'), isTrue);
  });

  for (final audio in [false, true]) {
    testWidgets(
      '${audio ? 'Audio' : 'Mushaf'} search accepts digits and clears',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'quran-search-test-',
        );
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => directory.path,
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          directory.deleteSync(recursive: true);
        });
        SharedPreferences.setMockInitialValues({
          'quran_suwar_cache': jsonEncode(
            suwar.map((s) => s.toCache()).toList(),
          ),
          'quran_cache_timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        QuranApiService.clearMemoryCache();
        final moshaf = Moshaf(
          id: 1,
          name: 'حفص',
          server: 'https://example.com/',
          surahList: {1, 2, 12},
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemeData.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: audio
                  ? SurahListScreen(
                      reciter: Reciter(id: 1, name: 'قارئ', moshaf: [moshaf]),
                      moshaf: moshaf,
                      allSuwar: suwar,
                    )
                  : const MushafIndexScreen(),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.byTooltip('مسح البحث'), findsNothing);

        for (final query in ['12', '١٢', '۱۲', ' ١2 ', 'يُوسُف']) {
          await tester.enterText(find.byType(TextField), query);
          await tester.pumpAndSettle();
          expect(find.text('سورة يوسف'), findsOneWidget);
          expect(find.text('سورة البقرة'), findsNothing);
          expect(find.text('سورة الفاتحة'), findsNothing);
        }

        await tester.enterText(find.byType(TextField), 'غير موجود');
        await tester.pumpAndSettle();
        expect(find.text('مفيش سورة بالاسم ده'), findsOneWidget);
        await tester.tap(find.byTooltip('مسح البحث'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
        expect(find.byTooltip('مسح البحث'), findsNothing);
        expect(find.text('سورة الفاتحة'), findsOneWidget);
        expect(find.text('سورة البقرة'), findsOneWidget);
        expect(find.text('سورة يوسف'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
