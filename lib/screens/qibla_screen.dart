import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../services/prayer_times_service.dart';
import '../theme/app_theme.dart';

/// شاشة بوصلة القبلة التفاعلية مع ردود الفعل الاهتزازية عند المحاذاة الدقيقة.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen>
    with SingleTickerProviderStateMixin {
  static const double _kaabaLat = 21.422487;
  static const double _kaabaLng = 39.826206;

  bool _loadingLocation = true;
  String? _locationError;

  double? _qiblaBearing;
  double? _distanceKm;

  StreamSubscription<CompassEvent>? _compassSub;
  double _smoothHeading = 0.0;

  bool _isAligned = false;
  DateTime? _lastHapticTime;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initLocationAndCompass();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndCompass() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    final result = await PrayerTimesService.resolveLocation();
    if (!mounted) return;

    if (!result.hasLocation) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'تعذر تحديد الموقع الجغرافي لحساب اتجاه القبلة';
      });
      return;
    }

    final loc = result.location!;
    final qibla = _calculateQibla(loc.latitude, loc.longitude);
    final distanceMeters = Geolocator.distanceBetween(
      loc.latitude,
      loc.longitude,
      _kaabaLat,
      _kaabaLng,
    );

    setState(() {
      _qiblaBearing = qibla;
      _distanceKm = (distanceMeters / 1000).roundToDouble();
      _loadingLocation = false;
    });

    _startCompassListener();
  }

  void _startCompassListener() {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;

      // تصفية ناعمة لتجنب الاهتزاز المفاجئ في حركة الإبرة (Low-pass smoothing)
      final diff = _angleDifference(heading, _smoothHeading);
      final newSmooth = (_smoothHeading + diff * 0.25) % 360.0;

      final qibla = _qiblaBearing ?? 0.0;
      final qiblaOffset = _angleDifference(qibla, newSmooth).abs();
      final alignedNow = qiblaOffset <= 3.5;

      if (alignedNow && !_isAligned) {
        _triggerHapticFeedback();
      }

      setState(() {
        _smoothHeading = (newSmooth + 360.0) % 360.0;
        _isAligned = alignedNow;
      });
    });
  }

  void _triggerHapticFeedback() {
    final now = DateTime.now();
    if (_lastHapticTime != null &&
        now.difference(_lastHapticTime!).inMilliseconds < 800) {
      return;
    }
    _lastHapticTime = now;
    HapticFeedback.heavyImpact();
  }

  static double _calculateQibla(double lat, double lng) {
    final phi1 = lat * math.pi / 180.0;
    const phi2 = _kaabaLat * math.pi / 180.0;
    final deltaLambda = (_kaabaLng - lng) * math.pi / 180.0;

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final qiblaRad = math.atan2(y, x);
    final qiblaDeg = (qiblaRad * 180.0 / math.pi + 360.0) % 360.0;
    return qiblaDeg;
  }

  static double _angleDifference(double target, double current) {
    var diff = (target - current) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return diff;
  }

  void _showCalibrationDialog() {
    final p = context.palette;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.screen_rotation, color: p.primary),
            const SizedBox(width: 10),
            Text('معايرة البوصلة', style: TextStyle(color: p.text, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'للحصول على أعلى دقة، حرّك هاتفك في الهواء على شكل رقم 8 بالإنجليزية (∞) لعدة مرات بعيداً عن المعادن والأجهزة الإلكترونية.',
              style: TextStyle(color: p.textMuted, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('فهمت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          title: const Text('اتجاه القبلة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'معايرة البوصلة',
              onPressed: _showCalibrationDialog,
            ),
          ],
        ),
        body: _loadingLocation
            ? Center(child: CircularProgressIndicator(color: p.primary))
            : _locationError != null
                ? _buildErrorView(p)
                : _buildCompassView(p),
      ),
    );
  }

  Widget _buildErrorView(AppPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, size: 64, color: p.danger),
            const SizedBox(height: AppSpace.md),
            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.text, fontSize: 16),
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton.icon(
              onPressed: _initLocationAndCompass,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(backgroundColor: p.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassView(AppPalette p) {
    final qibla = _qiblaBearing ?? 0.0;
    // زاوية تدوير القرص
    final dialRotation = -_smoothHeading * (math.pi / 180.0);
    // زاوية الكعبة بالنسبة للقرص
    final kaabaAngleOnDial = qibla * (math.pi / 180.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // بطاقة الحالة العلوية
            _buildStatusCard(p),

            const Spacer(),

            // البوصلة الدوارة
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final scale = _isAligned ? _pulseAnimation.value : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: 290,
                      height: 290,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // هالة التوهج عند المحاذاة
                          if (_isAligned)
                            Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: p.primary.withValues(alpha: 0.4),
                                    blurRadius: 32,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),

                          // قرص البوصلة الدائري مع الاتجاهات
                          Transform.rotate(
                            angle: dialRotation,
                            child: _CompassDial(
                              palette: p,
                              isAligned: _isAligned,
                              kaabaAngle: kaabaAngleOnDial,
                            ),
                          ),

                          // المؤشر الثابت لأعلى الهاتف
                          Positioned(
                            top: 6,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _isAligned ? p.primary : p.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),

                          // مركز البوصلة: أيقونة الكعبة أو الدرجة
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: p.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isAligned ? p.primary : p.border,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mosque,
                                  size: 26,
                                  color: _isAligned ? p.primary : p.accent,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_smoothHeading.toInt()}°',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: p.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Spacer(),

            // إحصائيات القبلة والمسافة لمكة المكرمة
            _buildInfoFooter(p),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(AppPalette p) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _isAligned ? p.primarySoft : p.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAligned ? p.primary : p.border,
          width: _isAligned ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAligned ? Icons.check_circle : Icons.explore_outlined,
            color: _isAligned ? p.primary : p.accent,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAligned
                      ? 'أنت في اتجاه القبلة تماماً 🕋'
                      : 'وجّه هاتفك نحو زاوية الكعبة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isAligned ? p.primary : p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isAligned
                      ? 'تمت المحاذاة بنجاح'
                      : 'زاوية القبلة: ${_qiblaBearing?.toStringAsFixed(1)}° من الشمال',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoFooter(AppPalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            p,
            icon: Icons.navigation_outlined,
            label: 'زاوية القبلة',
            value: '${_qiblaBearing?.toStringAsFixed(0)}°',
          ),
          Container(width: 1, height: 36, color: p.border),
          _buildInfoItem(
            p,
            icon: Icons.straighten,
            label: 'المسافة إلى مكة',
            value: _distanceKm != null ? '${_distanceKm!.toInt()} كم' : '—',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    AppPalette p, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: p.primary, size: 22),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: p.textMuted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: p.text,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// رسم قرص البوصلة مع الاتجاهات الأربعة والكعبة
class _CompassDial extends StatelessWidget {
  final AppPalette palette;
  final bool isAligned;
  final double kaabaAngle;

  const _CompassDial({
    required this.palette,
    required this.isAligned,
    required this.kaabaAngle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(280, 280),
      painter: _CompassDialPainter(
        palette: palette,
        isAligned: isAligned,
        kaabaAngle: kaabaAngle,
      ),
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  final AppPalette palette;
  final bool isAligned;
  final double kaabaAngle;

  _CompassDialPainter({
    required this.palette,
    required this.isAligned,
    required this.kaabaAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // الخلفية الدائرية للقرص
    final bgPaint = Paint()
      ..color = palette.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // الإطار الخارجي
    final borderPaint = Paint()
      ..color = isAligned ? palette.primary : palette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 2.5 : 1.5;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // خطوط التدريج
    final tickPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.0;

    final majorTickPaint = Paint()
      ..color = palette.textMuted
      ..strokeWidth = 1.8;

    for (int i = 0; i < 360; i += 5) {
      final angle = (i - 90) * math.pi / 180.0;
      final isMajor = i % 30 == 0;
      final isCardinal = i % 90 == 0;

      if (isCardinal) continue; // الحروف ستكتب مكانها

      final tickLength = isMajor ? 12.0 : 6.0;
      final start = Offset(
        center.dx + (radius - 8 - tickLength) * math.cos(angle),
        center.dy + (radius - 8 - tickLength) * math.sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 8) * math.cos(angle),
        center.dy + (radius - 8) * math.sin(angle),
      );

      canvas.drawLine(start, end, isMajor ? majorTickPaint : tickPaint);
    }

    // كتابة الاتجاهات الأربعة (ش، ج، ق، غ)
    _drawCardinal(canvas, center, radius - 24, 'ش', -math.pi / 2, palette.danger);
    _drawCardinal(canvas, center, radius - 24, 'ج', math.pi / 2, palette.textMuted);
    _drawCardinal(canvas, center, radius - 24, 'شـ', 0, palette.textMuted);
    _drawCardinal(canvas, center, radius - 24, 'غ', math.pi, palette.textMuted);

    // رسم علامة الكعبة على حافة القرص
    final kaabaCenterAngle = kaabaAngle - (math.pi / 2);
    final kaabaPos = Offset(
      center.dx + (radius - 36) * math.cos(kaabaCenterAngle),
      center.dy + (radius - 36) * math.sin(kaabaCenterAngle),
    );

    final kaabaBadgePaint = Paint()
      ..color = isAligned ? palette.primary : palette.accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(kaabaPos, 14, kaabaBadgePaint);

    final kaabaBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(kaabaPos, 14, kaabaBorderPaint);

    // رمز الكعبة الذهبي
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🕋',
        style: TextStyle(fontSize: 14),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    textPainter.paint(
      canvas,
      kaabaPos - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawCardinal(
    Canvas canvas,
    Offset center,
    double radius,
    String text,
    double angle,
    Color color,
  ) {
    final pos = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned ||
      oldDelegate.kaabaAngle != kaabaAngle ||
      oldDelegate.palette != palette;
}
