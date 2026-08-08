import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/quran_download_service.dart';
import '../../services/quran_prefs.dart';
import '../../theme/app_theme.dart';
import '../../utils/arabic_text.dart';
import '../../widgets/app_card.dart';
import 'quran_player_screen.dart';

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
  Set<int> _downloaded = <int>{};
  final Map<int, double?> _downloading = {};
  final Map<int, StreamSubscription<DownloadProgress>> _subs = {};

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
    for (final sub in _subs.values) { sub.cancel(); }
    super.dispose();
  }

  void _attachToRunningJobs() {
    for (final job in QuranDownloadService.activeJobs) {
      if (job.reciterId != widget.reciter.id) continue;
      if (job.moshafId != widget.moshaf.id) continue;
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
          .where((f) => f.moshafId == widget.moshaf.id && f.reciterId == widget.reciter.id)
          .map((f) => f.surahId)
          .toSet();
    });
  }

  Future<void> _toggleFavourite(int surahId) async {
    final isFav = await QuranPrefs.toggleFavouriteSurah(surahId);
    if (!mounted) return;
    setState(() { isFav ? _favourites.add(surahId) : _favourites.remove(surahId); });
  }

  List<Surah> get _visible {
    final q = _query.trim();
    if (q.isEmpty) return _available;
    return _available.where((s) => arabicContains(s.name, q) || s.id.toString() == q).toList();
  }

  Future<void> _onDownloadTap(Surah surah) async {
    if (_downloading.containsKey(surah.id)) { await _confirmCancel(surah); return; }
    if (_downloaded.contains(surah.id)) { await _confirmDelete(surah); return; }

    setState(() => _downloading[surah.id] = null);
    final size = await QuranDownloadService.remoteSize(widget.moshaf, surah.id);
    if (!mounted) return;
    setState(() => _downloading.remove(surah.id));

    final approved = await _confirmDownload(surah, size);
    if (approved != true || !mounted) return;
    _startDownload(surah);
  }

  Future<bool?> _confirmDownload(Surah surah, int? size) {
    final p = context.palette;
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
              Row(children: [
                Icon(Icons.sd_storage, size: 18, color: p.textFaint),
                const SizedBox(width: 8),
                Text('الحجم: ${QuranDownloadService.formatBytes(size)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Text(size == null ? 'تعذر معرفة الحجم من الخادم. تحب تكمل التحميل؟'
                  : 'هيتم استخدام الحجم ده من باقة الإنترنت بتاعتك.',
                style: TextStyle(fontSize: 13, color: p.textMuted)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تحميل')),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Surah surah) async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('مسح سورة ${surah.name}'),
          content: const Text('هتتمسح من الجهاز وهتحتاج إنترنت عشان تسمعها تاني.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('مسح', style: TextStyle(color: p.danger))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await QuranDownloadService.delete(widget.reciter.id, widget.moshaf.id, surah.id);
    if (!mounted) return;
    setState(() => _downloaded.remove(surah.id));
  }

  void _startDownload(Surah surah) {
    setState(() => _downloading[surah.id] = 0.0);
    final job = QuranDownloadService.startDownload(widget.reciter.id, widget.moshaf, surah.id);
    _watch(job);
  }

  void _watch(DownloadJob job) {
    final surahId = job.surahId;
    _subs[surahId] = job.stream.listen(
      (progress) { if (mounted) setState(() => _downloading[surahId] = progress.fraction); },
      onDone: () {
        _subs.remove(surahId);
        if (!mounted) return;
        setState(() { _downloading.remove(surahId); if (!job.cancelled) _downloaded.add(surahId); });
        if (!job.cancelled) _toast('تم تحميل سورة ${_nameOf(surahId)}');
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
    for (final s in _available) { if (s.id == surahId) return s.name; }
    return '$surahId';
  }

  Future<void> _confirmCancel(Surah surah) async {
    final job = QuranDownloadService.activeJob(widget.reciter.id, widget.moshaf.id, surah.id);
    if (job == null) return;
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('إيقاف تحميل ${surah.name}'),
          content: const Text('التحميل هيتلغي واللي نزل هيتمسح.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('كمّل التحميل')),
            TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('إيقاف', style: TextStyle(color: p.danger))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await job.cancel();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Directionality(textDirection: TextDirection.rtl, child: Text(message)),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _buildDownloadButton(Surah surah) {
    final p = context.palette;
    final isDownloading = _downloading.containsKey(surah.id);
    final isDownloaded = _downloaded.contains(surah.id);

    if (isDownloading) {
      final fraction = _downloading[surah.id];
      return SizedBox(
        width: 40, height: 40,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: 'إيقاف التحميل',
          onPressed: () => _onDownloadTap(surah),
          icon: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: p.primary, value: fraction)),
              Icon(Icons.close, size: 12, color: p.primary),
            ],
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(isDownloaded ? Icons.download_done : Icons.download_outlined,
        color: isDownloaded ? p.success : p.textFaint),
      tooltip: isDownloaded ? 'متاحة بدون إنترنت' : 'تحميل للاستماع بدون نت',
      onPressed: () => _onDownloadTap(surah),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final visible = _visible;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Column(
            children: [
              Text(widget.reciter.name, style: const TextStyle(fontSize: 17)),
              Text(widget.moshaf.name, style: TextStyle(fontSize: 12, color: p.textMuted)),
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
                decoration: const InputDecoration(
                  hintText: 'ابحث باسم السورة أو رقمها...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (_available.length < 114)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 15, color: p.textFaint),
                  const SizedBox(width: 6),
                  Expanded(child: Text('الرواية دي متاح فيها ${_available.length} سورة',
                    style: TextStyle(fontSize: 12, color: p.textMuted))),
                ]),
              ),
            Expanded(
              child: visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'مفيش سورة بالاسم ده',
                      hint: 'جرب تكتب جزء من اسم السورة، أو رقمها من ١ لـ ١١٤',
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final surah = visible[index];
                        final isFav = _favourites.contains(surah.id);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: p.primarySoft,
                              child: Text('${surah.id}', style: TextStyle(color: p.primary, fontWeight: FontWeight.bold)),
                            ),
                            title: Text('سورة ${surah.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(surah.typeLabel, style: TextStyle(fontSize: 12, color: p.textMuted)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDownloadButton(surah),
                                IconButton(
                                  icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? p.accent : p.textFaint),
                                  tooltip: isFav ? 'شيل من المفضلة' : 'ضيف للمفضلة',
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
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => QuranPlayerScreen(
        reciter: widget.reciter, moshaf: widget.moshaf,
        allSuwar: widget.allSuwar, startSurahId: surah.id,
      ),
    ));
  }
}
