import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/azkar_data.dart';
import '../models/zikr_model.dart';

class AzkarPage extends StatefulWidget {
  final double fontSize;

  const AzkarPage({super.key, required this.fontSize});

  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  String _searchQuery = '';
  bool _showSources = true;
  final TextEditingController _searchController = TextEditingController();

  final List<_AzkarSection> _sections = [
    _AzkarSection('الصباح', 'morning', AzkarData.morningAzkar),
    _AzkarSection('المساء', 'evening', AzkarData.eveningAzkar),
    _AzkarSection('النوم', 'sleep', AzkarData.sleepAzkar),
    _AzkarSection('الاستيقاظ', 'wake', AzkarData.wakeAzkar),
    _AzkarSection('بعد الصلاة', 'after_prayer', AzkarData.afterPrayerAzkar),
    _AzkarSection('أدعية', 'dua', AzkarData.selectedDua),
    _AzkarSection('الرقية', 'ruqyah', AzkarData.ruqyahAzkar),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);

    return DefaultTabController(
      length: _sections.length,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("أذكاري"),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: _showSources ? 'إخفاء المصادر' : 'إظهار المصادر',
              icon: Icon(
                _showSources ? Icons.menu_book : Icons.menu_book_outlined,
              ),
              onPressed: () => setState(() => _showSources = !_showSources),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: accent,
            labelColor: isDark ? Colors.white : Colors.black,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            tabs: _sections.map((section) => Tab(text: section.title)).toList(),
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.grey[100],
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
                decoration: InputDecoration(
                  hintText: 'ابحث في الأذكار...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF121212) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: _sections.map((section) {
                  return AzkarList(
                    items: section.items,
                    fontSize: widget.fontSize,
                    type: section.type,
                    title: section.title,
                    searchQuery: _searchQuery,
                    showSources: _showSources,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AzkarList extends StatefulWidget {
  final List<Zikr> items;
  final double fontSize;
  final String type;
  final String title;
  final String searchQuery;
  final bool showSources;

  const AzkarList({
    super.key,
    required this.items,
    required this.fontSize,
    required this.type,
    required this.title,
    required this.searchQuery,
    required this.showSources,
  });

  @override
  State<AzkarList> createState() => _AzkarListState();
}

class _AzkarListState extends State<AzkarList> {
  int _currentStreak = 0;
  int _totalCompleted = 0;
  String _lastCompletionDate = '';
  bool _sortCompletedLast = false;
  bool _favoritesOnly = false;
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadStats();
    _loadFavorites();
    _checkDailyReset();
  }

  @override
  void didUpdateWidget(covariant AzkarList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _loadProgress();
      _checkDailyReset();
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProgress = prefs.getString('azkar_${widget.type}_progress');

    if (savedProgress == null) return;

    try {
      final Map<String, dynamic> progress = jsonDecode(savedProgress);
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < widget.items.length; i++) {
          final zikrKey = 'zikr_$i';
          if (progress.containsKey(zikrKey)) {
            widget.items[i].current = progress[zikrKey];
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> progress = {};

    for (int i = 0; i < widget.items.length; i++) {
      progress['zikr_$i'] = widget.items[i].current;
    }

    await prefs.setString(
      'azkar_${widget.type}_progress',
      jsonEncode(progress),
    );
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentStreak = prefs.getInt('azkar_streak') ?? 0;
      _totalCompleted = prefs.getInt('azkar_total_completed') ?? 0;
      _lastCompletionDate = prefs.getString('azkar_last_completion') ?? '';
    });
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('azkar_streak', _currentStreak);
    await prefs.setInt('azkar_total_completed', _totalCompleted);
    await prefs.setString('azkar_last_completion', _lastCompletionDate);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favorites = (prefs.getStringList('favorite_azkar') ?? []).toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_azkar', _favorites.toList());
  }

  Future<void> _checkDailyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    final lastReset = prefs.getString('azkar_${widget.type}_last_reset');

    if (lastReset != today) {
      if (!mounted) return;
      setState(() {
        for (final item in widget.items) {
          item.current = item.max;
        }
      });
      await prefs.setString('azkar_${widget.type}_last_reset', today);
      await _saveProgress();
    }
  }

  void _completeAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final item in widget.items) {
        item.current = 0;
      }
    });
    _saveProgress();
    _showCompletionDialog();
  }

  void _toggleFavorite(Zikr item) {
    setState(() {
      if (_favorites.contains(item.text)) {
        _favorites.remove(item.text);
      } else {
        _favorites.add(item.text);
      }
    });
    _saveFavorites();
  }

  void _registerCompletion() {
    final today = DateTime.now().toString().split(' ')[0];
    if (_lastCompletionDate == today) return;

    _currentStreak++;
    _totalCompleted++;
    _lastCompletionDate = today;
    _saveStats();
  }

  void _showCompletionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);
    final orange = isDark ? Colors.orangeAccent : const Color(0xFFC15F00);
    final green = isDark ? Colors.greenAccent : const Color(0xFF2E7D32);
    _registerCompletion();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? [const Color(0xFF1a1a1a), const Color(0xFF0d0d0d)]
                  : [Colors.white, const Color(0xFFF5F5F5)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: green.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: green, size: 70),
              const SizedBox(height: 16),
              Text(
                "أتممت أذكار ${widget.title}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "اللهم تقبل وبارك في وردك",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CompletionStat(
                      icon: Icons.local_fire_department,
                      label: 'متتالي',
                      value: '$_currentStreak يوم',
                      color: orange,
                    ),
                    Container(width: 1, height: 42, color: Colors.white24),
                    _CompletionStat(
                      icon: Icons.timeline,
                      label: 'مجموع',
                      value: '$_totalCompleted',
                      color: accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Share.share(
                          'أتممت أذكار ${widget.title} اليوم، الحمد لله.',
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('مشاركة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('الحمد لله'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);
    final orange = isDark ? Colors.orangeAccent : const Color(0xFFC15F00);
    final green = isDark ? Colors.greenAccent : const Color(0xFF2E7D32);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1a1a1a) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, color: accent, size: 48),
              const SizedBox(height: 12),
              const Text(
                'إحصائيات الأذكار',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              _buildStatRow(
                Icons.local_fire_department,
                'الأيام المتتالية',
                '$_currentStreak يوم',
                orange,
                isDark,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                Icons.check_circle_outline,
                'مجموع الإتمامات',
                '$_totalCompleted',
                green,
                isDark,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                Icons.calendar_today,
                'آخر إتمام',
                _lastCompletionDate.isEmpty
                    ? 'لم يتم بعد'
                    : _lastCompletionDate,
                Colors.blueAccent,
                isDark,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Zikr> _getDisplayItems() {
    Iterable<Zikr> result = widget.items;

    if (widget.searchQuery.isNotEmpty) {
      result = result.where((item) {
        final text = item.text.toLowerCase();
        final source = item.source?.toLowerCase() ?? '';
        final query = widget.searchQuery.toLowerCase();
        return text.contains(query) || source.contains(query);
      });
    }

    if (_favoritesOnly) {
      result = result.where((item) => _favorites.contains(item.text));
    }

    final items = result.toList();
    if (!_sortCompletedLast) return items;

    final incomplete = items.where((item) => item.current > 0).toList();
    final complete = items.where((item) => item.current == 0).toList();
    return [...incomplete, ...complete];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);
    final orange = isDark ? Colors.orangeAccent : const Color(0xFFC15F00);
    final favoriteColor = isDark ? Colors.amberAccent : const Color(0xFFB7791F);
    final completed = widget.items.where((i) => i.current == 0).length;
    final progress = widget.items.isEmpty
        ? 0.0
        : completed / widget.items.length;
    final percentage = (progress * 100).toInt();
    final displayItems = _getDisplayItems();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.grey[100],
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.done_all, size: 20),
                    tooltip: 'إتمام الكل',
                    onPressed: _completeAll,
                  ),
                  IconButton(
                    icon: Icon(
                      _favoritesOnly ? Icons.star : Icons.star_border,
                      size: 22,
                    ),
                    color: _favoritesOnly ? favoriteColor : null,
                    tooltip: 'المفضلة',
                    onPressed: () =>
                        setState(() => _favoritesOnly = !_favoritesOnly),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bar_chart, size: 20),
                    tooltip: 'الإحصائيات',
                    onPressed: _showStatsDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.sort, size: 20),
                    tooltip: 'ترتيب المكتمل',
                    onPressed: () => setState(
                      () => _sortCompletedLast = !_sortCompletedLast,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: orange,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_currentStreak يوم',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  color: accent,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: displayItems.isEmpty
              ? _EmptyAzkarState(isDark: isDark)
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 15,
                    left: 15,
                    right: 15,
                    bottom: 100,
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final item = displayItems[index];
                    final isDone = item.current == 0;
                    return _buildZikrCard(item, isDone, index, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildZikrCard(Zikr item, bool isDone, int index, bool isDark) {
    final isFavorite = _favorites.contains(item.text);
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);
    final favoriteColor = isDark ? Colors.amberAccent : const Color(0xFFB7791F);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDone
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.grey[200]?.withValues(alpha: 0.5))
            : (isDark ? const Color(0xFF121212) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? (isDark ? Colors.white10 : Colors.black12)
              : accent.withValues(alpha: 0.3),
          width: isDone ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Opacity(
            opacity: isDone ? 0.45 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.text,
                  style: TextStyle(fontSize: widget.fontSize, height: 1.6),
                  textAlign: TextAlign.right,
                ),
                if (widget.showSources && item.source != null) ...[
                  const SizedBox(height: 10),
                  _SourceBadge(source: item.source!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isDone)
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.lightGreen,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "تم الإتمام اليوم",
                      style: TextStyle(
                        color: Colors.lightGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => item.current--);
                    _saveProgress();

                    if (item.current == 0) {
                      HapticFeedback.mediumImpact();
                      final allCompleted = widget.items.every(
                        (i) => i.current == 0,
                      );
                      if (allCompleted) {
                        Future.delayed(const Duration(milliseconds: 450), () {
                          if (mounted) _showCompletionDialog();
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? accent.withValues(alpha: 0.15)
                          : accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: isDark
                          ? null
                          : Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      "باقي: ${item.current}",
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      size: 21,
                    ),
                    color: isFavorite ? favoriteColor : null,
                    tooltip: 'المفضلة',
                    onPressed: () => _toggleFavorite(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'نسخ',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم النسخ الى حافظة الهاتف'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    tooltip: 'مشاركة',
                    onPressed: () => Share.share(item.text),
                  ),
                ],
              ),
            ],
          ),
          if (!isDone && index == 0 && item.current == item.max)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'اضغط على "باقي: ${item.current}" لبدء العد',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletionStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CompletionStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              source,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blueAccent,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAzkarState extends StatelessWidget {
  final bool isDark;

  const _EmptyAzkarState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد نتائج',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _AzkarSection {
  final String title;
  final String type;
  final List<Zikr> items;

  const _AzkarSection(this.title, this.type, this.items);
}
