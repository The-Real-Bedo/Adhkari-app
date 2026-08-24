import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/ayah.dart';
import '../utils/arabic_text.dart';
import 'quran_api_service.dart';

/// آية ضمن صفحة من صفحات المصحف
class PageAyah {
  final int surahId;
  final String surahName;
  final int numberInSurah;
  final String text;
  final int juz;
  final int hizbQuarter;
  final bool isFirstInSurah;

  const PageAyah({
    required this.surahId,
    required this.surahName,
    required this.numberInSurah,
    required this.text,
    required this.juz,
    required this.hizbQuarter,
    this.isFirstInSurah = false,
  });

  String get marker => '﴿${toArabicIndic(numberInSurah)}﴾';

  Map<String, dynamic> toJson() => {
        'sId': surahId,
        'sName': surahName,
        'n': numberInSurah,
        't': text,
        'j': juz,
        'h': hizbQuarter,
        'f': isFirstInSurah,
      };

  factory PageAyah.fromJson(Map<String, dynamic> json) {
    return PageAyah(
      surahId: json['sId'] as int? ?? 1,
      surahName: json['sName'] as String? ?? '',
      numberInSurah: json['n'] as int? ?? 1,
      text: json['t'] as String? ?? '',
      juz: json['j'] as int? ?? 1,
      hizbQuarter: json['h'] as int? ?? 1,
      isFirstInSurah: json['f'] as bool? ?? false,
    );
  }
}

/// بيانات صفحة واحدة من صفحات المصحف الـ 604
class MushafPage {
  final int pageNumber; // 1 .. 604
  final int juz;
  final String surahHeader;
  final List<PageAyah> ayahs;

  const MushafPage({
    required this.pageNumber,
    required this.juz,
    required this.surahHeader,
    required this.ayahs,
  });

  Map<String, dynamic> toJson() => {
        'page': pageNumber,
        'juz': juz,
        'surah': surahHeader,
        'ayahs': ayahs.map((a) => a.toJson()).toList(),
      };

  factory MushafPage.fromJson(Map<String, dynamic> json) {
    final rawAyahs = json['ayahs'] as List<dynamic>? ?? [];
    return MushafPage(
      pageNumber: json['page'] as int? ?? 1,
      juz: json['juz'] as int? ?? 1,
      surahHeader: json['surah'] as String? ?? '',
      ayahs: rawAyahs
          .whereType<Map<String, dynamic>>()
          .map(PageAyah.fromJson)
          .toList(),
    );
  }
}

/// خدمة جلب وتخزين صفحات المصحف الشريف الـ 604
class QuranPageService {
  static const String _baseUrl = 'https://api.alquran.cloud/v1/page';
  static const String _edition = 'quran-uthmani';
  static const Duration _timeout = Duration(seconds: 15);

  /// كاش في الذاكرة للصفحات المحملة مؤخراً
  static final Map<int, MushafPage> _memo = {};

  /// مصفوفة أرقام صفحات بداية كل سورة في مصحف المدينة (1 .. 114)
  static const Map<int, int> surahStartPages = {
    1: 1, 2: 2, 3: 50, 4: 77, 5: 106, 6: 128, 7: 151, 8: 177, 9: 187, 10: 208,
    11: 221, 12: 235, 13: 249, 14: 255, 15: 262, 16: 267, 17: 282, 18: 293, 19: 305, 20: 312,
    21: 322, 22: 332, 23: 342, 24: 350, 25: 359, 26: 367, 27: 377, 28: 385, 29: 396, 30: 404,
    31: 411, 32: 415, 33: 418, 34: 428, 35: 434, 36: 440, 37: 446, 38: 453, 39: 458, 40: 467,
    41: 477, 42: 483, 43: 489, 44: 496, 45: 499, 46: 502, 47: 507, 48: 511, 49: 515, 50: 518,
    51: 520, 52: 523, 53: 526, 54: 528, 55: 531, 56: 534, 57: 537, 58: 542, 59: 545, 60: 549,
    61: 551, 62: 553, 63: 554, 64: 556, 65: 558, 66: 560, 67: 562, 68: 564, 69: 566, 70: 568,
    71: 570, 72: 572, 73: 574, 74: 575, 75: 577, 76: 578, 77: 580, 78: 582, 79: 583, 80: 585,
    81: 586, 82: 587, 83: 587, 84: 589, 85: 590, 86: 591, 87: 591, 88: 592, 89: 593, 90: 594,
    91: 595, 92: 595, 93: 596, 94: 596, 95: 597, 96: 597, 97: 598, 98: 598, 99: 599, 100: 599,
    101: 600, 102: 600, 103: 601, 104: 601, 105: 601, 106: 602, 107: 602, 108: 602, 109: 603, 110: 603,
    111: 603, 112: 604, 113: 604, 114: 604,
  };

