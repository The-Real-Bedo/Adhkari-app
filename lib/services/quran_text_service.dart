import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/ayah.dart';
import 'quran_api_service.dart';

/// نص المصحف — بيتجاب من alquran.cloud مرة واحدة لكل سورة وبعدين
/// بيتقرا من الجهاز.
///
/// ليه ملفات مش SharedPreferences: المصحف كامل حوالي 1.5 ميجا، و
/// SharedPreferences على أندرويد ملف XML واحد بيتحمّل في الذاكرة كله،
/// فحشوه بالنص ده هيبطّأ كل قراءة تفضيل في التطبيق. نفس مجلد التحميلات
/// اللي الصوت بيستعمله — بيتمسح مع التطبيق ومش محتاج صلاحية تخزين.
class QuranTextService {
  static const String _base = 'https://api.alquran.cloud/v1/surah';

  /// الرسم العثماني — أقرب حاجة لشكل المصحف المطبوع
  static const String _edition = 'quran-uthmani';

  static const Duration _timeout = Duration(seconds: 20);

  /// كاش في الذاكرة عشان التنقل بين السور ما يقراش من القرص كل مرة
  static final Map<int, List<Ayah>> _memo = {};

  /// آيات سورة واحدة. الترتيب: الذاكرة، فالقرص، فالشبكة.
  static Future<List<Ayah>> surah(int surahId) async {
    final memo = _memo[surahId];
    if (memo != null) return memo;

    final cached = await _readCache(surahId);
    if (cached != null && cached.isNotEmpty) {
      _memo[surahId] = cached;
      return cached;
    }

    final String body;
    try {
      final response = await http
          .get(Uri.parse('$_base/$surahId/$_edition'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw QuranApiException('الخادم رد بالكود ${response.statusCode}');
      }
      // بنفك الترميز UTF-8 صراحة زي باقي خدمات القرآن
      body = utf8.decode(response.bodyBytes);
    } on QuranApiException {
      rethrow;
    } on TimeoutException {
      throw QuranApiException('انتهت مهلة الاتصال، حاول تاني');
    } catch (_) {
      throw QuranApiException('تعذر الاتصال بالإنترنت، تأكد من الشبكة');
    }

    final ayahs = parseBody(body, surahId);
    await _writeCache(surahId, ayahs);
    _memo[surahId] = ayahs;
    return ayahs;
  }

  /// تحليل رد الخادم. دالة صافية عشان تتختبر من غير شبكة.
  static List<Ayah> parseBody(String body, int surahId) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw QuranApiException('رد غير مفهوم من الخادم');
    }

    if (decoded is! Map<String, dynamic>) {
      throw QuranApiException('رد غير مفهوم من الخادم');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw QuranApiException('رد غير مفهوم من الخادم');
    }

    final raw = data['ayahs'];
    if (raw is! List) throw QuranApiException('السورة رجعت فاضية');

    final ayahs = <Ayah>[];
    for (final item in raw.whereType<Map<String, dynamic>>()) {
      final ayah = Ayah.tryParse(item);
      if (ayah == null) continue;

      // بعض الإصدارات بتلزق البسملة في أول آية بدل ما تفصلها. بنشيلها
      // من هنا عشان الشاشة تعرضها مرة واحدة كعنوان فوق السورة.
      if (ayah.number == 1 && surahHasBasmala(surahId)) {
        ayahs.add(Ayah(number: 1, text: stripLeadingBasmala(ayah.text)));
      } else {
        ayahs.add(ayah);
      }
    }

    if (ayahs.isEmpty) throw QuranApiException('السورة رجعت فاضية');
    return ayahs;
  }

  /// أرقام السور المحفوظة على الجهاز — الشاشة بتعلّم عليها إنها متاحة
  /// بدون إنترنت.
  static Future<Set<int>> cachedSurahIds() async {
    final dir = await _textDir();
    final ids = <int>{};
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final match = RegExp(r'surah_(\d{3})\.json$').firstMatch(entity.path);
      final id = int.tryParse(match?.group(1) ?? '');
      if (id != null) ids.add(id);
    }
    return ids;
  }

  static Future<void> clearCache() async {
    _memo.clear();
    final dir = await _textDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ————— أدوات داخلية —————

  static Future<Directory> _textDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/quran_text');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _fileFor(int surahId) async {
    final dir = await _textDir();
    return File('${dir.path}/surah_${surahId.toString().padLeft(3, '0')}.json');
  }

  /// بيرجع null لو مفيش كاش أو الملف بايظ — الاتنين معناهم "هات من الشبكة".
  static Future<List<Ayah>?> _readCache(int surahId) async {
    try {
      final file = await _fileFor(surahId);
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return null;

      final ayahs = decoded
          .whereType<Map<String, dynamic>>()
          .map(Ayah.fromCache)
          .whereType<Ayah>()
          .toList();
      return ayahs.isEmpty ? null : ayahs;
    } catch (_) {
      return null;
    }
  }

  /// فشل الكتابة مش سبب نوقف القراءة — المستخدم عنده النص في الذاكرة.
  static Future<void> _writeCache(int surahId, List<Ayah> ayahs) async {
    try {
      final file = await _fileFor(surahId);
      await file.writeAsString(
        jsonEncode(ayahs.map((a) => a.toCache()).toList()),
      );
    } catch (_) {}
  }
}
