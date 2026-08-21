import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/azkar_data.dart';
import '../models/zikr_model.dart';
import '../theme/app_theme.dart';

class AzkarPage extends StatefulWidget {
  final double fontSize;

  const AzkarPage({super.key, required this.fontSize});

  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  bool _showSources = true;

  final List<_AzkarSection> _sections = [
    _AzkarSection('الصباح', 'morning', AzkarData.morningAzkar),
    _AzkarSection('المساء', 'evening', AzkarData.eveningAzkar),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

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
            indicatorColor: p.primary,
            labelColor: p.text,
            unselectedLabelColor: p.textMuted,
            tabs: _sections.map((section) => Tab(text: section.title)).toList(),
          ),
        ),
        body: TabBarView(
          children: _sections.map((section) {
            return AzkarList(
              items: section.items,
              fontSize: widget.fontSize,
              type: section.type,
              title: section.title,
              showSources: _showSources,
            );
          }).toList(),
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
  final bool showSources;

  const AzkarList({
    super.key,
    required this.items,
    required this.fontSize,
    required this.type,
    required this.title,
    required this.showSources,
  });

  @override
  State<AzkarList> createState() => _AzkarListState();
}

class _AzkarListState extends State<AzkarList> {
  int _currentStreak = 0;
  int _totalCompleted = 0;
  String _lastCompletionDate = '';
  bool _favoritesOnly = false;
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadProgress().then((_) => _checkDailyReset());
    _loadStats();
    _loadFavorites();
  }

  @override
  void didUpdateWidget(covariant AzkarList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _loadProgress().then((_) => _checkDailyReset());
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
    final p = context.palette;
    _registerCompletion();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: p.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: p.success, size: 70),
              const SizedBox(height: AppSpace.lg),
              Text(
                "أتممت أذكار ${widget.title}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: p.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                "اللهم تقبل وبارك في وردك",
                style: TextStyle(color: p.textMuted),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CompletionStat(
                      icon: Icons.local_fire_department,
                      label: 'متتالي',
                      value: '$_currentStreak يوم',
                      color: p.accent,
                    ),
                    Container(width: 1, height: 42, color: p.border),
                    _CompletionStat(
                      icon: Icons.timeline,
                      label: 'مجموع',
                      value: '$_totalCompleted',
                      color: p.primary,
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
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.chip),
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
    final p = context.palette;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: p.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, color: p.primary, size: 48),
              const SizedBox(height: AppSpace.md),
              Text(
                'إحصائيات الأذكار',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: p.text,
                ),
              ),
              const SizedBox(height: 18),
              _buildStatRow(
                p,
                Icons.local_fire_department,
                'الأيام المتتالية',
                '$_currentStreak يوم',
                p.accent,
              ),
              const SizedBox(height: AppSpace.md),
              _buildStatRow(
                p,
                Icons.check_circle_outline,
                'مجموع الإتمامات',
                '$_totalCompleted',
                p.success,
              ),
              const SizedBox(height: AppSpace.md),
              _buildStatRow(
                p,
                Icons.calendar_today,
                'آخر إتمام',
                _lastCompletionDate.isEmpty
                    ? 'لم يتم بعد'
                    : _lastCompletionDate,
                p.primary,
              ),
              const SizedBox(height: AppSpace.lg),
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
    AppPalette p,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: p.textMuted)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// المعروض دلوقتي — المفضلة بس أو الكل. مفيش ترتيب بالمكتمل: الأذكار
  /// ليها ترتيب متعارف عليه في الورد، ومحدش المفروض يعيد ترتيبه.
  List<Zikr> _getDisplayItems() {
    if (!_favoritesOnly) return widget.items;
    return widget.items
        .where((item) => _favorites.contains(item.text))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
          color: p.surfaceAlt,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _favoritesOnly ? Icons.star : Icons.star_border,
                      size: 22,
                    ),
                    color: _favoritesOnly ? p.accent : null,
                    tooltip: 'المفضلة',
                    onPressed: () =>
                        setState(() => _favoritesOnly = !_favoritesOnly),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bar_chart, size: 20),
                    tooltip: 'الإحصائيات',
                    onPressed: _showStatsDialog,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: p.accent,
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
                      color: p.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: p.border,
                  color: p.primary,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: displayItems.isEmpty
              ? const _EmptyAzkarState()
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
                    return _buildZikrCard(p, item, isDone, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildZikrCard(AppPalette p, Zikr item, bool isDone, int index) {
    final isFavorite = _favorites.contains(item.text);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDone ? p.surfaceAlt : p.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isDone ? p.border : p.primary,
          width: isDone ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: isDone ? 0.45 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.text,
                  style: QuranTextStyle.amiri(
                    color: p.text,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                  ),
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
                Row(
                  children: [
                    Icon(Icons.check_circle, color: p.success, size: 24),
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      "تم الإتمام اليوم",
                      style: TextStyle(
                        color: p.success,
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
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: p.primary),
                    ),
                    child: Text(
                      "باقي: ${item.current}",
                      style: TextStyle(
                        color: p.primary,
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
                    color: isFavorite ? p.accent : null,
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
              margin: const EdgeInsets.only(top: AppSpace.md),
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: p.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'اضغط على "باقي: ${item.current}" لبدء العد',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: p.textMuted,
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
    final p = context.palette;
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: p.text),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book, size: 14, color: p.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              source,
              style: TextStyle(
                fontSize: 12,
                color: p.textMuted,
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
  const _EmptyAzkarState();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border, size: 60, color: p.textFaint),
          const SizedBox(height: AppSpace.md),
          Text(
            'مفيش أذكار مفضلة في القسم ده',
            style: TextStyle(color: p.textMuted),
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
