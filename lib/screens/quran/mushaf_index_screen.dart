import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/mushaf_prefs.dart';
import '../../services/quran_api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/arabic_text.dart';
import '../../widgets/app_card.dart';
import 'mushaf_reader_screen.dart';

/// فهرس المصحف — نفس الـ 114 سورة بتاعة شاشة الاستماع، بس القراءة بدل الصوت.
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

  /// مكية ولا مدنية — بتتعرض في لوحة عنوان السورة جوه المصحف. بنجيبها من
  /// القايمة المحمّلة بدل ما نمرّرها، عشان كارت "كمّل قراءتك" كمان يجيبها
  /// وهو مش شايف غير رقم السورة واسمها.
  String? _typeLabelOf(int surahId) {
    for (final surah in _suwar) {
      if (surah.id == surahId) return surah.typeLabel;
    }
    return null;
  }

  Future<void> _open(int surahId, String surahName, {int? startAyah}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          surahId: surahId,
          surahName: surahName,
          typeLabel: _typeLabelOf(surahId),
          startAyah: startAyah,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المصحف')),
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
                    onTap: () => _open(
                      bookmark.surahId,
                      bookmark.surahName,
                      startAyah: bookmark.ayah,
                    ),
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
                          surah.typeLabel,
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        ),
                        // مفيش أي علامة على السورة. قبل كده كانت السور
                        // المحفوظة للقراءة بدون إنترنت بتاخد علامة خضرا،
                        // واللي كان بيتقري غلط كأنها "سورة خلصتها".
                        trailing: Icon(Icons.chevron_left, color: p.textFaint),
                        onTap: () => _open(surah.id, surah.name),
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
