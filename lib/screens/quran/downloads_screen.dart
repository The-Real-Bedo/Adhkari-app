import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/quran_api_service.dart';
import '../../services/quran_download_service.dart';
import '../../services/quran_prefs.dart';
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

  int get _totalBytes => _files.fold<int>(0, (sum, f) => sum + f.bytes);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<Moshaf>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'اختر الرواية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...reciter.moshaf.map(
                (m) => ListTile(
                  title: Text(m.name),
                  subtitle: Text('${m.surahList.length} سورة'),
                  onTap: () => Navigator.pop(context, m),
                ),
              ),
              const SizedBox(height: 8),
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
            'هيتم مسح ${_files.length} ملف بحجم '
            '${QuranDownloadService.formatBytes(_totalBytes)}. '
            'هتحتاج إنترنت عشان تسمعهم تاني.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'مسح الكل',
                style: TextStyle(color: Colors.redAccent),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF00838F);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مكتبتي'),
            centerTitle: true,
            actions: [
              if (_files.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'مسح كل التحميلات',
                  onPressed: _deleteAll,
                ),
            ],
            bottom: TabBar(
              indicatorColor: accent,
              labelColor: accent,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.download_done), text: 'المحمّلة'),
                Tab(icon: Icon(Icons.star), text: 'المفضلة'),
              ],
            ),
          ),
          body: _loading
              ? Center(child: CircularProgressIndicator(color: accent))
              : TabBarView(
                  children: [
                    _buildDownloads(isDark, accent),
                    _buildFavourites(isDark, accent),
                  ],
                ),
        ),
      ),
    );
  }

  // ————— تبويب المحمّلة —————

  Widget _buildDownloads(bool isDark, Color accent) {
    if (_files.isEmpty) {
      return const _EmptyState(
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _StorageSummary(
          totalLabel: QuranDownloadService.formatBytes(_totalBytes),
          countLabel: '${_files.length} سورة محمّلة',
          accent: accent,
        ),
        const SizedBox(height: 8),

        for (final reciterId in reciterIds) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
            child: Row(
              children: [
                Icon(Icons.record_voice_over, size: 16, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _reciterById(reciterId)?.name ?? 'قارئ #$reciterId',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
                Text(
                  '${byReciter[reciterId]!.length} سورة',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          for (final file in byReciter[reciterId]!)
            _DownloadTile(
              title: 'سورة ${_surahNames[file.surahId] ?? file.surahId}',
              subtitle: QuranDownloadService.formatBytes(file.bytes),
              isDark: isDark,
              accent: accent,
              onPlay: () => _playDownloaded(file),
              onDelete: () => _deleteOne(file),
            ),
        ],
      ],
    );
  }

  // ————— تبويب المفضلة —————

  Widget _buildFavourites(bool isDark, Color accent) {
    if (_favReciters.isEmpty && _favSurahs.isEmpty) {
      return const _EmptyState(
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (favReciterList.isNotEmpty) ...[
          const _FavSectionTitle('القراء المفضلون'),
          for (final reciter in favReciterList)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isDark ? const Color(0xFF121212) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Icon(Icons.record_voice_over, color: accent),
                ),
                title: Text(
                  reciter.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  reciter.moshaf.length == 1
                      ? reciter.moshaf.first.name
                      : '${reciter.moshaf.length} روايات',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.star, color: Colors.amber),
                  tooltip: 'شيل من المفضلة',
                  onPressed: () => _unfavReciter(reciter.id),
                ),
                onTap: () => _openReciter(reciter),
              ),
            ),
          const SizedBox(height: 12),
        ],

        if (favSurahIds.isNotEmpty) ...[
          const _FavSectionTitle('السور المفضلة'),
          for (final surahId in favSurahIds)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isDark ? const Color(0xFF121212) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Text(
                    '$surahId',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'سورة ${_surahNames[surahId] ?? surahId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _surahById(surahId)?.typeLabel ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_circle_fill, color: accent),
                      tooltip: 'تشغيل',
                      onPressed: () => _playFavouriteSurah(surahId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.star, color: Colors.amber),
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

/// كارت ملخص المساحة المستخدمة
class _StorageSummary extends StatelessWidget {
  final String totalLabel;
  final String countLabel;
  final Color accent;

  const _StorageSummary({
    required this.totalLabel,
    required this.countLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            totalLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            countLabel,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
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
  final bool isDark;
  final Color accent;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _DownloadTile({
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.accent,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: isDark ? const Color(0xFF121212) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const Icon(Icons.offline_pin, color: Colors.green),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.play_circle_fill, color: accent),
              tooltip: 'تشغيل',
              onPressed: onPlay,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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

class _FavSectionTitle extends StatelessWidget {
  final String text;

  const _FavSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white38 : Colors.black45,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
