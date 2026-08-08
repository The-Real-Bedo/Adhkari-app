import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran_models.dart';

/// خطأ بنرميه لما الشبكة تفشل ومفيش كاش نرجعله
class QuranApiException implements Exception {
  final String message;
  QuranApiException(this.message);
  @override
  String toString() => message;
}

/// خدمة جلب بيانات القرآن من mp3quran.net مع كاش محلي.
///
/// ملاحظات مهمة:
/// - الـ endpoints بتعمل redirect 301، و package:http بيتابع الـ redirect
///   تلقائيًا في طلبات get، فمحتاجينش إعداد إضافي.
/// - بنخزن نسخة مصغرة من البيانات مش الرد الكامل (الرد الأصلي ~190KB).
class QuranApiService {
  static const String _base = 'https://mp3quran.net/api/v3';

  static const String _kRecitersCache = 'quran_reciters_cache';
  static const String _kSuwarCache = 'quran_suwar_cache';
  static const String _kCacheStamp = 'quran_cache_timestamp';

  static const Duration _cacheTtl = Duration(days: 7);
  static const Duration _timeout = Duration(seconds: 15);

  // كاش في الذاكرة عشان منقراش من القرص كل مرة الشاشة تتبني
  static List<Reciter>? _recitersMemo;
  static List<Surah>? _suwarMemo;

  /// قائمة القراء. بيحاول الشبكة الأول، وبيقع على الكاش لو فشلت.
  static Future<List<Reciter>> fetchReciters() async {
    if (_recitersMemo != null) return _recitersMemo!;

    final prefs = await SharedPreferences.getInstance();

    // الكاش لسه صالح؟ استخدمه على طول من غير شبكة
    if (_isCacheFresh(prefs)) {
      final cached = _readRecitersCache(prefs);
      if (cached != null && cached.isNotEmpty) {
        _recitersMemo = cached;
        return cached;
      }
    }

    try {
      final body = await _get('$_base/reciters?language=ar');
      final raw = (jsonDecode(body)['reciters'] as List<dynamic>? ?? const []);

      final reciters = raw
          .whereType<Map<String, dynamic>>()
          .map(Reciter.fromJson)
          // قارئ من غير أي رواية صالحة مالوش لازمة في القائمة
          .where((r) => r.moshaf.isNotEmpty)
          .toList();

      if (reciters.isEmpty) throw QuranApiException('قائمة القراء فارغة');

      await prefs.setString(
        _kRecitersCache,
        jsonEncode(reciters.map((r) => r.toCache()).toList()),
      );
      await _stampCache(prefs);

      _recitersMemo = reciters;
      return reciters;
    } catch (e) {
      // الشبكة فشلت — نرجع كاش قديم لو موجود أحسن من شاشة فاضية
      final cached = _readRecitersCache(prefs);
      if (cached != null && cached.isNotEmpty) {
        _recitersMemo = cached;
        return cached;
      }
      throw QuranApiException(_friendlyError(e));
    }
  }

  /// قائمة السور الـ 114 بأسمائها العربية
  static Future<List<Surah>> fetchSuwar() async {
    if (_suwarMemo != null) return _suwarMemo!;

    final prefs = await SharedPreferences.getInstance();

    if (_isCacheFresh(prefs)) {
      final cached = _readSuwarCache(prefs);
      if (cached != null && cached.isNotEmpty) {
        _suwarMemo = cached;
        return cached;
      }
    }

    try {
      final body = await _get('$_base/suwar?language=ar');
      final raw = (jsonDecode(body)['suwar'] as List<dynamic>? ?? const []);

      final suwar = raw
          .whereType<Map<String, dynamic>>()
          .map(Surah.fromJson)
          .toList();

      if (suwar.isEmpty) throw QuranApiException('قائمة السور فارغة');

      await prefs.setString(
        _kSuwarCache,
        jsonEncode(suwar.map((s) => s.toCache()).toList()),
      );
      await _stampCache(prefs);

      _suwarMemo = suwar;
      return suwar;
    } catch (e) {
      final cached = _readSuwarCache(prefs);
      if (cached != null && cached.isNotEmpty) {
        _suwarMemo = cached;
        return cached;
      }
      throw QuranApiException(_friendlyError(e));
    }
  }

  /// بنستخدمها مع زرار "إعادة المحاولة" عشان نتخطى الكاش
  static void clearMemoryCache() {
    _recitersMemo = null;
    _suwarMemo = null;
  }

  // ————— أدوات داخلية —————

  static Future<String> _get(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw QuranApiException('الخادم رد بالكود ${response.statusCode}');
    }
    // بنفك الترميز كـ UTF-8 صراحة عشان الأسماء العربية متتكسرش
    return utf8.decode(response.bodyBytes);
  }

  static bool _isCacheFresh(SharedPreferences prefs) {
    final stamp = prefs.getInt(_kCacheStamp);
    if (stamp == null) return false;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(stamp),
    );
    return age < _cacheTtl;
  }

  static Future<void> _stampCache(SharedPreferences prefs) =>
      prefs.setInt(_kCacheStamp, DateTime.now().millisecondsSinceEpoch);

  static List<Reciter>? _readRecitersCache(SharedPreferences prefs) {
    final raw = prefs.getString(_kRecitersCache);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Reciter.fromJson)
          .toList();
    } catch (_) {
      return null; // كاش تالف — نتجاهله ونجيب من الشبكة
    }
  }

  static List<Surah>? _readSuwarCache(SharedPreferences prefs) {
    final raw = prefs.getString(_kSuwarCache);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Surah.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  static String _friendlyError(Object e) {
    if (e is TimeoutException) return 'انتهت مهلة الاتصال، حاول تاني';
    if (e is QuranApiException) return e.message;
    return 'تعذر الاتصال بالإنترنت، تأكد من الشبكة وحاول تاني';
  }
}
