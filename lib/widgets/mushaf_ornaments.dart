import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/arabic_text.dart';

/// وردة نهاية الآية — الدايرة المزخرفة اللي فيها رقم الآية في المصحف
/// المطبوع.
///
/// الرقم بيترسم بـ TextPainter جوه الـ painter مش بـ Text widget، لأن
/// السورة الواحدة فيها لحد 286 علامة، وكل widget زيادة في النص الكبير
/// ده بيتحسب في وقت التخطيط.
class AyahMarker extends StatelessWidget {
  final int number;

  /// قطر العلامة — بيتحسب من حجم خط النص عشان تكبر وتصغر معاه
  final double size;

  final Color color;

  /// لون خلفية بيتحط لما الآية تكون متحددة
  final Color? background;

  const AyahMarker({
    super.key,
    required this.number,
    required this.size,
    required this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RosettePainter(
          label: toArabicIndic(number),
          color: color,
          background: background,
          // 0.36 هو أكبر مقاس بيخلي ٢٨٦ (ثلاث خانات) تفضل جوه الدايرة
          numberStyle: QuranTextStyle.amiri(
            fontSize: size * 0.36,
            color: color,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _RosettePainter extends CustomPainter {
  final String label;
  final Color color;
  final Color? background;
  final TextStyle numberStyle;

  /// عدد الشرائط حوالين الحلقة
  static const int _tickCount = 8;

  _RosettePainter({
    required this.label,
    required this.color,
    required this.background,
    required this.numberStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    if (background != null) {
      canvas.drawCircle(center, radius, Paint()..color = background!);
    }

    canvas.drawCircle(
      center,
      radius * 0.84,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, radius * 0.06)
        ..color = color,
    );

    // شرائط قصيرة حوالين الحلقة — الإيحاء بالوردة من غير زخرفة تقيلة
    // تشوّش على النص لما تتكرر مئات المرات في الصفحة
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, radius * 0.07)
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55);

    for (var i = 0; i < _tickCount; i++) {
      final angle = i * 2 * math.pi / _tickCount;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (radius * 0.90),
        center + direction * radius,
        tick,
      );
    }

    final painter = TextPainter(
      text: TextSpan(text: label, style: numberStyle),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width);

    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_RosettePainter old) =>
      old.label != label ||
      old.color != color ||
      old.background != background ||
      old.numberStyle != numberStyle;
}

/// لوحة عنوان السورة — الإطار المزدوج اللي بيتصدّر كل سورة في المصحف.
class SurahBanner extends StatelessWidget {
  final String name;

  /// مكية / مدنية — ممكن تكون null لو دخلنا من علامة قراءة محفوظة
  final String? typeLabel;

  final int ayahCount;
  final Color color;
  final Color textColor;

  const SurahBanner({
    super.key,
    required this.name,
    required this.typeLabel,
    required this.ayahCount,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (typeLabel != null) typeLabel!,
      'آياتها ${toArabicIndic(ayahCount)}',
    ].join('  ·  ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.4),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(3),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.md,
        ),
        child: Column(
          children: [
            Text(
              'سُورَةُ $name',
              textAlign: TextAlign.center,
              style: QuranTextStyle.amiri(color: textColor, fontSize: 24),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.3,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
