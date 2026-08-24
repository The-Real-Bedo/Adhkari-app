import 'package:flutter/material.dart';

import '../services/habit_tracker_service.dart';
import '../theme/app_theme.dart';

/// شاشة "رحلتي مع الأذكار" — إحصائيات العادات وشبكة النشاط اليومي (Heatmap)
class HabitInsightsScreen extends StatefulWidget {
  const HabitInsightsScreen({super.key});

  @override
  State<HabitInsightsScreen> createState() => _HabitInsightsScreenState();
}

class _HabitInsightsScreenState extends State<HabitInsightsScreen> {
  int _bestStreak = 0;
  DailyActivity? _selectedActivity;

  @override
  void initState() {
    super.initState();
    _loadBestStreak();
  }

  Future<void> _loadBestStreak() async {
    final best = await HabitTrackerService.getBestStreak();
    if (mounted) setState(() => _bestStreak = best);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currentStreak = HabitTrackerService.calculateStreak();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          title: const Text('رحلتي مع الأذكار'),
        ),
        body: ValueListenableBuilder<Map<String, DailyActivity>>(
          valueListenable: HabitTrackerService.activityNotifier,
          builder: (context, activityMap, _) {
            int totalTasbih = 0;
            int totalPages = 0;
            int morningCount = 0;
            int eveningCount = 0;

            for (final act in activityMap.values) {
              totalTasbih += act.tasbihCount;
              totalPages += act.quranPages;
              if (act.morningDone) morningCount++;
              if (act.eveningDone) eveningCount++;
            }

            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // لوحة السلسلة الحالية (Streak Panel)
                _buildStreakHero(p, currentStreak, _bestStreak),

                const SizedBox(height: 20),

                // شبكة النشاط (Heatmap)
                _buildHeatmapSection(p, activityMap),

                const SizedBox(height: 20),

                // بطاقة تفاصيل اليوم المحدد (عند الضغط على مربع)
                if (_selectedActivity != null) ...[
                  _buildDayDetailCard(p, _selectedActivity!),
                  const SizedBox(height: 20),
                ],

                // الإحصائيات التراكمية
                Text(
                  'المسيرة الروحانية',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        p,
                        icon: Icons.wb_sunny_outlined,
                        title: 'أذكار الصباح',
                        value: '$morningCount مرة',
                        color: p.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        p,
                        icon: Icons.nights_stay_outlined,
                        title: 'أذكار المساء',
                        value: '$eveningCount مرة',
                        color: p.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        p,
                        icon: Icons.fingerprint,
                        title: 'مجموع التسبيح',
                        value: '$totalTasbih',
                        color: p.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        p,
                        icon: Icons.auto_stories,
                        title: 'صفحات القرآن',
                        value: '$totalPages ص',
                        color: p.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // رسالة تشجيعية
                _buildInspirationCard(p),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStreakHero(AppPalette p, int currentStreak, int bestStreak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department,
              color: p.accent,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$currentStreak يوم متتالي',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أفضل سلسلة مستمرة: $bestStreak يوم 🏆',
                  style: TextStyle(fontSize: 13, color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapSection(
    AppPalette p,
    Map<String, DailyActivity> activityMap,
  ) {
    final days = HabitTrackerService.getHeatmapDays(weeks: 14);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'شبكة النشاط اليومي',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                ),
              ),
              _buildHeatmapLegend(p),
            ],
          ),
          const SizedBox(height: 14),

          // شبكة المربعات أفقية التمرير
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // RTL scrolling
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(14, (weekIndex) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Column(
                    children: List.generate(7, (dayIndex) {
                      final itemIndex = weekIndex * 7 + dayIndex;
                      if (itemIndex >= days.length) {
                        return const SizedBox.shrink();
                      }
                      final date = days[itemIndex];
                      final dateKey = date.toString().split(' ')[0];
                      final act = activityMap[dateKey] ??
                          DailyActivity(date: dateKey);
                      final intensity = act.intensity;

                      final isSelected =
                          _selectedActivity?.date == dateKey;

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedActivity = act);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 2.5),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _colorForIntensity(p, intensity),
                            borderRadius: BorderRadius.circular(4),
                            border: isSelected
                                ? Border.all(color: p.accent, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForIntensity(AppPalette p, int intensity) {
    switch (intensity) {
      case 1:
        return p.primarySoft;
      case 2:
        return p.primary.withValues(alpha: 0.55);
      case 3:
        return p.primary.withValues(alpha: 0.85);
      case 4:
        return p.primary;
      default:
        return p.surfaceAlt;
    }
  }

  Widget _buildHeatmapLegend(AppPalette p) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        children: [
          Text('أقل', style: TextStyle(fontSize: 10, color: p.textMuted)),
          const SizedBox(width: 4),
          for (int i = 0; i <= 4; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: _colorForIntensity(p, i),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(width: 4),
          Text('أكثر', style: TextStyle(fontSize: 10, color: p.textMuted)),
        ],
      ),
    );
  }

  Widget _buildDayDetailCard(AppPalette p, DailyActivity act) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'إنجاز يوم: ${act.date}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: p.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _selectedActivity = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _detailChip(
                p,
                label: 'أذكار الصباح: ${act.morningDone ? "مكتملة ✅" : "لم تكتمل ⚪"}',
              ),
              _detailChip(
                p,
                label: 'أذكار المساء: ${act.eveningDone ? "مكتملة ✅" : "لم تكتمل ⚪"}',
              ),
              _detailChip(
                p,
                label: 'التسبيحات: ${act.tasbihCount}',
              ),
              _detailChip(
                p,
                label: 'صفحات القرآن: ${act.quranPages}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailChip(AppPalette p, {required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, color: p.text),
      ),
    );
  }

  Widget _buildStatCard(
    AppPalette p, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11.5, color: p.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspirationCard(AppPalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: p.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '«أَحَبُّ الأَعْمَالِ إِلَى اللهِ أَدْوَمُهَا وَإِنْ قَلَّ» — داوم على وردك وإن كان يسيراً.',
              style: TextStyle(
                fontSize: 12.5,
                color: p.text,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
