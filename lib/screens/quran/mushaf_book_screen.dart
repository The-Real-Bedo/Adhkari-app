import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ayah.dart';
import '../../services/khatmah_service.dart';
import '../../services/mushaf_prefs.dart';
import '../../services/quran_page_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/arabic_text.dart';
import '../../widgets/mushaf_ornaments.dart';
import '../../widgets/quote_card_studio.dart';

/// شاشة المصحف الشريف الحقيقي بنظام الصفحات الـ 604 (مصحف المدينة المنورة)
class MushafBookScreen extends StatefulWidget {
  final int initialPage;

  const MushafBookScreen({
    super.key,
    this.initialPage = 1,
  });

  @override
  State<MushafBookScreen> createState() => _MushafBookScreenState();
}

class _MushafBookScreenState extends State<MushafBookScreen> {
  late final PageController _pageController;
  late int _currentPage;
  bool _showControls = true;
  PageAyah? _selectedAyah;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, 604);
    // في PageView ذو الـ reverse، الفهرس 0 يمثل الصفحة 1
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final pageNum = index + 1;
    setState(() {
      _currentPage = pageNum;
      _selectedAyah = null;
    });

    // تحديث خطة الختمة وتتبع العادات إذا كان المستخدم يقرأ للأمام
    if (pageNum > KhatmahService.currentPlan.currentPage) {
      KhatmahService.updateCurrentPage(pageNum);
    }
  }

  void _jumpToPage(int pageNum) {
    final target = pageNum.clamp(1, 604);
    _pageController.jumpToPage(target - 1);
  }

  void _showJumpDialog() {
    final p = context.palette;
    final controller = TextEditingController(text: '$_currentPage');

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.auto_stories, color: p.primary),
              const SizedBox(width: 10),
              const Text('انتقال إلى صفحة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'أدخل رقم الصفحة في المصحف (1 - 604):',
                style: TextStyle(fontSize: 13, color: p.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'رقم الصفحة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(controller.text);
                if (page != null && page >= 1 && page <= 604) {
                  _jumpToPage(page);
                  Navigator.pop(dialogContext);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
              ),
              child: const Text('انتقال'),
            ),
          ],
        ),
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
        body: Stack(
          children: [
            // قارئ الصفحات التفاعلي (RTL PageView)
            GestureDetector(
              onTap: () => setState(() {
                _showControls = !_showControls;
                _selectedAyah = null;
              }),
              child: PageView.builder(
                controller: _pageController,
                itemCount: 604,
                reverse: true, // تصفح كتاب عربي من اليمين لليسار
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final pageNum = index + 1;
                  return _MushafPageItem(
                    pageNumber: pageNum,
                    selectedAyah: _selectedAyah,
                    onSelectAyah: (ayah) {
                      setState(() {
                        _selectedAyah = ayah;
                        _showControls = true;
                      });
                    },
                  );
                },
              ),
            ),

            // شريط العنوان العلوي (يختفي عند وضع الانغماس)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.95),
                  border: Border(bottom: BorderSide(color: p.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'المصحف الشريف',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: p.text,
                            ),
                          ),
                          Text(
                            'صفحة $_currentPage من 604',
                            style: TextStyle(fontSize: 12, color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add_outlined),
                      tooltip: 'حفظ علامة القراءة',
                      onPressed: () async {
                        await MushafPrefs.setBookmark(
                          MushafBookmark(
                            surahId: _selectedAyah?.surahId ?? 1,
                            surahName: _selectedAyah?.surahName ?? 'المصحف',
                            ayah: _selectedAyah?.numberInSurah ?? 1,
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم حفظ علامة القراءة عند صفحة $_currentPage'),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.find_in_page_outlined),
                      tooltip: 'انتقال لصفحة',
                      onPressed: _showJumpDialog,
                    ),
                  ],
                ),
              ),
            ),

            // شريط التحكم السفلي وخيارات الآية المحددة
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              bottom: _showControls ? 0 : -140,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  top: 12,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.95),
                  border: Border(top: BorderSide(color: p.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // شريط أدوات الآية عند تحديدها
                    if (_selectedAyah != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'سورة ${_selectedAyah!.surahName} — آية ${_selectedAyah!.numberInSurah}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: p.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, size: 20),
                            tooltip: 'مشاركة كبطاقة أو نص',
                            color: p.primary,
                            onPressed: () {
                              QuoteCardStudio.show(
                                context,
                                text: _selectedAyah!.text,
                                source: 'سورة ${_selectedAyah!.surahName} - آية ${_selectedAyah!.numberInSurah}',
                                isQuran: true,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            tooltip: 'نسخ الآية',
                            color: p.textMuted,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _selectedAyah!.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم نسخ الآية الكريمة')),
                              );
                            },
                          ),
                        ],
                      ),
                      Divider(color: p.border, height: 12),
                    ],

                    // شريط التمرير السريع للصفحات
                    Row(
                      children: [
                        Text('1', style: TextStyle(fontSize: 11, color: p.textMuted)),
                        Expanded(
                          child: Slider(
                            value: _currentPage.toDouble(),
                            min: 1,
                            max: 604,
                            divisions: 603,
                            activeColor: p.primary,
                            inactiveColor: p.border,
                            label: '$_currentPage',
                            onChanged: (val) => _jumpToPage(val.round()),
                          ),
                        ),
                        Text('604', style: TextStyle(fontSize: 11, color: p.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عارض محتوى الصفحة القرآنية الواحدة
class _MushafPageItem extends StatefulWidget {
  final int pageNumber;
  final PageAyah? selectedAyah;
  final ValueChanged<PageAyah> onSelectAyah;

  const _MushafPageItem({
    required this.pageNumber,
    required this.selectedAyah,
    required this.onSelectAyah,
  });

  @override
  State<_MushafPageItem> createState() => _MushafPageItemState();
}

class _MushafPageItemState extends State<_MushafPageItem> {
  late Future<MushafPage> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = QuranPageService.getPage(widget.pageNumber);
  }

  @override
  void didUpdateWidget(_MushafPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageNumber != oldWidget.pageNumber) {
      _pageFuture = QuranPageService.getPage(widget.pageNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return FutureBuilder<MushafPage>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: p.primary),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 48, color: p.textFaint),
                  const SizedBox(height: 12),
                  Text(
                    'تعذر تحميل صفحة ${widget.pageNumber}',
                    style: TextStyle(color: p.textMuted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _pageFuture = QuranPageService.getPage(widget.pageNumber);
                      });
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        final page = snapshot.data!;
        return _buildPageContent(context, p, page);
      },
    );
  }

  Widget _buildPageContent(BuildContext context, AppPalette p, MushafPage page) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ترويسة أعلى الصفحة: اسم السورة يميناً والجزء يساراً
            _buildPageHeader(p, page),

            const SizedBox(height: 10),
            Divider(color: p.border, height: 1),
            const SizedBox(height: 12),

            // متن الآيات داخل الصفحة
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildAyahsSpans(p, page),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Divider(color: p.border, height: 1),
            const SizedBox(height: 8),

            // رقم الصفحة في أسفل الصفحة بتنسيق المصحف
            Text(
              '– ${toArabicIndic(page.pageNumber)} –',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: p.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(AppPalette p, MushafPage page) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'سورة ${page.surahHeader}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: p.primary,
          ),
        ),
        Text(
          'الجزء ${page.juz}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: p.textMuted,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAyahsSpans(AppPalette p, MushafPage page) {
    final widgets = <Widget>[];
    int? currentSurahId;

    final currentBlock = <PageAyah>[];

    void flushBlock() {
      if (currentBlock.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text.rich(
            TextSpan(
              children: currentBlock.map((ayah) {
                final isSelected = widget.selectedAyah?.surahId == ayah.surahId &&
                    widget.selectedAyah?.numberInSurah == ayah.numberInSurah;

                return TextSpan(
                  children: [
                    TextSpan(
                      text: '${ayah.text} ',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 21,
                        height: 2.1,
                        color: isSelected ? p.primary : p.text,
                        backgroundColor: isSelected ? p.primarySoft : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => widget.onSelectAyah(ayah),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            ayah.marker,
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 18,
                              color: isSelected ? p.primary : p.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' '),
                  ],
                );
              }).toList(),
            ),
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
      currentBlock.clear();
    }

    for (final ayah in page.ayahs) {
      if (currentSurahId != ayah.surahId) {
        flushBlock();
        currentSurahId = ayah.surahId;

        // ترويسة بداية السورة إذا كانت بداية السورة في هذه الصفحة
        if (ayah.isFirstInSurah) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SurahBanner(
                name: ayah.surahName,
                typeLabel: null,
                ayahCount: 0,
                color: p.primary,
                textColor: p.text,
              ),
            ),
          );

          if (surahHasBasmala(ayah.surahId)) {
            widgets.add(
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Text(
                    basmala,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }
        }
      }

      currentBlock.add(ayah);
    }

    flushBlock();
    return widgets;
  }
}
