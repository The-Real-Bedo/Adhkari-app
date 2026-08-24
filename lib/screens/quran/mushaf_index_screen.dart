import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/mushaf_prefs.dart';
import '../../services/quran_api_service.dart';
import '../../services/quran_page_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/arabic_text.dart';
import '../../widgets/app_card.dart';
import 'mushaf_book_screen.dart';

/// فهرس المصحف — تصفح السور والانتقال لصفحات مصحف المدينة الـ 604.
class MushafIndexScreen extends StatefulWidget {
  const MushafIndexScreen({super.key});

  @override
  State<MushafIndexScreen> createState() => _MushafIndexScreenState();
}

class _MushafIndexScreenState extends State<MushafIndexScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Surah> _suwar = const [];
  String _query = '';
  bool _loading = true;
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final suwar = await QuranApiService.fetchSuwar();
      if (!mounted) return;
      setState(() {
        _suwar = suwar;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Surah> get _visible {
    final q = _query.trim();
    if (q.isEmpty) return _suwar;
    return _suwar
        .where((s) => arabicContains(s.name, q) || s.id.toString() == q)
        .toList();
  }

  Future<void> _openSurahPage(int surahId) async {
    final page = QuranPageService.surahStartPages[surahId] ?? 1;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafBookScreen(
          initialPage: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المصحف الشريف'),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book),
              tooltip: 'فتح المصحف (604 صفحات)',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MushafBookScreen(),
                ),
              ),
            ),
          ],
        ),
        body: _buildBody(context.palette),
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
          padding: const EdgeInsets.all(24),
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

    final visible = _visible;

    return Column(
      children: [
                ValueListenableBuilder<MushafBookmark?>(
          valueListenable: MushafPrefs.bookmarkNotifier,
          builder: (context, bookmark, _) => bookmark == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _ResumeCard(
                    bookmark: bookmark,
                    onTap: () => _openSurahPage(bookmark.surahId),
                  ),
                ),
        ),
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
                    final startPage =
                        QuranPageService.surahStartPages[surah.id] ?? 1;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.primarySoft,
                          child: Text(
                            '${surah.id}',
                            style: TextStyle(
                              color: p.primary,
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
                          '${surah.typeLabel} • ص $startPage',
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        ),
                        trailing: Icon(Icons.chevron_left, color: p.textFaint),
                        onTap: () => _openSurahPage(surah.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// كارت "كمّل قراءة" — بيظهر بس لما يكون في علامة محفوظة.
class _ResumeCard extends StatelessWidget {
  final MushafBookmark bookmark;
  final VoidCallback onTap;

  const _ResumeCard({required this.bookmark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(Icons.bookmark, color: p.accent),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كمّل قراءتك',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'سورة ${bookmark.surahName} — آية ${bookmark.ayah}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: p.textFaint),
            tooltip: 'شيل العلامة',
            onPressed: MushafPrefs.clearBookmark,
          ),
        ],
      ),
    );
  }
}
