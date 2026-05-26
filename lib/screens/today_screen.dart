import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/azkar_data.dart';
import '../models/zikr_model.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback openTasbih;
  final VoidCallback openAzkar;
  final VoidCallback openSettings;

  const TodayScreen({
    super.key,
    required this.openTasbih,
    required this.openAzkar,
    required this.openSettings,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<_TodaySummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<_TodaySummary> _loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDailyTarget = prefs.getInt('dailyTasbihTarget') ?? 1000;

    return _TodaySummary(
      morningProgress: _loadAzkarProgress(
        prefs,
        'morning',
        AzkarData.morningAzkar,
      ),
      eveningProgress: _loadAzkarProgress(
        prefs,
        'evening',
        AzkarData.eveningAzkar,
      ),
      dailyTasbih: prefs.getInt('dailyCounter') ?? 0,
      totalTasbih: prefs.getInt('totalCounter') ?? 0,
      dailyTasbihTarget: savedDailyTarget <= 0 ? 1000 : savedDailyTarget,
      streak: prefs.getInt('azkar_streak') ?? 0,
      lastLog: _readLastLog(prefs),
    );
  }

  double _loadAzkarProgress(
    SharedPreferences prefs,
    String type,
    List<Zikr> items,
  ) {
    final savedProgress = prefs.getString('azkar_${type}_progress');
    if (items.isEmpty || savedProgress == null) return 0;

    try {
      final Map<String, dynamic> progress = jsonDecode(savedProgress);
      int completed = 0;

      for (int i = 0; i < items.length; i++) {
        final current = progress['zikr_$i'] ?? items[i].max;
        if (current == 0) completed++;
      }

      return completed / items.length;
    } catch (_) {
      return 0;
    }
  }

  String _readLastLog(SharedPreferences prefs) {
    final logString = prefs.getString('activityLog');
    if (logString == null) return 'لا يوجد نشاط بعد';

    try {
      final List<dynamic> logs = jsonDecode(logString);
      if (logs.isEmpty) return 'لا يوجد نشاط بعد';
      final first = Map<String, dynamic>.from(logs.first);
      return '${first['count']} مرة - ${first['zikr']}';
    } catch (_) {
      return 'لا يوجد نشاط بعد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final morningColor = isDark ? Colors.orangeAccent : const Color(0xFFC15F00);
    final eveningColor = isDark ? Colors.cyanAccent : const Color(0xFF007C89);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ورد اليوم'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => setState(() => _summaryFuture = _loadSummary()),
          ),
        ],
      ),
      body: FutureBuilder<_TodaySummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          final summary = snapshot.data ?? _TodaySummary.empty();
          final tasbihProgress =
              (summary.dailyTasbih / summary.dailyTasbihTarget)
                  .clamp(0.0, 1.0)
                  .toDouble();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _summaryFuture = _loadSummary());
              await _summaryFuture;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              children: [
                _HeroPanel(
                  streak: summary.streak,
                  openAzkar: widget.openAzkar,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressCard(
                        title: 'أذكار الصباح',
                        value: summary.morningProgress,
                        icon: Icons.wb_sunny_outlined,
                        color: morningColor,
                        onTap: widget.openAzkar,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProgressCard(
                        title: 'أذكار المساء',
                        value: summary.eveningProgress,
                        icon: Icons.nights_stay_outlined,
                        color: eveningColor,
                        onTap: widget.openAzkar,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TasbihGoalCard(
                  count: summary.dailyTasbih,
                  total: summary.totalTasbih,
                  target: summary.dailyTasbihTarget,
                  progress: tasbihProgress,
                  onTap: widget.openTasbih,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _InfoStrip(
                  icon: Icons.history,
                  title: 'آخر نشاط',
                  value: summary.lastLog,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _InfoStrip(
                  icon: Icons.notifications_active_outlined,
                  title: 'التذكيرات',
                  value: 'اضبط مواعيد الصباح والمساء من الإعدادات',
                  onTap: widget.openSettings,
                  isDark: isDark,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final int streak;
  final VoidCallback openAzkar;
  final bool isDark;

  const _HeroPanel({
    required this.streak,
    required this.openAzkar,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [const Color(0xFF171717), const Color(0xFF090909)]
              : [Colors.white, const Color(0xFFEAF7FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.amber : const Color(0xFFB7791F))
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: isDark ? Colors.amber : const Color(0xFFB7791F),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ابدأ وردك بهدوء',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      streak == 0
                          ? 'أول خطوة اليوم تكفي'
                          : '$streak يوم متتالي',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: openAzkar,
              icon: const Icon(Icons.play_arrow),
              label: const Text('ابدأ وردك'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.cyanAccent
                    : const Color(0xFF007C89),
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ProgressCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.22 : 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: value,
              minHeight: 7,
              color: color,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasbihGoalCard extends StatelessWidget {
  final int count;
  final int total;
  final int target;
  final double progress;
  final VoidCallback onTap;
  final bool isDark;

  const _TasbihGoalCard({
    required this.count,
    required this.total,
    required this.target,
    required this.progress,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Icon(Icons.fingerprint, color: accent),
                const Spacer(),
                const Text(
                  'هدف التسبيح اليومي',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: accent,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الإجمالي: $total'),
                Text(
                  '$count / $target',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool isDark;

  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? Colors.amberAccent : const Color(0xFFB7791F);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySummary {
  final double morningProgress;
  final double eveningProgress;
  final int dailyTasbih;
  final int totalTasbih;
  final int dailyTasbihTarget;
  final int streak;
  final String lastLog;

  const _TodaySummary({
    required this.morningProgress,
    required this.eveningProgress,
    required this.dailyTasbih,
    required this.totalTasbih,
    required this.dailyTasbihTarget,
    required this.streak,
    required this.lastLog,
  });

  factory _TodaySummary.empty() {
    return const _TodaySummary(
      morningProgress: 0,
      eveningProgress: 0,
      dailyTasbih: 0,
      totalTasbih: 0,
      dailyTasbihTarget: 1000,
      streak: 0,
      lastLog: 'لا يوجد نشاط بعد',
    );
  }
}
