class Zikr {
  final String text;
  final int max;
  int current;
  final String? source; // المصدر (اختياري)

  Zikr({
    required this.text,
    required this.max,
    required this.current,
    this.source, // المصدر اختياري
  });
}
