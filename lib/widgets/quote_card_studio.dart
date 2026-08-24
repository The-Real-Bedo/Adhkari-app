import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

/// الثيمات المتاحة لتصميم البطاقة
enum CardThemePreset {
  emerald(
    id: 'emerald',
    name: 'الزمرد الملكي',
    background: Color(0xFF0D533D),
    surface: Color(0xFF0A4432),
    border: Color(0xFFC9A227),
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFE8C862),
    subtextColor: Color(0xFFD4E8DC),
  ),
  sand(
    id: 'sand',
    name: 'الرمل والبردي',
    background: Color(0xFFF7F3EA),
    surface: Color(0xFFEFE8DA),
    border: Color(0xFF0F6B4F),
    textColor: Color(0xFF1E2320),
    accentColor: Color(0xFF0F6B4F),
    subtextColor: Color(0xFF5A665E),
  ),
  midnight(
    id: 'midnight',
    name: 'الليل الكحلي',
    background: Color(0xFF111722),
    surface: Color(0xFF182030),
    border: Color(0xFFE5C365),
    textColor: Color(0xFFF0F4F8),
    accentColor: Color(0xFFE5C365),
    subtextColor: Color(0xFF9BA8BA),
  ),
  charcoal(
    id: 'charcoal',
    name: 'الفحم والأناقة',
    background: Color(0xFF1A1A1A),
    surface: Color(0xFF242424),
    border: Color(0xFF404040),
    textColor: Color(0xFFF5F5F5),
    accentColor: Color(0xFFC9A227),
    subtextColor: Color(0xFFAAAAAA),
  );

  final String id;
  final String name;
  final Color background;
  final Color surface;
  final Color border;
  final Color textColor;
  final Color accentColor;
  final Color subtextColor;

  const CardThemePreset({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.border,
    required this.textColor,
    required this.accentColor,
    required this.subtextColor,
  });
}

enum CardAspectRatio {
  square(label: 'مربع (1:1)', ratio: 1.0, icon: Icons.crop_square),
  story(label: 'قصة (9:16)', ratio: 9 / 16, icon: Icons.crop_portrait);

  final String label;
  final double ratio;
  final IconData icon;

  const CardAspectRatio({
    required this.label,
    required this.ratio,
    required this.icon,
  });
}

/// استوديو تصميم بطاقات الأذكار والآيات لمشاركتها كصور جمالية.
class QuoteCardStudio extends StatefulWidget {
  final String text;
  final String? title;
  final String? source;
  final bool isQuran;

  const QuoteCardStudio({
    super.key,
    required this.text,
    this.title,
    this.source,
    this.isQuran = false,
  });

  /// فتح الاستوديو كنافذة منبثقة أو صفحة سريعة
  static Future<void> show(
    BuildContext context, {
    required String text,
    String? title,
    String? source,
    bool isQuran = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuoteCardStudio(
        text: text,
        title: title,
        source: source,
        isQuran: isQuran,
      ),
    );
  }

  @override
  State<QuoteCardStudio> createState() => _QuoteCardStudioState();
}

class _QuoteCardStudioState extends State<QuoteCardStudio> {
  final GlobalKey _cardKey = GlobalKey();

