import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/quran_download_service.dart';
import '../../services/quran_prefs.dart';
import '../../utils/arabic_text.dart';
import 'quran_player_screen.dart';

/// قائمة سور الرواية المختارة.
/// بنعرض السور المتاحة في الرواية دي بس — مش كل قارئ عنده الـ 114.
class SurahListScreen extends StatefulWidget {
  final Reciter reciter;
  final Moshaf moshaf;
  final List<Surah> allSuwar;

  const SurahListScreen({
    super.key,
    required this.reciter,
    required this.moshaf,
    required this.allSuwar,
  });

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  final TextEditingController _searchController = TextEditingController();

  Set<int> _favourites = <int>{};
  String _query = '';

  /// السور المتحملة على الجهاز
  Set<int> _downloaded = <int>{};

  /// السور اللي بتتحمل دلوقتي ونسبة التقدم بتاعتها (null = الحجم مش معروف)
  final Map<int, double?> _downloading = {};

  /// اشتراكات المتابعة بس — التحميل نفسه عايش في الخدمة.
  /// لما نعمل dispose بنلغي المتابعة مش التحميل.
  final Map<int, StreamSubscription<DownloadProgress>> _subs = {};

  /// السور المتاحة في الرواية دي بالترتيب
  late final List<Surah> _available = widget.allSuwar
      .where((s) => widget.moshaf.surahList.contains(s.id))
      .toList();

