/// تحويل بين الميلادي والهجري بالتقويم الهجري الجدولي (المدني).
///
/// الملف ده رياضيات صافية — مفيش أي import من Flutter، عشان يتاخد له
/// unit test من غير ما نشغّل widget harness.
library;

/// رقم اليوم اليولياني لأول محرم سنة 1 هـ (16 يوليو 622 ميلادي يولياني).
const int _hijriEpochJdn = 1948440;

/// مواقع السنين الكبيسة جوّه دورة الـ30 سنة. السنة الكبيسة 355 يوم
/// والعادية 354.
const Set<int> _leapPositions = {2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29};

/// تاريخ هجري بقيمة ثابتة — مقارنة بالقيمة مش بالمرجع.
class HijriDate {
  final int year;
  final int month; // 1..12
  final int day; // 1..30

  const HijriDate(this.year, this.month, this.day);

  /// من رقم اليوم اليولياني — خوارزمية الكويت للتقويم الجدولي.
  factory HijriDate.fromJdn(int jdn) {
    int l = jdn - _hijriEpochJdn + 10632;
    final int n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final int j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final int month = (24 * l) ~/ 709;
    final int day = l - (709 * month) ~/ 24;
    final int year = 30 * n + j - 30;
    return HijriDate(year, month, day);
  }

  /// بيستعمل اليوم والشهر والسنة بس، والوقت بيتجاهل.
  ///
  /// [offset] بيزحزح التاريخ الهجري بأيام كاملة: +1 يعني الهجري يبقى
  /// متقدّم يوم عن الحساب الجدولي. الزحزحة بتتم على رقم اليوم اليولياني
  /// مش على DateTime، فالتوقيت الصيفي مالوش أي تأثير هنا.
  factory HijriDate.fromGregorian(DateTime date, {int offset = 0}) =>
      HijriDate.fromJdn(
        _gregorianToJdn(date.year, date.month, date.day) + offset,
      );

  int toJdn() =>
      ((11 * year + 3) ~/ 30) +
      354 * year +
      30 * month -
      ((month - 1) ~/ 2) +
      day +
      _hijriEpochJdn -
      385;

  /// عكس [HijriDate.fromGregorian] عند offset صفر. بيرجّع UTC عشان
  /// المقارنة تبقى من غير لبس توقيت.
  DateTime toGregorian() => _jdnToGregorian(toJdn());

  static bool isLeapYear(int hijriYear) =>
      _leapPositions.contains(hijriYear % 30);

  static int daysInMonth(int hijriYear, int month) {
    if (month == 12) return isLeapYear(hijriYear) ? 30 : 29;
    return month.isOdd ? 30 : 29;
  }

  String get monthNameAr => hijriMonthNamesAr[month - 1];

  /// "23 صفر 1448 هـ" — أرقام غربية زي باقي التطبيق.
  String formatAr() => '$day $monthNameAr $year هـ';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HijriDate &&
          other.year == year &&
          other.month == month &&
          other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'HijriDate($year-$month-$day)';
}

/// ميلادي إلى رقم يوم يولياني — Fliegel–Van Flandern.
///
/// الصيغة دي مبنية على قسمة بتقطع ناحية الصفر، وده اللي `~/` بيعمله في
/// Dart بالظبط. لو اتكتبت بـ floor بدل قطع، النتيجة هتغلط بيومين.
int _gregorianToJdn(int year, int month, int day) {
  final int a = (month - 14) ~/ 12;
  return (1461 * (year + 4800 + a)) ~/ 4 +
      (367 * (month - 2 - 12 * a)) ~/ 12 -
      (3 * ((year + 4900 + a) ~/ 100)) ~/ 4 +
      day -
      32075;
}

/// عكس [_gregorianToJdn].
DateTime _jdnToGregorian(int jdn) {
  int l = jdn + 68569;
  final int n = (4 * l) ~/ 146097;
  l = l - (146097 * n + 3) ~/ 4;
  final int i = (4000 * (l + 1)) ~/ 1461001;
  l = l - (1461 * i) ~/ 4 + 31;
  final int j = (80 * l) ~/ 2447;
  final int day = l - (2447 * j) ~/ 80;
  final int k = j ~/ 11;
  final int month = j + 2 - 12 * k;
  final int year = 100 * (n - 49) + i + k;
  return DateTime.utc(year, month, day);
}

const List<String> hijriMonthNamesAr = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

const List<String> gregorianMonthNamesAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// `DateTime.weekday` في Dart بيبدأ من الاثنين = 1، فالليستة مترتبة كده.
const List<String> weekdayNamesAr = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// "السبت 8 أغسطس 2026".
String formatGregorianAr(DateTime date) =>
    '${weekdayNamesAr[date.weekday - 1]} ${date.day} '
    '${gregorianMonthNamesAr[date.month - 1]} ${date.year}';

/// عدّ الأيام بمطابقة العدد العربية: يوم واحد / يومين / 3 أيام / 11 يوم.
String formatDaysAr(int days) {
  if (days == 1) return 'يوم واحد';
  if (days == 2) return 'يومين';
  if (days >= 3 && days <= 10) return '$days أيام';
  return '$days يوم';
}
