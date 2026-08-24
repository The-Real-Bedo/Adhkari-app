import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'main_navigation.dart';

class CustomSplashScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const CustomSplashScreen({super.key, required this.toggleTheme});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final AnimationController _lightController;
  late final AnimationController _detailsController;

  late final Animation<double> _detailsFade;

  final String _arabicText = "أَذْكَارِي";

  /// الخط بيتبنى مرة واحدة عن قصد.
  ///
  /// اللي بيتغير كل frame هو اللون وقوة البلور بس، فالنمط الأساسي ده
  /// بيتحسب مرة وبنعمل عليه `copyWith` — قبل كده كان بيتبني مرتين جوّه كل
  /// frame (طبقة الظل وطبقة التدرّج)، يعني 240 مرة في الثانية على شاشة
  /// 120Hz. الخط نفسه مبني في التطبيق ومعلن في pubspec.yaml بوزن 700.
  static const TextStyle _baseCalligraphy = TextStyle(
    fontFamily: 'ScheherazadeNew',
    fontSize: 104,
    fontWeight: FontWeight.w700,
    height: 1.45,
  );

  Timer? _detailsTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _lightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    _detailsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _detailsFade = CurvedAnimation(
      parent: _detailsController,
      curve: Curves.easeOut,
    );

    _revealController.forward();
    _lightController.repeat(reverse: true);

    _detailsTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _detailsController.forward();
    });

    // 2.6 ثانية بدل 4.7. الكشف بيخلص عند 2.0 والتفاصيل بتظهر من 1.2،
    // فالمستخدم شاف كل حاجة قبل الانتقال — الوقت الزيادة كان استنى فاضي.
    _navigationTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || !context.mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MainNavigation(toggleTheme: widget.toggleTheme),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _detailsTimer?.cancel();
    _navigationTimer?.cancel();
    _revealController.dispose();
    _lightController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _SplashColors c = _SplashColors.of(context);

    // الشجرة مقسومة لتلات أجزاء بتتحرك كل واحد لوحده، بدل AnimatedBuilder
    // واحد كان بيلفّ الشاشة كلها. قبل كده كل frame كان بيعيد بناء الخلفية
    // والهالة والاسم والخط الفاصل ونص "ADHKARI" — وده اللي كان بيسقّط
    // إطارات في أول التشغيل.
    return Scaffold(
      backgroundColor: c.ground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ————— 1) الخلفية: بتهمّها النَفَس بس —————
          AnimatedBuilder(
            animation: _lightController,
            builder: (context, _) {
              final double breath = math.sin(_lightController.value * math.pi);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.15, -0.25),
                    radius: 1.15,
                    colors: [
                      Color.lerp(c.glowNear, c.glowFar, breath)!,
                      c.groundMid,
                      c.ground,
                    ],
                    stops: const [0.0, 0.46, 1.0],
                  ),
                ),
              );
            },
          ),

          // ————— 2) الهالة —————
          // الـ painter مربوط بالـ controller بنفسه (repaint:)، فمحتاجش
          // AnimatedBuilder يعيد بناء widget كل frame — بيرسم وبس.
          // و RepaintBoundary بتعزل الرسم ده عن باقي الشاشة.
          RepaintBoundary(
            child: CustomPaint(
              painter: _IslamicAuraPainter(
                progress: _lightController,
                color: c.halo,
                baseAlpha: c.auraAlpha,
                swing: c.auraSwing,
              ),
            ),
          ),

          // ————— 3) الاسم —————
          Center(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _revealController,
                  _lightController,
                ]),
                // الخط الفاصل ونص "ADHKARI" بيتمرروا كـ child، فبيتبنوا
                // مرة واحدة بس مهما اتعاد بناء الحركة.
                child: FadeTransition(
                  opacity: _detailsFade,
                  child: Column(
                    children: [
                      Container(
                        width: 148,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              c.halo.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "A D H K A R I",
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 13,
                          color: c.subtitle,
                          letterSpacing: 9,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                builder: (context, child) {
                  final double reveal = Curves.easeInOutCubic.transform(
                    _revealController.value,
                  );
                  final double breath = math.sin(
                    _lightController.value * math.pi,
                  );

                  return Transform.translate(
                    offset: Offset(0, -18 + ((1 - reveal) * 16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCalligraphy(c, reveal, breath),
                        const SizedBox(height: 22),
                        child!,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 👇 دي الدالة الجديدة الموسعة اللي طلبتها مدموجة هنا جاهزة
  Widget _buildCalligraphy(_SplashColors c, double reveal, double breath) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 14),
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Text(
              _arabicText,
              style: _calligraphyStyle(
                c,
                color: c.ink.withValues(alpha: 0.10),
                blur: 0,
              ),
            ),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                final Rect expandedBounds = Rect.fromLTRB(
                  bounds.left - 40,
                  bounds.top - 60,
                  bounds.right + 40,
                  bounds.bottom + 60,
                );

                final double stop1 = (reveal * 0.3).clamp(0.0, 1.0);
                final double stop2 = (reveal * 0.7).clamp(0.0, 1.0);

                return LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    c.inkDeep,
                    c.ink,
                    c.inkBright,
                    c.ink.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: [0.0, stop1, stop2, reveal, 1.0],
                ).createShader(expandedBounds);
              },
              child: Text(
                _arabicText,
                style: _calligraphyStyle(
                  c,
                  color: c.ink,
                  blur: 7 + (breath * 6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _calligraphyStyle(
    _SplashColors c, {
    required Color color,
    required double blur,
  }) {
    // بنبني على الخط المحسوب مرة واحدة في [_baseCalligraphy] — اللي بيتغير
    // كل frame هو اللون وقوة البلور بس.
    return _baseCalligraphy.copyWith(
      color: color,
      shadows: [
        Shadow(
          color: c.halo.withValues(alpha: c.glowAlpha),
          blurRadius: blur,
          offset: const Offset(0, 0),
        ),
        Shadow(
          color: c.inkDeep.withValues(alpha: c.glowAlpha * 0.8),
          blurRadius: blur * 2,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }
}

/// ألوان شاشة البداية — زمردي على رملي في النهار، زمردي فاتح على أخضر
/// غامق في الليل. الحركة والتوقيت زي ما هما، اللي اتغير هو اللون بس.
class _SplashColors {
  final Color ground;
  final Color groundMid;
  final Color glowNear;
  final Color glowFar;

  /// لون الخط العربي ودرجاته في التدرّج اللي بيكشف الاسم
  final Color ink;
  final Color inkDeep;
  final Color inkBright;

  /// الذهبي الهادي — الهالة والخط الفاصل
  final Color halo;
  final Color subtitle;

  final double auraAlpha;
  final double auraSwing;
  final double glowAlpha;

  const _SplashColors({
    required this.ground,
    required this.groundMid,
    required this.glowNear,
    required this.glowFar,
    required this.ink,
    required this.inkDeep,
    required this.inkBright,
    required this.halo,
    required this.subtitle,
    required this.auraAlpha,
    required this.auraSwing,
    required this.glowAlpha,
  });

  static _SplashColors of(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }

  /// النهار — رملي دافي والاسم زمردي غامق
  static const _SplashColors _light = _SplashColors(
    ground: Color(0xFFF0E9DA),
    groundMid: Color(0xFFF7F3EA),
    glowNear: Color(0xFFFFFDF8),
    glowFar: Color(0xFFFBF4E4),
    ink: Color(0xFF0F6B4F),
    inkDeep: Color(0xFF083D2D),
    inkBright: Color(0xFF2E9370),
    halo: Color(0xFFC9A227),
    subtitle: Color(0xFF6B7A73),
    auraAlpha: 0.16,
    auraSwing: 0.10,
    glowAlpha: 0.14,
  );

  /// الليل — فحمي محايد يطابق خلفية الثيم الجديدة، والاسم زمردي هادي
  static const _SplashColors _dark = _SplashColors(
    ground: Color(0xFF101413),
    groundMid: Color(0xFF161C1A),
    glowNear: Color(0xFF1E2623),
    glowFar: Color(0xFF252E2A),
    ink: Color(0xFF52B892),
    inkDeep: Color(0xFF2A6B52),
    inkBright: Color(0xFFA9E0C6),
    halo: Color(0xFFD9B75A),
    subtitle: Color(0xFF9BA8A2),
    auraAlpha: 0.12,
    auraSwing: 0.08,
    glowAlpha: 0.24,
  );
}

/// الهالة الزخرفية ورا الاسم.
///
/// بتاخد الـ [Animation] نفسها وبتمررها لـ `super(repaint:)`، فبترسم لوحدها
/// كل frame من غير ما أي widget يعيد البناء. اللون بيتحسب جوّه [paint]
/// عشان الـ painter مايتغيّرش مع كل قيمة جديدة.
class _IslamicAuraPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;
  final double baseAlpha;
  final double swing;

  /// عدد نقط الحلقة. الشكل فيه 8 فصوص، و64 نقطة تكفي إنها تبان ناعمة —
  /// 96 كانت شغل زيادة في كل frame من غير فرق واضح.
  static const int _segments = 64;

  const _IslamicAuraPainter({
    required this.progress,
    required this.color,
    required this.baseAlpha,
    required this.swing,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    final double breath = math.sin(t * math.pi);
    final Color tint = color.withValues(alpha: baseAlpha + (breath * swing));

    final Offset center = size.center(Offset.zero);
    final double base = math.min(size.width, size.height) * 0.36;

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = tint;

    canvas.save();
    canvas.translate(center.dx, center.dy - 42);
    canvas.rotate((t - 0.5) * 0.08);

    for (int layer = 0; layer < 3; layer++) {
      final double radius = base + (layer * 34);
      final Path path = Path();

      for (int i = 0; i <= _segments; i++) {
        final double angle = (math.pi * 2 * i / _segments);
        final double petal = math.sin(angle * 8 + t * math.pi * 2);
        final double r = radius + (petal * (8 + layer * 2));
        final Offset point = Offset(math.cos(angle) * r, math.sin(angle) * r);

        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }

      canvas.drawPath(path, ringPaint);
    }

    final Paint rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..color = tint.withValues(alpha: tint.a * 0.55);

    for (int i = 0; i < 24; i++) {
      final double angle = (math.pi * 2 * i / 24) + (t * 0.12);
      final Offset start = Offset(
        math.cos(angle) * base * 0.74,
        math.sin(angle) * base * 0.74,
      );
      final Offset end = Offset(
        math.cos(angle) * base * 1.48,
        math.sin(angle) * base * 1.48,
      );
      canvas.drawLine(start, end, rayPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IslamicAuraPainter oldDelegate) {
    // الحركة جاية من repaint: progress، فمحتاجين نعيد الرسم هنا بس لو
    // الثيم اتغيّر (نهاري/ليلي).
    return oldDelegate.color != color ||
        oldDelegate.baseAlpha != baseAlpha ||
        oldDelegate.swing != swing;
  }
}