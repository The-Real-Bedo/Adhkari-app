import '../utils/arabic_text.dart';

/// آية واحدة من المصحف.
class Ayah {
  /// رقم الآية جوّه السورة، بيبدأ من 1
  final int number;

  final String text;

  const Ayah({required this.number, required this.text});

  /// بيرجع null لو العنصر ناقص أو شكله غلط، عشان آية واحدة بايظة في الرد
  /// ما تبوّظش السورة كلها.
  static Ayah? tryParse(Map<String, dynamic> json) {
    final rawNumber = json['numberInSurah'];
    final number = rawNumber is int
        ? rawNumber
        : int.tryParse(rawNumber?.toString() ?? '');
    if (number == null || number < 1) return null;

    final text = (json['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;

    return Ayah(number: number, text: text);
  }

  /// بنخزن مفاتيح قصيرة في الكاش — 6236 آية، وكل حرف بيفرق في حجم الملف.
  Map<String, dynamic> toCache() => {'n': number, 't': text};

  static Ayah? fromCache(Map<String, dynamic> json) {
    final number = json['n'];
    final text = json['t'];
    if (number is! int || text is! String || text.isEmpty) return null;
    return Ayah(number: number, text: text);
  }

  /// علامة الآية زي ما بتتكتب في المصحف: ﴿١٢﴾
  String get marker => '﴿${toArabicIndic(number)}﴾';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ayah && other.number == number && other.text == text;

  @override
  int get hashCode => Object.hash(number, text);

  @override
  String toString() => 'Ayah($number)';
}

/// البسملة بالرسم العثماني.
const String basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

/// كل السور بتبدأ بالبسملة ما عدا اتنين: الفاتحة لأن البسملة نفسها آية
/// رقم 1 فيها، والتوبة لأن مالهاش بسملة أصلًا.
bool surahHasBasmala(int surahId) => surahId != 1 && surahId != 9;

/// بتشيل البسملة من أول آية لو الخادم رجّعها ملزوقة فيها.
///
/// إصدارات النص بتختلف: بعضها بيفصل البسملة وبعضها بيحطها في أول آية.
/// بنقارن أول أربع كلمات بعد توحيد الشكل، فالفرق في التشكيل أو في رسم
/// الألف مابيأثرش. لو الآية كلها أربع كلمات (وده حال الفاتحة) بنسيبها
/// زي ما هي عشان مانرجّعش نص فاضي.
String stripLeadingBasmala(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;

  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length <= 4) return trimmed;

  final head = normalizeArabic(words.take(4).join(' '));
  if (head != normalizeArabic(basmala)) return trimmed;

  return words.skip(4).join(' ').trim();
}
