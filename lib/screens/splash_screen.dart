import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Timer? _detailsTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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

    _detailsTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) _detailsController.forward();
    });

    _navigationTimer = Timer(const Duration(milliseconds: 4700), () {
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

    return Scaffold(
      backgroundColor: c.ground,
      body: AnimatedBuilder(
        animation: Listenable.merge([_revealController, _lightController]),
        builder: (context, child) {
          final double reveal = Curves.easeInOutCubic.transform(
            _revealController.value,
          );
          final double breath = math.sin(_lightController.value * math.pi);

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
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
              ),
              CustomPaint(
                painter: _IslamicAuraPainter(
                  progress: _lightController.value,
                  color: c.halo.withValues(
                    alpha: c.auraAlpha + (breath * c.auraSwing),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, -18 + ((1 - reveal) * 16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCalligraphy(c, reveal, breath),
                      const SizedBox(height: 22),
                      FadeTransition(
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
                              style: GoogleFonts.raleway(
                                fontSize: 13,
                                color: c.subtitle,
                                letterSpacing: 9,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
    return GoogleFonts.scheherazadeNew(
      fontSize: 104,
      fontWeight: FontWeight.w700,
      height: 1.45,
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

class _IslamicAuraPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _IslamicAuraPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double base = math.min(size.width, size.height) * 0.36;

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = color;

    canvas.save();
    canvas.translate(center.dx, center.dy - 42);
    canvas.rotate((progress - 0.5) * 0.08);

    for (int layer = 0; layer < 3; layer++) {
      final double radius = base + (layer * 34);
      final Path path = Path();

      for (int i = 0; i <= 96; i++) {
        final double angle = (math.pi * 2 * i / 96);
        final double petal = math.sin(angle * 8 + progress * math.pi * 2);
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
      ..color = color.withValues(alpha: color.a * 0.55);

    for (int i = 0; i < 24; i++) {
      final double angle = (math.pi * 2 * i / 24) + (progress * 0.12);
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
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}