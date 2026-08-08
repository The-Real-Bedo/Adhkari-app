import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/quran_api_service.dart';
import '../../services/quran_download_service.dart';
import '../../services/quran_prefs.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import 'quran_player_screen.dart';
import 'surah_list_screen.dart';

/// مكتبة المستخدم: التلاوات المحمّلة + المفضلة.
///
/// قبل كده كانت قايمة مسطحة بتعرض "سورة 2" وبزرار مسح بس. دلوقتي
/// مقسومة تبويبين، والمحمّلة متجمعة تحت كل قارئ وتقدر تشغّلها من هنا
/// على طول من غير ما تلف على القارئ والرواية تاني.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadedFile> _files = const [];
  List<Reciter> _reciters = const [];
  List<Surah> _suwar = const [];

  Set<int> _favReciters = <int>{};
  Set<int> _favSurahs = <int>{};

  bool _loading = true;

  /// أسماء السور بالرقم — عشان نعرض "البقرة" مش "2"
  Map<int, String> get _surahNames => {for (final s in _suwar) s.id: s.name};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final files = await QuranDownloadService.listDownloads();
    final favReciters = await QuranPrefs.favouriteReciters();
    final favSurahs = await QuranPrefs.favouriteSurahs();

    // القوايم من الكاش — لو مفيش نت هنعرض الأرقام بدل الأسماء وخلاص
    List<Reciter> reciters = const [];
    List<Surah> suwar = const [];
    try {
      reciters = await QuranApiService.fetchReciters();
      suwar = await QuranApiService.fetchSuwar();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _files = files;
      _reciters = reciters;
      _suwar = suwar;
      _favReciters = favReciters;
      _favSurahs = favSurahs;
      _loading = false;
    });
  }

  Reciter? _reciterById(int id) {
    for (final r in _reciters) {
      if (r.id == id) return r;
    }
    return null;
  }

  Moshaf? _moshafById(Reciter reciter, int moshafId) {
    for (final m in reciter.moshaf) {
      if (m.id == moshafId) return m;
    }
    return null;
  }

  Surah? _surahById(int id) {
    for (final s in _suwar) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ————— التشغيل —————

  /// تشغيل سورة محمّلة — بنفتح المشغل بنفس القارئ والرواية بتوعها
  Future<void> _playDownloaded(DownloadedFile file) async {
    final reciter = _reciterById(file.reciterId);
    final moshaf = reciter == null
        ? null
        : _moshafById(reciter, file.moshafId);

    if (reciter == null || moshaf == null) {
      _toast('مش لاقيين بيانات القارئ — افتح قسم القرآن مرة وجرب تاني');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranPlayerScreen(
          reciter: reciter,
          moshaf: moshaf,
          allSuwar: _suwar,
          startSurahId: file.surahId,
        ),
      ),
    );
  }

  /// السور المفضلة متسجلة بالرقم بس من غير قارئ، فبنشغلها بآخر قارئ
  /// كان بيسمع له. لو لسه مسمعش حاجة بنقوله يختار قارئ الأول.
  Future<void> _playFavouriteSurah(int surahId) async {
    final last = await QuranPrefs.lastPlayed();
    if (!mounted) return;

    if (last == null) {
      _toast('اختر قارئ من قسم القرآن الأول');
      return;
    }

    final reciter = _reciterById(last.reciterId);
    final moshaf = reciter == null
        ? null
        : _moshafById(reciter, last.moshafId);

    if (reciter == null || moshaf == null) {
      _toast('مش لاقيين بيانات القارئ');
      return;
    }

    if (!moshaf.surahList.contains(surahId)) {
      _toast('السورة دي مش متاحة عند ${reciter.name}');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuranPlayerScreen(
          reciter: reciter,
          moshaf: moshaf,
          allSuwar: _suwar,
          startSurahId: surahId,
        ),
      ),
    );
  }

  Future<void> _openReciter(Reciter reciter) async {
    // لو الرواية واحدة بس مفيش داعي نسأل
    final moshaf = reciter.moshaf.length == 1
        ? reciter.moshaf.first
        : await _pickMoshaf(reciter);

    if (moshaf == null) return;
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahListScreen(
          reciter: reciter,
          moshaf: moshaf,
          allSuwar: _suwar,
        ),
      ),
    );
    await _load();
  }

  Future<Moshaf?> _pickMoshaf(Reciter reciter) {
    final p = context.palette;

    return showModalBottomSheet<Moshaf>(
      context: context,
      backgroundColor: p.surface,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Text(
                  'اختر الرواية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
              ),
              ...reciter.moshaf.map(
                (m) => ListTile(
                  title: Text(m.name, style: TextStyle(color: p.text)),
                  subtitle: Text(
                    '${m.surahList.length} سورة',
                    style: TextStyle(color: p.textMuted),
                  ),
                  onTap: () => Navigator.pop(context, m),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
          ),
        ),
      ),
    );
  }

  // ————— المسح —————

  Future<void> _deleteOne(DownloadedFile file) async {
    await QuranDownloadService.delete(
      file.reciterId,
      file.moshafId,
      file.surahId,
    );
    await _load();
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مسح كل التحميلات'),
          content: Text(
            'هيتم مسح ${_files.length} سورة. '
            'هتحتاج إنترنت عشان تسمعهم تاني.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'مسح الكل',
                style: TextStyle(color: context.palette.danger),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    await QuranDownloadService.deleteAll();
    await _load();
  }

  Future<void> _unfavSurah(int surahId) async {
    await QuranPrefs.toggleFavouriteSurah(surahId);
    if (!mounted) return;
    setState(() => _favSurahs.remove(surahId));
  }

  Future<void> _unfavReciter(int reciterId) async {
    await QuranPrefs.toggleFavouriteReciter(reciterId);
    if (!mounted) return;
    setState(() => _favReciters.remove(reciterId));
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مكتبتي'),
            actions: [
              if (_files.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'مسح كل التحميلات',
                  onPressed: _deleteAll,
                ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.download_done), text: 'المحمّلة'),
                Tab(icon: Icon(Icons.star), text: 'المفضلة'),
              ],
            ),
          ),
          body: _loading
              ? Center(child: CircularProgressIndicator(color: p.primary))
              : TabBarView(
                  children: [
                    _buildDownloads(p),
                    _buildFavourites(p),
                  ],
                ),
        ),
      ),
    );
  }

  // ————— تبويب المحمّلة —————

  Widget _buildDownloads(AppPalette p) {
    if (_files.isEmpty) {
      return const EmptyState(
        icon: Icons.download_outlined,
        title: 'مفيش تلاوات محمّلة',
        hint: 'اضغط على أيقونة التحميل جنب أي سورة عشان تسمعها بدون إنترنت',
      );
    }

    // بنجمع الملفات تحت كل قارئ عشان القايمة تبقى مقروءة
    final byReciter = <int, List<DownloadedFile>>{};
    for (final f in _files) {
      byReciter.putIfAbsent(f.reciterId, () => []).add(f);
    }

    final reciterIds = byReciter.keys.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xl,
      ),
      children: [
        _StorageSummary(
          countLabel: '${_files.length} سورة',
        ),
        const SizedBox(height: AppSpace.sm),

        for (final reciterId in reciterIds) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
            child: Row(
              children: [
                Icon(Icons.record_voice_over, size: 16, color: p.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _reciterById(reciterId)?.name ?? 'قارئ #$reciterId',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.primary,
                    ),
                  ),
                ),
                Text(
                  '${byReciter[reciterId]!.length} سورة',
                  style: TextStyle(fontSize: 11, color: p.textFaint),
                ),
              ],
            ),
          ),
          for (final file in byReciter[reciterId]!)
            _DownloadTile(
              title: 'سورة ${_surahNames[file.surahId] ?? file.surahId}',
              subtitle: 'متاحة بدون إنترنت',
              onPlay: () => _playDownloaded(file),
              onDelete: () => _deleteOne(file),
            ),
        ],
      ],
    );
  }

  // ————— تبويب المفضلة —————

  Widget _buildFavourites(AppPalette p) {
    if (_favReciters.isEmpty && _favSurahs.isEmpty) {
      return const EmptyState(
        icon: Icons.star_border,
        title: 'مفيش مفضلة لسه',
        hint: 'اضغط على النجمة جنب أي قارئ أو سورة عشان تلاقيهم هنا بسرعة',
      );
    }

    final favReciterList = _favReciters
        .map(_reciterById)
        .whereType<Reciter>()
        .toList();

    final favSurahIds = _favSurahs.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xl,
      ),
      children: [
        if (favReciterList.isNotEmpty) ...[
          const SectionTitle('القراء المفضلون'),
          for (final reciter in favReciterList)
            Card(
              margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.primarySoft,
                  child: Icon(Icons.record_voice_over, color: p.primary),
                ),
                title: Text(
                  reciter.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  reciter.moshaf.length == 1
                      ? reciter.moshaf.first.name
                      : '${reciter.moshaf.length} روايات',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.star, color: p.accent),
                  tooltip: 'شيل من المفضلة',
                  onPressed: () => _unfavReciter(reciter.id),
                ),
                onTap: () => _openReciter(reciter),
              ),
            ),
          const SizedBox(height: AppSpace.md),
        ],

        if (favSurahIds.isNotEmpty) ...[
          const SectionTitle('السور المفضلة'),
          for (final surahId in favSurahIds)
            Card(
              margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.primarySoft,
                  child: Text(
                    '$surahId',
                    style: TextStyle(
                      color: p.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  'سورة ${_surahNames[surahId] ?? surahId}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _surahById(surahId)?.typeLabel ?? '',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_circle_fill, color: p.primary),
                      tooltip: 'تشغيل',
                      onPressed: () => _playFavouriteSurah(surahId),
                    ),
                    IconButton(
                      icon: Icon(Icons.star, color: p.accent),
                      tooltip: 'شيل من المفضلة',
                      onPressed: () => _unfavSurah(surahId),
                    ),
                  ],
                ),
                onTap: () => _playFavouriteSurah(surahId),
              ),
            ),
        ],
      ],
    );
  }
}

/// كارت ملخص المكتبة — عدد السور بس. الحجم بيتعرض قبل التحميل عشان
/// المستخدم يعرف هياكل قد إيه من الباقة، وبعد ما ينزل مبقاش يهم.
class _StorageSummary extends StatelessWidget {
  final String countLabel;

  const _StorageSummary({required this.countLabel});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Text(
            countLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: p.primary,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'متاحة بدون إنترنت',
            style: TextStyle(fontSize: 13, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

/// سطر سورة محمّلة — تشغيل ومسح
class _DownloadTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _DownloadTile({
    required this.title,
    required this.subtitle,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Icon(Icons.offline_pin, color: p.success),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: p.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.play_circle_fill, color: p.primary),
              tooltip: 'تشغيل',
              onPressed: onPlay,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: p.danger),
              tooltip: 'مسح',
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onPlay,
      ),
    );
  }
}
