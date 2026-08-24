/// أدوات معالجة النص العربي للبحث.
///
/// المشكلة: "الأعراف" و "الاعراف" مختلفين في الترميز، فلو المستخدم كتب
/// الهمزة بشكل مختلف عن اللي في البيانات مش هيلاقي نتيجة. الحل إننا
/// نوحّد الشكل قبل المقارنة على الجانبين.
library;

/// علامات التشكيل والمدّ اللي بنشيلها قبل المقارنة
final RegExp _tashkeel = RegExp(
  '['
  'ً-ٟ' // الفتحتين والضمتين والكسرتين والشدة والسكون
  'ٰ' // الألف الخنجرية
  'ۖ-ۭ' // علامات الوقف والتجويد
  ']',
);

/// التطويل (الكشيدة) — بيتحط للزخرفة ومالوش قيمة في البحث
const String _tatweel = 'ـ';

/// بتوحّد شكل النص العربي عشان البحث يشتغل مهما اختلفت طريقة الكتابة:
///
/// - أ إ آ ٱ ← ا   (كل أشكال الهمزة على الألف)
/// - ة ← ه          (التاء المربوطة)
/// - ى ← ي          (الألف المقصورة)
/// - ؤ ← و ، ئ ← ي  (الهمزة على الواو والياء)
/// - بنشيل التشكيل والتطويل
///
/// مثال: "الأَعْرَاف" و "الاعراف" الاتنين بيبقوا "الاعراف"
String normalizeArabic(String input) {
  if (input.isEmpty) return input;

  final buffer = StringBuffer();

  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);

    switch (char) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ٱ':
      case 'ٲ':
      case 'ٳ':
        buffer.write('ا');
      case 'ة':
        buffer.write('ه');
      case 'ى':
      case 'ی': // Persian Yeh
        buffer.write('ي');
      case 'ؤ':
        buffer.write('و');
      case 'ئ':
        buffer.write('ي');
      case _tatweel:
        break; // بنتجاهله خالص
      default:
        buffer.write(char);
    }
  }

  return buffer
      .toString()
      .replaceAll(_tashkeel, '')
      .trim()
      // المسافات المتكررة بتبوظ المطابقة
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// بحث متسامح: بيقارن النصين بعد التوحيد.
/// بنستخدمها بدل contains العادية في كل شاشات القرآن.
bool arabicContains(String haystack, String needle) {
  final n = normalizeArabic(needle);
  if (n.isEmpty) return true;
  return normalizeArabic(haystack).contains(n);
}

const List<String> _arabicIndicDigits = [
  '٠',
  '١',
  '٢',
  '٣',
  '٤',
  '٥',
  '٦',
  '٧',
  '٨',
  '٩',
];

/// أرقام هندية عربية — ١٢٣ بدل 123.
///
/// باقي التطبيق بيستخدم الأرقام الغربية، لكن علامة الآية في المصحف
/// بتتكتب بالهندية دايمًا، فالدالة دي مخصوصة للمصحف مش للواجهة كلها.
String toArabicIndic(int value) {
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (final char in value.abs().toString().split('')) {
    buffer.write(_arabicIndicDigits[int.parse(char)]);
  }
  return buffer.toString();
}
