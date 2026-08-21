import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:adhkari/models/ayah.dart';
import 'package:adhkari/services/quran_api_service.dart';
import 'package:adhkari/services/quran_text_service.dart';
import 'package:adhkari/utils/arabic_text.dart';

/// Builds the shape alquran.cloud returns, so parseBody is tested against
/// realistic input instead of a hand-made structure.
String buildBody(List<Map<String, dynamic>> ayahs) => jsonEncode({
  'code': 200,
  'status': 'OK',
  'data': {'number': 2, 'name': 'سورة البقرة', 'ayahs': ayahs},
});

void main() {
  group('toArabicIndic', () {
    test('converts each digit', () {
      expect(toArabicIndic(0), '٠');
      expect(toArabicIndic(7), '٧');
      expect(toArabicIndic(123), '١٢٣');
      expect(toArabicIndic(286), '٢٨٦');
    });

    test('keeps the minus sign in front', () {
      expect(toArabicIndic(-5), '-٥');
    });
  });

  group('surahHasBasmala', () {
    test('is false for Al-Fatiha and At-Tawbah only', () {
      expect(surahHasBasmala(1), isFalse);
      expect(surahHasBasmala(9), isFalse);
      expect(surahHasBasmala(2), isTrue);
      expect(surahHasBasmala(8), isTrue);
      expect(surahHasBasmala(10), isTrue);
      expect(surahHasBasmala(114), isTrue);
    });
  });

  group('stripLeadingBasmala', () {
    test('removes a glued-on basmala', () {
      expect(stripLeadingBasmala('$basmala الٓمٓ'), 'الٓمٓ');
    });

    test('ignores differences in spelling and diacritics', () {
      expect(
        stripLeadingBasmala('بسم الله الرحمن الرحيم الٓمٓ ذلك الكتاب'),
        'الٓمٓ ذلك الكتاب',
      );
    });

    test('leaves a four-word ayah alone so Al-Fatiha keeps its first ayah', () {
      expect(stripLeadingBasmala(basmala), basmala);
    });

    test('leaves text that does not start with the basmala', () {
      const text = 'قُلْ هُوَ ٱللَّهُ أَحَدٌ';
      expect(stripLeadingBasmala(text), text);
    });

    test('returns empty for empty input', () {
      expect(stripLeadingBasmala('   '), '');
    });
  });

  group('Ayah', () {
    test('tryParse reads an integer ayah number', () {
      final ayah = Ayah.tryParse({'numberInSurah': 3, 'text': 'نص'});
      expect(ayah?.number, 3);
      expect(ayah?.text, 'نص');
    });

    test('tryParse accepts a numeric string', () {
      expect(Ayah.tryParse({'numberInSurah': '12', 'text': 'نص'})?.number, 12);
    });

    test('tryParse rejects missing, zero, and empty values', () {
      expect(Ayah.tryParse({'text': 'نص'}), isNull);
      expect(Ayah.tryParse({'numberInSurah': 0, 'text': 'نص'}), isNull);
      expect(Ayah.tryParse({'numberInSurah': 1, 'text': '   '}), isNull);
    });

    test('survives a cache round trip', () {
      const original = Ayah(number: 5, text: 'نص الآية');
      final restored = Ayah.fromCache(
        jsonDecode(jsonEncode(original.toCache())) as Map<String, dynamic>,
      );
      expect(restored, original);
    });

    test('fromCache rejects a corrupt entry', () {
      expect(Ayah.fromCache({'n': '5', 't': 'نص'}), isNull);
      expect(Ayah.fromCache({'n': 5, 't': ''}), isNull);
    });

    test('marker uses Arabic-Indic digits inside ornate parentheses', () {
      expect(const Ayah(number: 12, text: 'نص').marker, '﴿١٢﴾');
    });
  });

  group('QuranTextService.parseBody', () {
    test('reads every ayah in order', () {
      final ayahs = QuranTextService.parseBody(
        buildBody([
          {'numberInSurah': 1, 'text': 'أولى'},
          {'numberInSurah': 2, 'text': 'تانية'},
        ]),
        2,
      );

      expect(ayahs.length, 2);
      expect(ayahs[1].number, 2);
      expect(ayahs[1].text, 'تانية');
    });

    test('strips the basmala from ayah 1 of a surah that has one', () {
      final ayahs = QuranTextService.parseBody(
        buildBody([
          {'numberInSurah': 1, 'text': '$basmala الٓمٓ'},
        ]),
        2,
      );

      expect(ayahs.single.text, 'الٓمٓ');
    });

    test('keeps ayah 1 of Al-Fatiha intact', () {
      final ayahs = QuranTextService.parseBody(
        buildBody([
          {'numberInSurah': 1, 'text': basmala},
        ]),
        1,
      );

      expect(ayahs.single.text, basmala);
    });

    test('skips a malformed ayah instead of failing the whole surah', () {
      final ayahs = QuranTextService.parseBody(
        buildBody([
          {'numberInSurah': 1, 'text': 'أولى'},
          {'text': 'من غير رقم'},
          {'numberInSurah': 3, 'text': 'تالتة'},
        ]),
        2,
      );

      expect(ayahs.map((a) => a.number), [1, 3]);
    });

    test('throws on malformed JSON', () {
      expect(
        () => QuranTextService.parseBody('not json', 2),
        throwsA(isA<QuranApiException>()),
      );
    });

    test('throws when the payload has no ayah list', () {
      expect(
        () => QuranTextService.parseBody(jsonEncode({'data': {}}), 2),
        throwsA(isA<QuranApiException>()),
      );
    });

    test('throws when every ayah is unusable', () {
      expect(
        () => QuranTextService.parseBody(
          buildBody([
            {'text': 'من غير رقم'},
          ]),
          2,
        ),
        throwsA(isA<QuranApiException>()),
      );
    });
  });
}
