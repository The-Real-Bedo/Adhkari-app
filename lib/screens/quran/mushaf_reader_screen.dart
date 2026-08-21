import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/ayah.dart';
import '../../services/mushaf_prefs.dart';
import '../../services/quran_text_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mushaf_ornaments.dart';

/// شاشة قراءة سورة كاملة بالرسم العثماني.
///
/// النص بيترسم متصل ومضبوط الحواف (justify) مع وردة رقم بعد كل آية — زي
/// صفحة المصحف. المحاولة الأولى كانت كل آية في كارت لوحدها، وده بيقرا
/// كأنه قائمة مش مصحف.
class MushafReaderScreen extends StatefulWidget {
  final int surahId;
  final String surahName;

  /// مكية / مدنية — بتظهر في لوحة عنوان السورة، وممكن تكون null
  final String? typeLabel;

  /// الآية اللي نفتح عندها — بتيجي من علامة القراءة
  final int? startAyah;

  const MushafReaderScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    this.typeLabel,
    this.startAyah,
  });

  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen> {
  /// أقصى عدد حروف في الكتلة الواحدة.
  ///
  /// السورة كلها في فقرة واحدة معناها إن البقرة (٢٨٦ آية، ~٢٥ ألف حرف)
  /// تتخطط وتترسم كاملة في كل frame، مع ٢٨٦ WidgetSpan للورود. بنقسمها
  /// لكتل قد الشاشة تقريبًا عشان ListView يبني المرئي بس. جوه الكتلة النص
  /// يفضل متصل ومضبوط الحواف، فالشكل مايتغيرش.
  static const int _blockCharBudget = 1200;

  /// سقف محاولات الوصول لآية العلامة. كل محاولة = frame واحد بينط لآخر
  /// المبني، والـ ListView بيبني اللي بعده. السقف عشان مانلفش للأبد لو
  /// الآية مش موجودة لأي سبب.
  static const int _maxJumpAttempts = 40;

  final ScrollController _scrollController = ScrollController();

  /// مفتاح على وردة الآية اللي جايين عندها من العلامة
  final GlobalKey _targetKey = GlobalKey();

  /// متعرّف لمس لكل آية. بيتبنوا مرة واحدة بعد التحميل وبيتم التخلص منهم
  /// في dispose — الـ TextSpan بيمسك المتعرّف طول عمره.
  final Map<int, TapGestureRecognizer> _recognizers = {};

  List<Ayah> _ayahs = const [];
  List<List<Ayah>> _blocks = const [];
  bool _loading = true;
  String? _error;

  /// الآية اللي المستخدم لمسها — بيظهر لها شريط أدوات تحت
  int? _selected;

  /// تظليل خفيف على آية العلامة عند الفتح، بيروح أول ما يلمس أي حاجة
  int? _resumeHighlight;

  @override
  void initState() {
    super.initState();
    _resumeHighlight = widget.startAyah;
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ayahs = await QuranTextService.surah(widget.surahId);
      if (!mounted) return;

      for (final recognizer in _recognizers.values) {
        recognizer.dispose();
      }
      _recognizers.clear();
      for (final ayah in ayahs) {
        _recognizers[ayah.number] = TapGestureRecognizer()
          ..onTap = () => _select(ayah.number);
      }

      setState(() {
        _ayahs = ayahs;
        _blocks = _splitIntoBlocks(ayahs);
        _loading = false;
      });
      _scheduleJump();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static List<List<Ayah>> _splitIntoBlocks(List<Ayah> ayahs) {
    final blocks = <List<Ayah>>[];
    var current = <Ayah>[];
    var length = 0;

    for (final ayah in ayahs) {
      current.add(ayah);
      length += ayah.text.length;
      if (length >= _blockCharBudget) {
        blocks.add(current);
        current = <Ayah>[];
        length = 0;
      }
    }
    if (current.isNotEmpty) blocks.add(current);

    return blocks;
  }

  /// الوصول لآية العلامة.
  ///
  /// ListView بيبني بالترتيب من فوق، فالنط لآخر المبني بيبني الشوية اللي
  /// بعدها من غير ما نعدّي الهدف. أول ما الوردة يبقى ليها context بنظبط
  /// عليها بالظبط بـ ensureVisible.
  void _scheduleJump([int attempt = 0]) {
    if (widget.startAyah == null || attempt >= _maxJumpAttempts) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final targetContext = _targetKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.2,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        return;
      }

      final position = _scrollController.position;
      if (position.maxScrollExtent <= position.pixels) return; // خلص المبني
      _scrollController.jumpTo(position.maxScrollExtent);
      _scheduleJump(attempt + 1);
    });
  }

  void _select(int number) {
    setState(() {
      _resumeHighlight = null;
      _selected = _selected == number ? null : number;
    });
  }

  Ayah? _ayahOf(int number) {
    for (final ayah in _ayahs) {
      if (ayah.number == number) return ayah;
    }
    return null;
  }

  /// النص اللي بيتنسخ أو يتشارك — الآية وبعدها مرجعها
  String _quote(Ayah ayah) =>
      '${ayah.text}\n[سورة ${widget.surahName}: ${ayah.number}]';

  Future<void> _bookmark(Ayah ayah) async {
    await MushafPrefs.setBookmark(
      MushafBookmark(
        surahId: widget.surahId,
        surahName: widget.surahName,
        ayah: ayah.number,
      ),
    );
    if (!mounted) return;
    setState(() => _selected = null);
    _toast('اتحفظت علامة القراءة عند الآية ${ayah.number}');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openTypographySheet() {
    final p = context.palette;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(child: _TypographySheet(palette: p)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // ورق المصحف بيميل للأصفر الدافي، وبيملا الشاشة كلها — مش كارت طايف
    // على خلفية. في الليل بنسيب سطح الثيم زي ما هو عشان مانبيّضش الشاشة
    // في وش اللي بيقرا في الضلمة.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark ? p.surface : const Color(0xFFFCF7EA);

    final selected = _selected;
    final selectedAyah = selected == null ? null : _ayahOf(selected);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: pageColor,
        appBar: AppBar(
          backgroundColor: pageColor,
          foregroundColor: p.text,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: Text('سورة ${widget.surahName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.text_fields),
              tooltip: 'الخط والتباعد',
              onPressed: _openTypographySheet,
            ),
          ],
        ),
        body: _buildBody(p),
        // شريط أدوات الآية المحددة — بيطلع ويختفي بحركة قصيرة
        bottomNavigationBar: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: selectedAyah == null
              ? const SizedBox(width: double.infinity)
              : _AyahActionBar(
                  palette: p,
                  label: 'الآية ${selectedAyah.number}',
                  onBookmark: () => _bookmark(selectedAyah),
                  onCopy: () {
                    Clipboard.setData(
                      ClipboardData(text: _quote(selectedAyah)),
                    );
                    setState(() => _selected = null);
                    _toast('تم نسخ الآية');
                  },
                  onShare: () {
                    Share.share(_quote(selectedAyah));
                    setState(() => _selected = null);
                  },
                  onClose: () => setState(() => _selected = null),
                ),
        ),
      ),
    );
  }

  Widget _buildBody(AppPalette p) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: p.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 52, color: p.textFaint),
              const SizedBox(height: AppSpace.md),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted),
              ),
              const SizedBox(height: AppSpace.md),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('حاول تاني'),
              ),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<double>(
      valueListenable: MushafPrefs.fontSizeNotifier,
      builder: (context, fontSize, _) => ValueListenableBuilder<double>(
        valueListenable: MushafPrefs.lineHeightNotifier,
        builder: (context, lineHeight, _) {
          final textStyle = QuranTextStyle.amiri(
            fontSize: fontSize,
            color: p.text,
            height: lineHeight,
          );

          return ListView.builder(
            // الـ controller بيخلي موضع القراءة ثابت لما المستخدم يغيّر
            // حجم الخط والشاشة تتعاد بناءها
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
            itemCount: _blocks.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildHeader(p, fontSize);
              return Text.rich(
                _blockSpan(_blocks[index - 1], p, fontSize),
                textAlign: TextAlign.justify,
                style: textStyle,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppPalette p, double fontSize) {
    return Column(
      children: [
        const SizedBox(height: AppSpace.sm),
        SurahBanner(
          name: widget.surahName,
          typeLabel: widget.typeLabel,
          ayahCount: _ayahs.length,
          color: p.accent,
          textColor: p.text,
        ),
        const SizedBox(height: AppSpace.lg),
        if (surahHasBasmala(widget.surahId)) ...[
          Text(
            basmala,
            textAlign: TextAlign.center,
            style: QuranTextStyle.amiri(
              fontSize: fontSize + 1,
              color: p.primary,
              height: 1.9,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ],
    );
  }

  /// كتلة آيات في span واحد: نص الآية، بعده وردة رقمها، بعده مسافة.
  TextSpan _blockSpan(List<Ayah> block, AppPalette p, double fontSize) {
    final markerSize = fontSize * 1.6;
    final children = <InlineSpan>[];

    for (final ayah in block) {
      final isMarked =
          _selected == ayah.number || _resumeHighlight == ayah.number;
      final highlight = isMarked ? p.primarySoft : null;

      children.add(
        TextSpan(
          text: ayah.text,
          recognizer: _recognizers[ayah.number],
          style: TextStyle(backgroundColor: highlight),
        ),
      );
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AyahMarker(
            key: ayah.number == widget.startAyah ? _targetKey : null,
            number: ayah.number,
            size: markerSize,
            color: p.accent,
            background: highlight,
          ),
        ),
      );
      children.add(const TextSpan(text: ' '));
    }

    return TextSpan(children: children);
  }
}

/// شريط أدوات الآية المحددة
class _AyahActionBar extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onClose;

  const _AyahActionBar({
    required this.palette,
    required this.label,
    required this.onBookmark,
    required this.onCopy,
    required this.onShare,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.border)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs,
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: palette.textMuted,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.bookmark_add_outlined, color: palette.primary),
                tooltip: 'علّم آخر موضع قراءة',
                onPressed: onBookmark,
              ),
              IconButton(
                icon: Icon(Icons.copy_outlined, color: palette.textMuted),
                tooltip: 'نسخ',
                onPressed: onCopy,
              ),
              IconButton(
                icon: Icon(Icons.share_outlined, color: palette.textMuted),
                tooltip: 'مشاركة',
                onPressed: onShare,
              ),
              IconButton(
                icon: Icon(Icons.close, color: palette.textFaint),
                tooltip: 'إلغاء التحديد',
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// درج حجم الخط وتباعد السطور، مع معاينة حيّة بنفس القيم
class _TypographySheet extends StatelessWidget {
  final AppPalette palette;

  const _TypographySheet({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.xl,
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: MushafPrefs.fontSizeNotifier,
        builder: (context, fontSize, _) => ValueListenableBuilder<double>(
          valueListenable: MushafPrefs.lineHeightNotifier,
          builder: (context, lineHeight, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الخط والتباعد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: AppSpace.md),

              // معاينة بنفس إعدادات الصفحة عشان المستخدم يشوف الأثر فورًا
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: AppRadius.cardR,
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'قُلْ هُوَ ٱللَّهُ أَحَدٌ ٱللَّهُ ٱلصَّمَدُ',
                  textAlign: TextAlign.center,
                  style: QuranTextStyle.amiri(
                    fontSize: fontSize,
                    color: palette.text,
                    height: lineHeight,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),

              _SliderRow(
                icon: Icons.format_size,
                label: 'حجم الخط',
                value: fontSize,
                min: MushafPrefs.minFontSize,
                max: MushafPrefs.maxFontSize,
                palette: palette,
                onChanged: (v) => MushafPrefs.fontSizeNotifier.value = v,
                onChangeEnd: MushafPrefs.setFontSize,
              ),
              _SliderRow(
                icon: Icons.format_line_spacing,
                label: 'تباعد السطور',
                value: lineHeight,
                min: MushafPrefs.minLineHeight,
                max: MushafPrefs.maxLineHeight,
                palette: palette,
                onChanged: (v) => MushafPrefs.lineHeightNotifier.value = v,
                onChangeEnd: MushafPrefs.setLineHeight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final AppPalette palette;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.palette,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.textMuted),
        const SizedBox(width: AppSpace.sm),
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: palette.primary,
            inactiveColor: palette.border,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
