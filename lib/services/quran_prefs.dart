import 'package:shared_preferences/shared_preferences.dart';

/// تفضيلات قسم القرآن: المفضلة + آخر موضع تشغيل.
/// بنستخدم نفس أسلوب shared_preferences المستخدم في باقي التطبيق.
class QuranPrefs {
  static const String _kFavReciters = 'quran_fav_reciters';
  static const String _kFavSurahs = 'quran_fav_surahs';

  static const String _kLastReciter = 'quran_last_reciter';
  static const String _kLastReciterName = 'quran_last_reciter_name';
  static const String _kLastMoshaf = 'quran_last_moshaf';
  static const String _kLastSurah = 'quran_last_surah';
  static const String _kLastSurahTitle = 'quran_last_surah_title';
  static const String _kLastPosition = 'quran_last_position_ms';
  static const String _kLastDuration = 'quran_last_duration_ms';

  // ————— القراء المفضلين —————

  static Future<Set<int>> favouriteReciters() async {
    final prefs = await SharedPreferences.getInstance();
    return _toIntSet(prefs.getStringList(_kFavReciters));
  }

  /// بترجع true لو القارئ بقى مفضل بعد التبديل
  static Future<bool> toggleFavouriteReciter(int reciterId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _toIntSet(prefs.getStringList(_kFavReciters));

    final added = current.add(reciterId);
    if (!added) current.remove(reciterId);

    await prefs.setStringList(
      _kFavReciters,
      current.map((e) => e.toString()).toList(),
    );
    return added;
  }

  // ————— السور المفضلة —————

  static Future<Set<int>> favouriteSurahs() async {
    final prefs = await SharedPreferences.getInstance();
    return _toIntSet(prefs.getStringList(_kFavSurahs));
  }

  static Future<bool> toggleFavouriteSurah(int surahId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _toIntSet(prefs.getStringList(_kFavSurahs));

    final added = current.add(surahId);
    if (!added) current.remove(surahId);

    await prefs.setStringList(
      _kFavSurahs,
      current.map((e) => e.toString()).toList(),
    );
    return added;
  }

  // ————— آخر موضع تشغيل —————

  static Future<void> saveLastPlayed({
    required int reciterId,
    required String reciterName,
    required int moshafId,
    required int surahId,
    required String surahTitle,
    required Duration position,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastReciter, reciterId);
    await prefs.setString(_kLastReciterName, reciterName);
    await prefs.setInt(_kLastMoshaf, moshafId);
    await prefs.setInt(_kLastSurah, surahId);
    await prefs.setString(_kLastSurahTitle, surahTitle);
    await prefs.setInt(_kLastPosition, position.inMilliseconds);
    await prefs.setInt(_kLastDuration, duration.inMilliseconds);
  }

  /// بترجع null لو مفيش تشغيل سابق محفوظ
  static Future<LastPlayed?> lastPlayed() async {
    final prefs = await SharedPreferences.getInstance();

    final reciterId = prefs.getInt(_kLastReciter);
    final moshafId = prefs.getInt(_kLastMoshaf);
    final surahId = prefs.getInt(_kLastSurah);
    if (reciterId == null || moshafId == null || surahId == null) return null;

    return LastPlayed(
      reciterId: reciterId,
      reciterName: prefs.getString(_kLastReciterName) ?? '',
      moshafId: moshafId,
      surahId: surahId,
      surahTitle: prefs.getString(_kLastSurahTitle) ?? 'سورة $surahId',
      position: Duration(milliseconds: prefs.getInt(_kLastPosition) ?? 0),
      duration: Duration(milliseconds: prefs.getInt(_kLastDuration) ?? 0),
    );
  }

  /// بنمسح آخر موضع لما المستخدم يختار يبدأ من الأول
  static Future<void> clearLastPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastReciter);
    await prefs.remove(_kLastReciterName);
    await prefs.remove(_kLastMoshaf);
    await prefs.remove(_kLastSurah);
    await prefs.remove(_kLastSurahTitle);
    await prefs.remove(_kLastPosition);
    await prefs.remove(_kLastDuration);
  }

  static Set<int> _toIntSet(List<String>? raw) {
    if (raw == null) return <int>{};
    return raw
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }
}

class LastPlayed {
  final int reciterId;
  final String reciterName;
  final int moshafId;
  final int surahId;
  final String surahTitle;
  final Duration position;
  final Duration duration;

  LastPlayed({
    required this.reciterId,
    required this.reciterName,
    required this.moshafId,
    required this.surahId,
    required this.surahTitle,
    required this.position,
    required this.duration,
  });

  /// نسبة التقدم من 0.0 لـ 1.0 — بيستخدمها كارت "تابع الاستماع"
  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}
