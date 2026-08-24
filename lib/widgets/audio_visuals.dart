import 'dart:math' as math;

import 'package:flutter/material.dart';

/// عدد الحلقات اللي بتطلع ورا بعض من الدايرة
const int _ringCount = 3;

/// هالة نابضة حوالين أيقونة المشغل أثناء التلاوة.
///
/// الحلقات بتترسم في CustomPainter مربوط بالـ controller مباشرة، يعني
/// بترسم كل frame من غير ما تعيد بناء أي widget. والحركة بتقف خالص لما
/// التشغيل يقف — مافيش ticker شغال في الخلفية على الفاضي.
class AudioPulse extends StatefulWidget {
  final bool playing;

  /// قطر الدايرة اللي جوه — الحلقات بتبدأ من حافتها
  final double size;

  final Color color;
  final Widget child;

  const AudioPulse({
    super.key,
    required this.playing,
    required this.size,
    required this.color,
    required this.child,
  });

  @override
  State<AudioPulse> createState() => _AudioPulseState();
}

class _AudioPulseState extends State<AudioPulse> with TickerProviderStateMixin {
  late final AnimationController _waves = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// شدة الحركة. بتنزل لصفر بالتدريج عند الإيقاف عشان الحلقات تتلاشى
  /// بدل ما تتجمد في نص الطريق.
  late final AnimationController _intensity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _startAnimating();
  }

  @override
  void didUpdateWidget(AudioPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) return;
    widget.playing ? _startAnimating() : _stopAnimating();
  }

  @override
  void dispose() {
    _waves.dispose();
    _intensity.dispose();
    super.dispose();
  }

  void _startAnimating() {
    if (!_waves.isAnimating) _waves.repeat();
    _intensity.forward();
  }

  void _stopAnimating() {
    _intensity.reverse().whenCompleteOrCancel(() {
      // ممكن يكون رجّع التشغيل في نص التلاشي، ساعتها مانوقفش حاجة
      if (!mounted || widget.playing) return;
      _waves.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    // الحلقات محتاجة مساحة أكبر من الدايرة عشان تكبر فيها، بس المساحة دي
    // بترسم بره حدود التخطيط بـ OverflowBox — يعني الودجت بياخد مقاس
    // الدايرة بالظبط وبيفضل بديل مباشر لأي Container قبل كده، من غير ما
    // يزق اللي تحته أو يعمل overflow على الشاشات الصغيرة.
    final canvasSize = widget.size * 1.55;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          OverflowBox(
            maxWidth: canvasSize,
            maxHeight: canvasSize,
            child: CustomPaint(
              size: Size.square(canvasSize),
              painter: _PulsePainter(
                waves: _waves,
                intensity: _intensity,
                color: widget.color,
                coreSize: widget.size,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_waves, _intensity]),
            child: widget.child,
            builder: (context, child) {
              // نَفَس خفيف — 2% كفاية تدي إحساس بالحياة من غير ما تشتت
              final breath =
                  1 +
                  0.02 *
                      _intensity.value *
                      math.sin(2 * math.pi * _waves.value);
              return Transform.scale(scale: breath, child: child);
            },
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final Animation<double> waves;
  final Animation<double> intensity;
  final Color color;
  final double coreSize;

  _PulsePainter({
    required this.waves,
    required this.intensity,
    required this.color,
    required this.coreSize,
  }) : super(repaint: Listenable.merge([waves, intensity]));

  @override
  void paint(Canvas canvas, Size size) {
    final strength = intensity.value;
    if (strength <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final start = coreSize / 2;
    final end = size.shortestSide / 2;

    for (var i = 0; i < _ringCount; i++) {
      // كل حلقة متأخرة عن اللي قبلها بجزء من الدورة، فبيطلعوا ورا بعض
      final t = (waves.value + i / _ringCount) % 1.0;

      // بتخف وهي بتكبر — تتلاشى قبل ما توصل للحافة
      final opacity = (1 - t) * 0.45 * strength;
      if (opacity <= 0.01) continue;

      canvas.drawCircle(
        center,
        start + (end - start) * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.color != color || old.coreSize != coreSize;
}

/// أعمدة معادل صوت صغيرة — للشريط المصغر، مكان ما الهالة تبقى كبيرة.
class EqualizerBars extends StatefulWidget {
  final bool playing;
  final Color color;
  final double size;

  const EqualizerBars({
    super.key,
    required this.playing,
    required this.color,
    this.size = 16,
  });

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) return;
    if (widget.playing) {
      _controller.repeat();
    } else {
      // بنرجّع لأول الدورة عشان الأعمدة تقف على ارتفاع واحد مرتب
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _EqualizerPainter(
          animation: _controller,
          color: widget.color,
          animating: widget.playing,
        ),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final bool animating;

  /// إزاحة كل عمود في الموجة — أرقام غير منتظمة عشان الحركة ما تبانش آلية
  static const List<double> _phases = [0.0, 0.35, 0.62, 0.85];

  _EqualizerPainter({
    required this.animation,
    required this.color,
    required this.animating,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    const gapRatio = 0.4;
    final barWidth = size.width / (_phases.length + gapRatio * (_phases.length - 1));
    final gap = barWidth * gapRatio;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < _phases.length; i++) {
      final wave = math.sin(2 * math.pi * (animation.value + _phases[i]));
      // 0.35 أقل ارتفاع و 1.0 أعلى ارتفاع. وقت الوقوف كلهم في النص.
      final factor = animating ? 0.35 + 0.65 * (0.5 + 0.5 * wave) : 0.5;
      final height = size.height * factor;
      final left = i * (barWidth + gap);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) =>
      old.color != color || old.animating != animating;
}

/// شريط تقدم بشكل موجة صوتية بأعمدة — أسلوب ساوندكلاود.
///
/// الأعمدة ارتفاعها ثابت (مش عشوائي كل frame) عشان تبان زي موجة تسجيل
/// حقيقي. اللي اتسمع بياخد لون التطبيق واللي فاضل بيفضل باهت. وقت التشغيل
/// بتمشي نبضة خفيفة جوّه الجزء المسموع — زي الجزيرة الديناميكية — وبتفرد
/// نفسها بالتدريج عند الإيقاف بدل ما تتجمد.
class WaveProgressBar extends StatefulWidget {
  /// نسبة اللي اتسمع، من 0.0 لـ 1.0
  final double progress;

  /// النبضة بتتحرك بس وهي true
  final bool playing;

  final Color color;
  final Color backgroundColor;

  final double height;

  const WaveProgressBar({
    super.key,
    required this.progress,
    required this.playing,
    required this.color,
    required this.backgroundColor,
    this.height = 30,
  });

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  /// شدة النبضة — صفر يعني الأعمدة واقفة على ارتفاعها الأصلي
  late final AnimationController _amplitude = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _start();
  }

  @override
  void didUpdateWidget(WaveProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) return;
    widget.playing ? _start() : _stop();
  }

  @override
  void dispose() {
    _wave.dispose();
    _amplitude.dispose();
    super.dispose();
  }

  void _start() {
    if (!_wave.isAnimating) _wave.repeat();
    _amplitude.forward();
  }

  void _stop() {
    _amplitude.reverse().whenCompleteOrCancel(() {
      // ممكن التشغيل يرجع في نص الفرد، ساعتها مانوقفش حاجة
      if (!mounted || widget.playing) return;
      _wave.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveBarsPainter(
          wave: _wave,
          amplitude: _amplitude,
          progress: widget.progress.clamp(0.0, 1.0),
          color: widget.color,
          backgroundColor: widget.backgroundColor,
        ),
      ),
    );
  }
}

class _WaveBarsPainter extends CustomPainter {
  final Animation<double> wave;
  final Animation<double> amplitude;
  final double progress;
  final Color color;
  final Color backgroundColor;

  /// عرض العمود والمسافة بينه واللي بعده، بالبكسل المنطقي
  static const double _barWidth = 3;
  static const double _gap = 2;

  _WaveBarsPainter({
    required this.wave,
    required this.amplitude,
    required this.progress,
    required this.color,
    required this.backgroundColor,
  }) : super(repaint: Listenable.merge([wave, amplitude]));

  /// ارتفاع العمود رقم [i] كنسبة من الارتفاع الكامل.
  ///
  /// تركيب تلات موجات بترددات مش من مضاعفات بعضها، فالشكل بيطلع غير
  /// منتظم زي موجة صوت حقيقية، وبرضه ثابت — نفس الفهرس بيدي نفس الارتفاع
  /// كل مرة، فالموجة مش بترقص عبثًا.
  static double _barFactor(int i, int total) {
    final double x = i / total;
    final double a = math.sin(x * math.pi * 7.0);
    final double b = math.sin(x * math.pi * 13.0 + 1.7);
    final double c = math.sin(x * math.pi * 23.0 + 0.4);
    final double v = 0.30 + 0.34 * a.abs() + 0.22 * b.abs() + 0.14 * c.abs();
    return v.clamp(0.16, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double step = _barWidth + _gap;
    final int total = (size.width / step).floor();
    if (total <= 0) return;

    final double midY = size.height / 2;
    final double playedX = size.width * progress;
    final double pulse = amplitude.value;

    final Paint playedPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.75),
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, playedX > 0 ? playedX : 1, size.height));

    final Paint pending = Paint()..color = backgroundColor;

    for (int i = 0; i < total; i++) {
      final double x = i * step;
      final bool isPlayed = x + _barWidth <= playedX;

      double factor = _barFactor(i, total);

      // النبضة بتمشي جوّه الجزء المسموع مع حركة ناعمة حية
      if (isPlayed && pulse > 0) {
        final double travel = math.sin(
          2 * math.pi * (wave.value - (i / total) * 2.2),
        );
        factor *= 1 + 0.35 * pulse * travel;
      }

      final double barHeight = (size.height * factor).clamp(2.0, size.height);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, midY - barHeight / 2, _barWidth, barHeight),
          const Radius.circular(_barWidth / 2),
        ),
        isPlayed ? playedPaint : pending,
      );
    }

    // رسم نقطة / هالة مضيئة عند رأس المؤشر الحالي أثناء التشغيل
    if (playedX > 4 && playedX < size.width) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35 * (pulse > 0 ? pulse : 0.6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(playedX, midY), 5.0, glowPaint);

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(playedX, midY), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_WaveBarsPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.backgroundColor != backgroundColor;
}
