import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// علامة القراءة — آخر آية المستخدم وقف عندها.
class MushafBookmark {
  final int surahId;
  final String surahName;
  final int ayah;

  const MushafBookmark({
    required this.surahId,
    required this.surahName,
    required this.ayah,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MushafBookmark &&
          other.surahId == surahId &&
          other.surahName == surahName &&
          other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surahId, surahName, ayah);
}

/// تفضيلات المصحف: حجم الخط وعلامة القراءة.
///
/// القيمتين منشورين في ValueNotifier عشان شاشة الفهرس وشاشة القراءة
/// يفضلوا متوافقين من غير ما نمرّر callbacks بينهم.
class MushafPrefs {
  static const String _kFontSize = 'mushaf_font_size';
  static const String _kLineHeight = 'mushaf_line_height';
  static const String _kBookmarkSurah = 'mushaf_bookmark_surah';
  static const String _kBookmarkName = 'mushaf_bookmark_surah_name';
  static const String _kBookmarkAyah = 'mushaf_bookmark_ayah';

  static const double minFontSize = 18;
  static const double maxFontSize = 44;
  static const double defaultFontSize = 26;

  /// تباعد السطور مضروب في حجم الخط. النص القرآني مشكّل، والتشكيل بياخد
  /// مساحة فوق وتحت الحرف، فالسطور المتلزقة بتبقى غير مقروءة.
  static const double minLineHeight = 1.7;
  static const double maxLineHeight = 3.0;
  static const double defaultLineHeight = 2.2;

  static final ValueNotifier<double> fontSizeNotifier = ValueNotifier<double>(
    defaultFontSize,
  );

  static final ValueNotifier<double> lineHeightNotifier = ValueNotifier<double>(
    defaultLineHeight,
  );

  static final ValueNotifier<MushafBookmark?> bookmarkNotifier =
      ValueNotifier<MushafBookmark?>(null);

  static double _clamp(double value) =>
      value.clamp(minFontSize, maxFontSize).toDouble();

  static double _clampHeight(double value) =>
      value.clamp(minLineHeight, maxLineHeight).toDouble();

  /// بتتنده مرة واحدة عند بداية التطبيق.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    fontSizeNotifier.value = _clamp(
      prefs.getDouble(_kFontSize) ?? defaultFontSize,
    );

    lineHeightNotifier.value = _clampHeight(
      prefs.getDouble(_kLineHeight) ?? defaultLineHeight,
    );

    final surahId = prefs.getInt(_kBookmarkSurah);
    final ayah = prefs.getInt(_kBookmarkAyah);
    if (surahId != null && ayah != null) {
      bookmarkNotifier.value = MushafBookmark(
        surahId: surahId,
        surahName: prefs.getString(_kBookmarkName) ?? 'سورة $surahId',
        ayah: ayah,
      );
    }
  }

  static Future<void> setFontSize(double value) async {
    final clamped = _clamp(value);
    fontSizeNotifier.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, clamped);
  }

  static Future<void> setLineHeight(double value) async {
    final clamped = _clampHeight(value);
    lineHeightNotifier.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLineHeight, clamped);
  }

  static Future<void> setBookmark(MushafBookmark bookmark) async {
    bookmarkNotifier.value = bookmark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBookmarkSurah, bookmark.surahId);
    await prefs.setString(_kBookmarkName, bookmark.surahName);
    await prefs.setInt(_kBookmarkAyah, bookmark.ayah);
  }

  static Future<void> clearBookmark() async {
    bookmarkNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBookmarkSurah);
    await prefs.remove(_kBookmarkName);
    await prefs.remove(_kBookmarkAyah);
  }
}