  CardThemePreset _selectedTheme = CardThemePreset.emerald;
  CardAspectRatio _selectedRatio = CardAspectRatio.square;
  bool _showBasmala = false;
  bool _showWatermark = true;
  bool _showSource = true;
  double _fontSize = 20.0;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _showBasmala = widget.isQuran;
    // ضبط الحجم المبدئي حسب طول النص
    if (widget.text.length > 250) {
      _fontSize = 16.0;
    } else if (widget.text.length < 80) {
      _fontSize = 24.0;
    }
  }

  Future<Uint8List?> _captureCardPng() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // 3.0 pixelRatio لضمان نقاء وجودة الصورة المصدّرة على كل الشاشات
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('خطأ أثناء إنشاء الصورة: $e');
      return null;
    }
  }

  Future<void> _shareAsImage() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final bytes = await _captureCardPng();
      if (bytes == null) {
        throw Exception('تعذر تصدير البطاقة');
      }

      final tempDir = await getTemporaryDirectory();
      final shareDir = Directory('${tempDir.path}/card_share');
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }

      final fileName =
          'adhkari_card_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${shareDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: fileName)],
        text: widget.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت مشاركة الصورة: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _shareAsText() {
    final buffer = StringBuffer();
    if (_showBasmala) buffer.writeln('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ');
    if (widget.title != null) buffer.writeln('【 ${widget.title} 】');
    buffer.writeln(widget.text);
    if (_showSource && widget.source != null) {
      buffer.writeln('\n المصدر: ${widget.source}');
    }
    buffer.writeln('\n— تطبيق أذكاري');

    Share.share(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.90,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          // رأس النافذة
          _buildHeader(p),
          const Divider(height: 1),

          // محتوى الاستوديو
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // معاينة البطاقة
                  Center(child: _buildCardPreview()),

                  const SizedBox(height: 20),

                  // أدوات التحكم بالتصميم
                  _buildControls(p),
                ],
              ),
            ),
          ),

          // شريط أزرار التصدير
          _buildBottomBar(p),
        ],
      ),
    );
  }

  Widget _buildHeader(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.palette_outlined, color: p.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'صانع البطاقات الجمالية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: p.text,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPreview() {
    final theme = _selectedTheme;
    final isStory = _selectedRatio == CardAspectRatio.story;

    // أبعاد المعاينة على الشاشة
    final previewWidth = isStory ? 240.0 : 310.0;
    final previewHeight = isStory ? (240.0 * 16 / 9) : 310.0;

    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // الزخرفة الخلفية الهندسية الخفيفة
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardIslamicPatternPainter(
                    color: theme.accentColor.withValues(alpha: 0.07),
                  ),
                ),
              ),

              // الإطار الداخلي الأنيق
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.accentColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // محتوى النص
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // أعلى البطاقة: البسملة أو العنوان
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showBasmala) ...[
                          Text(
                            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                            style: QuranTextStyle.amiri(
                              color: theme.accentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 60,
                            height: 1.5,
                            color: theme.accentColor.withValues(alpha: 0.4),
                          ),
                        ],
                        if (widget.title != null) ...[
                          Text(
                            widget.title!,
                            style: TextStyle(
                              color: theme.accentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ],
                    ),

                    // وسط البطاقة: النص الأساسي
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Text(
                            widget.text,
                            textAlign: TextAlign.center,
                            style: QuranTextStyle.amiri(
                              color: theme.textColor,
                              fontSize: _fontSize,
                              height: 1.7,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // أسفل البطاقة: المصدر وعلامة التطبيق
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showSource && widget.source != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.surface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    theme.accentColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              widget.source!,
                              style: TextStyle(
                                color: theme.subtextColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_showWatermark)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 11,
                                color: theme.accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'تطبيق أذكاري',
                                style: TextStyle(
                                  color: theme.accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اختيار النمط اللوني
        Text(
          'السمة اللونية',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: p.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: CardThemePreset.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final theme = CardThemePreset.values[index];
              final isSelected = _selectedTheme == theme;

              return ChoiceChip(
                label: Text(theme.name),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedTheme = theme),
                selectedColor: p.primarySoft,
                backgroundColor: p.surfaceAlt,
                labelStyle: TextStyle(
                  color: isSelected ? p.primary : p.text,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                avatar: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.border, width: 1.2),
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? p.primary : p.border,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // اختيار المقاس
        Text(
          'أبعاد البطاقة',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: p.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: CardAspectRatio.values.map((ratio) {
            final isSelected = _selectedRatio == ratio;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedRatio = ratio),
                  icon: Icon(ratio.icon, size: 18),
                  label: Text(ratio.label, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isSelected ? p.primary : p.text,
                    backgroundColor: isSelected ? p.primarySoft : p.surfaceAlt,
                    side: BorderSide(
                      color: isSelected ? p.primary : p.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // حجم الخط
        Row(
          children: [
            Icon(Icons.format_size, size: 18, color: p.textMuted),
            const SizedBox(width: 8),
            Text(
              'حجم الخط',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: p.textMuted,
              ),
            ),
            Expanded(
              child: Slider(
                value: _fontSize,
                min: 14,
                max: 32,
                activeColor: p.primary,
                inactiveColor: p.border,
                onChanged: (val) => setState(() => _fontSize = val),
              ),
            ),
            Text(
              '${_fontSize.toInt()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: p.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // خيارات إظهار العناصر
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            FilterChip(
              label: const Text('البسملة', style: TextStyle(fontSize: 11)),
              selected: _showBasmala,
              onSelected: (val) => setState(() => _showBasmala = val),
              selectedColor: p.primarySoft,
              checkmarkColor: p.primary,
            ),
            if (widget.source != null)
              FilterChip(
                label: const Text('المصدر', style: TextStyle(fontSize: 11)),
                selected: _showSource,
                onSelected: (val) => setState(() => _showSource = val),
                selectedColor: p.primarySoft,
                checkmarkColor: p.primary,
              ),
            FilterChip(
              label: const Text('شعار التطبيق', style: TextStyle(fontSize: 11)),
              selected: _showWatermark,
              onSelected: (val) => setState(() => _showWatermark = val),
              selectedColor: p.primarySoft,
              checkmarkColor: p.primary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar(AppPalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _shareAsImage,
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isExporting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onPrimary,
                      ),
                    )
                  : const Icon(Icons.share, size: 18),
              label: Text(
                _isExporting ? 'جاري التجهيز...' : 'مشاركة كبطاقة صورة 🎨',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.outlined(
            tooltip: 'مشاركة كنص',
            icon: const Icon(Icons.text_snippet_outlined),
            onPressed: _shareAsText,
          ),
        ],
      ),
    );
  }
}

/// رسم نمط هندسي إسلامي تجريدي خفيف لخلفية البطاقة
class _CardIslamicPatternPainter extends CustomPainter {
  final Color color;

  _CardIslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const step = 48.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        final path = Path();
        path.moveTo(x, y - 10);
        path.lineTo(x + 10, y);
        path.lineTo(x, y + 10);
        path.lineTo(x - 10, y);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardIslamicPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
