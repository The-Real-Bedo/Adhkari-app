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
