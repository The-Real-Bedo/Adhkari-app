import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/quran_api_service.dart';
import '../../services/quran_audio_service.dart';
import '../../services/quran_prefs.dart';
import '../../theme/app_theme.dart';
import '../../utils/arabic_text.dart';
import '../../widgets/app_card.dart';
import 'downloads_screen.dart';
import 'mushaf_index_screen.dart';
import 'surah_list_screen.dart';

/// شاشة اختيار القارئ — بحث بالاسم العربي والمفضلة في الأول
class RecitersScreen extends StatefulWidget {
  const RecitersScreen({super.key});

  @override
  State<RecitersScreen> createState() => _RecitersScreenState();
}

class _RecitersScreenState extends State<RecitersScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Reciter> _all = const [];
  List<Surah> _suwar = const [];
  Set<int> _favourites = <int>{};

  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    try {
      final results = await Future.wait([
        QuranApiService.fetchReciters(),
        QuranApiService.fetchSuwar(),
        QuranPrefs.favouriteReciters(),
      ]);

      if (!mounted) return;
      setState(() {
        _all = results[0] as List<Reciter>;
        _suwar = results[1] as List<Surah>;
        _favourites = results[2] as Set<int>;
        _loading = false;
      });

      await _preloadLastPlayed();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _preloadLastPlayed() async {
    if (!QuranAudioService.isReady) return;
    final handler = QuranAudioService.handler;
    if (handler.mediaItem.value != null) return;

    final last = await QuranPrefs.lastPlayed();
    if (last == null || !mounted) return;

    Reciter? reciter;
    for (final r in _all) { if (r.id == last.reciterId) { reciter = r; break; } }
    if (reciter == null) return;

    Moshaf? moshaf;
    for (final m in reciter.moshaf) { if (m.id == last.moshafId) { moshaf = m; break; } }
    if (moshaf == null) return;

    try {
      await handler.loadReciter(
        reciterId: reciter.id, reciterName: reciter.name,
        moshaf: moshaf, allSuwar: _suwar, startSurahId: last.surahId,
        startPosition: last.position, autoPlay: false,
      );
    } catch (_) {}
  }

  Future<void> _retry() async { QuranApiService.clearMemoryCache(); await _load(); }

  Future<void> _toggleFavourite(int reciterId) async {
    final isFav = await QuranPrefs.toggleFavouriteReciter(reciterId);
    if (!mounted) return;
    setState(() { isFav ? _favourites.add(reciterId) : _favourites.remove(reciterId); });
  }

  List<Reciter> get _visible {
    final q = _query.trim();
    final filtered = q.isEmpty
        ? _all
        : _all.where((r) => arabicContains(r.name, q)).toList();
    final favs = filtered.where((r) => _favourites.contains(r.id)).toList();
    final rest = filtered.where((r) => !_favourites.contains(r.id)).toList();
    return [...favs, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('القرآن الكريم'),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'اقرأ المصحف',
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const MushafIndexScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download_done),
              tooltip: 'التلاوات المحمّلة',
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              ),
            ),
          ],
        ),
        body: _buildBody(p),
      ),
    );
  }

  Widget _buildBody(AppPalette p) {
    if (_loading) return Center(child: CircularProgressIndicator(color: p.primary));
    if (_error != null) return _ErrorView(message: _error!, onRetry: _retry);

    final visible = _visible;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'ابحث عن قارئ...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty ? null : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () { _searchController.clear(); setState(() => _query = ''); },
              ),
            ),
          ),
        ),
        if (visible.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'مفيش قارئ بالاسم ده',
              hint: 'جرب تكتب جزء من الاسم بس، أو امسح البحث وتصفّح القايمة',
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final reciter = visible[index];
                final isFav = _favourites.contains(reciter.id);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.primarySoft,
                      child: Icon(Icons.record_voice_over, color: p.primary),
                    ),
                    title: Text(reciter.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(
                      reciter.moshaf.length == 1
                          ? reciter.moshaf.first.name
                          : '${reciter.moshaf.length} روايات',
                      style: TextStyle(fontSize: 13, color: p.textMuted),
                    ),
                    trailing: IconButton(
                      icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? p.accent : p.textFaint),
                      tooltip: isFav ? 'شيل من المفضلة' : 'ضيف للمفضلة',
                      onPressed: () => _toggleFavourite(reciter.id),
                    ),
                    onTap: () => _openReciter(reciter),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _openReciter(Reciter reciter) async {
    final moshaf = reciter.moshaf.length == 1
        ? reciter.moshaf.first
        : await _pickMoshaf(reciter);
    if (moshaf == null || !mounted) return;

    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => SurahListScreen(reciter: reciter, moshaf: moshaf, allSuwar: _suwar),
    ));
  }

  Future<Moshaf?> _pickMoshaf(Reciter reciter) {
    final p = context.palette;
    return showModalBottomSheet<Moshaf>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('اختر الرواية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.text)),
              ),
              ...reciter.moshaf.map(
                (m) => ListTile(
                  title: Text(m.name, textAlign: TextAlign.right),
                  subtitle: Text('${m.surahList.length} سورة', textAlign: TextAlign.right),
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
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 56, color: p.textFaint),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: p.textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