  @override
  void initState() {
    super.initState();
    _loadFavourites();
    _loadDownloaded();
    _attachToRunningJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // بنلغي المتابعة بس. التحميل بيفضل شغال في الخدمة عشان لو المستخدم
    // رجع تاني يلاقيه مكمّل مش واقف من أول وجديد.
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  /// لو فيه تحميلات شغالة للرواية دي بنرجع نتفرج عليها.
  /// ده اللي بيخلي المستخدم يخرج ويرجع ويلاقي التحميل مكمّل.
  void _attachToRunningJobs() {
    for (final job in QuranDownloadService.activeJobs) {
      if (job.reciterId != widget.reciter.id) continue;
      if (job.moshafId != widget.moshaf.id) continue;

      // نعرض آخر نسبة وصل لها قبل ما نشترك، لأن الـ broadcast مش بيعيد
      // الأحداث اللي فاتت
      _downloading[job.surahId] = job.last?.fraction;
      _watch(job);
    }
  }

  Future<void> _loadFavourites() async {
    final favs = await QuranPrefs.favouriteSurahs();
    if (!mounted) return;
    setState(() => _favourites = favs);
  }

  Future<void> _loadDownloaded() async {
    final files = await QuranDownloadService.listDownloads();
    if (!mounted) return;
    setState(() {
      _downloaded = files
          .where(
            (f) =>
                f.moshafId == widget.moshaf.id &&
                f.reciterId == widget.reciter.id,
          )
          .map((f) => f.surahId)
          .toSet();
    });
  }

  Future<void> _toggleFavourite(int surahId) async {
    final isFav = await QuranPrefs.toggleFavouriteSurah(surahId);
    if (!mounted) return;
    setState(() {
      if (isFav) {
        _favourites.add(surahId);
      } else {
        _favourites.remove(surahId);
      }
    });
  }

  List<Surah> get _visible {
    final q = _query.trim();
    if (q.isEmpty) return _available;
    // بحث متسامح مع اختلاف الهمزة (الأعراف / الاعراف) أو برقم السورة
    return _available
        .where((s) => arabicContains(s.name, q) || s.id.toString() == q)
        .toList();
  }

  // ————— التحميل —————

  /// الضغط على زرار التحميل: لو متحملة نسأل عن المسح،
  /// ولو لأ نجيب الحجم الحقيقي الأول وبعدين نستأذن المستخدم
  Future<void> _onDownloadTap(Surah surah) async {
    // بيتحمل دلوقتي؟ الضغطة معناها إنه عايز يوقفه
    if (_downloading.containsKey(surah.id)) {
      await _confirmCancel(surah);
      return;
    }

    if (_downloaded.contains(surah.id)) {
      await _confirmDelete(surah);
      return;
    }

    // بنجيب الحجم بطلب HEAD خفيف — مش بنحمّل الملف
    setState(() => _downloading[surah.id] = null);
    final size = await QuranDownloadService.remoteSize(widget.moshaf, surah.id);
    if (!mounted) return;
    setState(() => _downloading.remove(surah.id));

    final approved = await _confirmDownload(surah, size);
    if (approved != true || !mounted) return;

    _startDownload(surah);
  }

  Future<bool?> _confirmDownload(Surah surah, int? size) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تحميل سورة ${surah.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sd_storage, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'الحجم: ${QuranDownloadService.formatBytes(size)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                size == null
                    // السيرفر مبعتش الحجم — نكون صادقين مع المستخدم
                    ? 'تعذر معرفة الحجم من الخادم. تحب تكمل التحميل؟'
                    : 'هيتم استخدام الحجم ده من باقة الإنترنت بتاعتك.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تحميل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Surah surah) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('مسح سورة ${surah.name}'),
          content: const Text(
            'هتتمسح من الجهاز وهتحتاج إنترنت عشان تسمعها تاني.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'مسح',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    await QuranDownloadService.delete(
      widget.reciter.id,
      widget.moshaf.id,
      surah.id,
    );
    if (!mounted) return;
    setState(() => _downloaded.remove(surah.id));
  }

  void _startDownload(Surah surah) {
    // 0.0 مش 0 — الخريطة بتاعتنا double? والقيمة دي بتتقرا كنسبة تقدم
    setState(() => _downloading[surah.id] = 0.0);

    // التحميل بيتسجل في الخدمة، فلو خرجنا من الشاشة بيكمّل لوحده
    final job = QuranDownloadService.startDownload(
      widget.reciter.id,
      widget.moshaf,
      surah.id,
    );
    _watch(job);
  }

  /// الاشتراك في تحميل شغال عشان نعرض تقدمه
  void _watch(DownloadJob job) {
    final surahId = job.surahId;

    _subs[surahId] = job.stream.listen(
      (progress) {
        if (!mounted) return;
        setState(() => _downloading[surahId] = progress.fraction);
      },
      onDone: () {
        _subs.remove(surahId);
        if (!mounted) return;
        setState(() {
          _downloading.remove(surahId);
          // لو المستخدم لغاه بإيده مش هيكون فيه ملف
          if (!job.cancelled) _downloaded.add(surahId);
        });
        if (!job.cancelled) {
          _toast('تم تحميل سورة ${_nameOf(surahId)}');
        }
      },
      onError: (Object e) {
        _subs.remove(surahId);
        if (!mounted) return;
        setState(() => _downloading.remove(surahId));
        _toast(e.toString());
      },
    );
  }

  String _nameOf(int surahId) {
    for (final s in _available) {
      if (s.id == surahId) return s.name;
    }
    return '$surahId';
  }

  /// إلغاء تحميل شغال — بيسأل الأول
  Future<void> _confirmCancel(Surah surah) async {
    final job = QuranDownloadService.activeJob(
      widget.reciter.id,
      widget.moshaf.id,
      surah.id,
    );
    if (job == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('إيقاف تحميل ${surah.name}'),
          content: const Text('التحميل هيتلغي واللي نزل هيتمسح.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('كمّل التحميل'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'إيقاف',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    await job.cancel();
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

  /// زرار التحميل بيعدي بتلات حالات: متحملة / بتتحمل / مش متحملة
  Widget _buildDownloadButton(Surah surah, Color accent) {
    final isDownloading = _downloading.containsKey(surah.id);
    final isDownloaded = _downloaded.contains(surah.id);

    if (isDownloading) {
      final fraction = _downloading[surah.id];
      return SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: 'إيقاف التحميل',
          onPressed: () => _onDownloadTap(surah),
          icon: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: accent,
                  // لو الحجم مش معروف بنعرض دوران مستمر بدل نسبة غلط
                  value: fraction,
                ),
              ),
              Icon(Icons.close, size: 12, color: accent),
            ],
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(
        isDownloaded ? Icons.download_done : Icons.download_outlined,
        color: isDownloaded ? Colors.green : Colors.grey,
      ),
      tooltip: isDownloaded ? 'متاحة بدون إنترنت' : 'تحميل للاستماع بدون نت',
      onPressed: () => _onDownloadTap(surah),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF00838F);
    final visible = _visible;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Column(
            children: [
              Text(
                widget.reciter.name,
                style: const TextStyle(fontSize: 17),
              ),
              Text(
                widget.moshaf.name,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم السورة أو رقمها...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF121212) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // تنبيه لو الرواية ناقصة سور، عشان المستخدم ميستغربش
            if (_available.length < 114)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'الرواية دي متاح فيها ${_available.length} سورة',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        'مفيش سورة بالاسم ده',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final surah = visible[index];
                        final isFav = _favourites.contains(surah.id);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          color: isDark
                              ? const Color(0xFF121212)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: accent.withValues(alpha: 0.15),
                              child: Text(
                                '${surah.id}',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              'سورة ${surah.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              surah.typeLabel,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDownloadButton(surah, accent),
                                IconButton(
                                  icon: Icon(
                                    isFav ? Icons.star : Icons.star_border,
                                    color: isFav ? Colors.amber : Colors.grey,
                                  ),
                                  onPressed: () => _toggleFavourite(surah.id),
                                ),
                              ],
                            ),
                            onTap: () => _play(surah),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _play(Surah surah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranPlayerScreen(
          reciter: widget.reciter,
          moshaf: widget.moshaf,
          allSuwar: widget.allSuwar,
          startSurahId: surah.id,
        ),
      ),
    );
  }
}