  /// جلب صفحة محددة (من 1 إلى 604)
  static Future<MushafPage> getPage(int pageNumber, {bool isPrefetch = false}) async {
    final clamped = pageNumber.clamp(1, 604);
    final memo = _memo[clamped];
    if (memo != null) return memo;

    final cached = await _readCache(clamped);
    if (cached != null) {
      _memo[clamped] = cached;
      if (!isPrefetch) _prefetchAdjacent(clamped);
      return cached;
    }

    final String body;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$clamped/$_edition'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw QuranApiException('الخادم رد بالكود ${response.statusCode}');
      }
      body = utf8.decode(response.bodyBytes);
    } on TimeoutException {
      throw QuranApiException('انتهت مهلة الاتصال بالخادم، يرجى المحاولة ثانية');
    } catch (e) {
      if (e is QuranApiException) rethrow;
      throw QuranApiException('تعذر تحميل صفحة المصحف، تأكد من اتصال الإنترنت');
    }

    final page = _parsePageJson(body, clamped);
    await _writeCache(clamped, page);
    _memo[clamped] = page;
    if (!isPrefetch) _prefetchAdjacent(clamped);
    return page;
  }

  /// تحميل الصفحتين المجاورتين فقط — بدون تسلسل عشان مانحملش المصحف كله
  static void _prefetchAdjacent(int page) {
    if (page + 1 <= 604 && !_memo.containsKey(page + 1)) {
      getPage(page + 1, isPrefetch: true).catchError((_) => const MushafPage(pageNumber: 1, juz: 1, surahHeader: '', ayahs: []));
    }
    if (page - 1 >= 1 && !_memo.containsKey(page - 1)) {
      getPage(page - 1, isPrefetch: true).catchError((_) => const MushafPage(pageNumber: 1, juz: 1, surahHeader: '', ayahs: []));
    }
  }

  static MushafPage _parsePageJson(String body, int pageNumber) {
    final Map<String, dynamic> decoded = jsonDecode(body);
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) throw QuranApiException('تنسيق غير صالح لبيانات الصفحة');

    final rawAyahs = data['ayahs'] as List<dynamic>? ?? [];
    final ayahs = <PageAyah>[];
    String mainSurahName = '';
    int juzNumber = 1;

    for (final item in rawAyahs.whereType<Map<String, dynamic>>()) {
      final surahData = item['surah'] as Map<String, dynamic>? ?? {};
      final surahId = surahData['number'] as int? ?? 1;
      final rawSurahName = (surahData['name'] as String? ?? '').trim();
      final surahName = rawSurahName.replaceAll('سُورَةُ ', '').replaceAll('سورة ', '');
      if (mainSurahName.isEmpty) mainSurahName = surahName;

      final numberInSurah = item['numberInSurah'] as int? ?? 1;
      final juz = item['juz'] as int? ?? 1;
      final hizbQuarter = item['hizbQuarter'] as int? ?? 1;
      juzNumber = juz;

      String text = (item['text'] as String? ?? '').trim();
      final isFirst = numberInSurah == 1;

      // إزالة البسملة إذا كانت مدمجة في أول آية لسور غير الفاتحة والتوبة
      if (isFirst && surahHasBasmala(surahId)) {
        text = stripLeadingBasmala(text);
      }

      ayahs.add(
        PageAyah(
          surahId: surahId,
          surahName: surahName,
          numberInSurah: numberInSurah,
          text: text,
          juz: juz,
          hizbQuarter: hizbQuarter,
          isFirstInSurah: isFirst,
        ),
      );
    }

    return MushafPage(
      pageNumber: pageNumber,
      juz: juzNumber,
      surahHeader: mainSurahName,
      ayahs: ayahs,
    );
  }

  static Future<Directory> _pagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/mushaf_pages');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _fileFor(int page) async {
    final dir = await _pagesDir();
    return File('${dir.path}/page_${page.toString().padLeft(3, '0')}.json');
  }

  static Future<MushafPage?> _readCache(int page) async {
    try {
      final file = await _fileFor(page);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return MushafPage.fromJson(jsonDecode(content));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(int page, MushafPage pageData) async {
    try {
      final file = await _fileFor(page);
      await file.writeAsString(jsonEncode(pageData.toJson()));
    } catch (_) {}
  }
}
