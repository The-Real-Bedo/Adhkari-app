import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/azkar_data.dart';
import '../data/islamic_events.dart';
import '../models/zikr_model.dart';
import '../services/hijri_prefs.dart';
import '../services/home_widget_service.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/hijri_date.dart';
import 'habit_insights_screen.dart';
import '../widgets/audio_visuals.dart';
import '../widgets/hijri_date_card.dart';
import '../widgets/khatmah_card.dart';
import '../widgets/prayer_times_card.dart';
import 'quran/quran_player_screen.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback openTasbih;
  final VoidCallback openAzkar;
  final VoidCallback openSettings;

  /// بيفتح تبويب القرآن — بيستخدمه كارت "تابع الاستماع"
  final VoidCallback openQuran;

  const TodayScreen({
    super.key,
    required this.openTasbih,
    required this.openAzkar,
    required this.openSettings,
    required this.openQuran,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<_TodaySummary> _summaryFuture;

  /// آخر تلاوة كان بيسمعها — بنعرضها في كارت "تابع الاستماع"
  LastPlayed? _lastPlayed;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
    _loadLastPlayed();
  }

  Future<void> _loadLastPlayed() async {
    final last = await QuranPrefs.lastPlayed();
    if (!mounted) return;
    setState(() => _lastPlayed = last);
  }

  Future<_TodaySummary> _loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDailyTarget = prefs.getInt('dailyTasbihTarget') ?? 1000;
    HomeWidgetService.updateAll();

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
    final p = context.palette;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ورد اليوم'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'رحلتي مع الأذكار والإحصائيات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitInsightsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => setState(() {
              _summaryFuture = _loadSummary();
            }),
          ),
        ],
      ),
      body: FutureBuilder<_TodaySummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = snapshot.data ?? _TodaySummary.empty();
          final tasbihProgress =
              (summary.dailyTasbih / summary.dailyTasbihTarget)
                  .clamp(0.0, 1.0)
                  .toDouble();

          return RefreshIndicator(
            onRefresh: () async {
              // نفس سبب الأقواس المعقوفة اللي فوق: مانرجّعش Future من
              // جوّه setState.
              setState(() {
                _summaryFuture = _loadSummary();
              });
              await _summaryFuture;
              // آخر تلاوة ممكن تكون اتغيرت وهو بيسمع في تبويب تاني
              await _loadLastPlayed();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              children: [
                _HeroPanel(
                  streak: summary.streak,
                  openAzkar: widget.openAzkar,
                ),
                const SizedBox(height: 16),

                // التاريخ الهجري بيتحسب جوّه الـ builder — حساب صحيح خالص
                // من غير I/O، فمفيش داعي يعدّي على _TodaySummary. الـ
                // ValueListenableBuilder هو اللي بيخلي الكارت يتحدّث لحظياً
                // لما الإزاحة تتغيّر من شاشة الإعدادات، من غير ما نستنى
                // الشاشة دي تتبني من الأول.
                ValueListenableBuilder<int>(
                  valueListenable: HijriPrefs.offsetNotifier,
                  builder: (context, offset, _) {
                    final now = DateTime.now();
                    final hijri = HijriDate.fromGregorian(now, offset: offset);
                    final upcoming = nextEvent(hijri);
                    return HijriDateCard(
                      hijri: hijri,
                      gregorian: now,
                      nextEvent: upcoming.event,
                      daysRemaining: upcoming.daysRemaining,
                      dayInEvent: upcoming.dayInEvent,
                      onTap: widget.openSettings,
                    );
                  },
                ),

                const SizedBox(height: 12),
                const PrayerTimesCard(),
                const SizedBox(height: 12),

                // كارت متابعة الاستماع — بيتفرج على الهاندلر مباشرة زي
                // الشريط المصغر، فلو التلاوة شغالة الاتنين بيتحركوا مع بعض.
                // ولو مفيش حاجة شغالة بيرجع لآخر تلاوة محفوظة.
                _ResumeListeningCard(
                  fallback: _lastPlayed,
                  onOpenTab: widget.openQuran,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _ProgressCard(
                        title: 'أذكار الصباح',
                        value: summary.morningProgress,
                        icon: Icons.wb_sunny_outlined,
                        color: p.accent,
                        onTap: widget.openAzkar,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProgressCard(
                        title: 'أذكار المساء',
                        value: summary.eveningProgress,
                        icon: Icons.nights_stay_outlined,
                        color: p.primary,
                        onTap: widget.openAzkar,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const KhatmahCard(),
                const SizedBox(height: 12),
                _TasbihGoalCard(
                  count: summary.dailyTasbih,
                  total: summary.totalTasbih,
                  target: summary.dailyTasbihTarget,
                  progress: tasbihProgress,
                  onTap: widget.openTasbih,
                ),
                const SizedBox(height: 12),
                _InfoStrip(
                  icon: Icons.history,
                  title: 'آخر نشاط',
                  value: summary.lastLog,
                ),
                const SizedBox(height: 12),
                _InfoStrip(
                  icon: Icons.notifications_active_outlined,
                  title: 'التذكيرات',
                  value: 'اضبط مواعيد الصباح والمساء من الإعدادات',
                  onTap: widget.openSettings,
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

  const _HeroPanel({
    required this.streak,
    required this.openAzkar,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [p.surface, p.surfaceAlt],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: p.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ابدأ وردك بهدوء',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HabitInsightsScreen(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            streak == 0
                                ? 'أول خطوة اليوم تكفي'
                                : '$streak يوم متتالي 🔥',
                            style: TextStyle(
                              color: streak > 0 ? p.accent : p.textMuted,
                              fontWeight: streak > 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_left, size: 16, color: p.textMuted),
                        ],
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
            child: FilledButton.icon(
              onPressed: openAzkar,
              icon: const Icon(Icons.play_arrow),
              label: const Text('ابدأ وردك'),
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
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

  const _ProgressCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final percentage = (value * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: p.text)),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: value,
              minHeight: 7,
              color: color,
              backgroundColor: p.border,
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

  const _TasbihGoalCard({
    required this.count,
    required this.total,
    required this.target,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fingerprint, color: p.primary),
                const SizedBox(width: 10),
                Text(
                  'هدف التسبيح اليومي',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: p.text),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: p.primary,
              backgroundColor: p.border,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الإجمالي: $total', style: TextStyle(color: p.text)),
                Text(
                  '$count / $target',
                  style: TextStyle(
                    color: p.primary,
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

  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: p.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: p.text),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textMuted),
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

/// كارت متابعة الاستماع.
///
/// بياخد حالته من الهاندلر مباشرة — نفس المصدر اللي الشريط المصغر بيقرا
/// منه — عشان الاتنين يمشوا مع بعض: لو وقفت من الشريط الكارت بيوقف، ولو
/// دوست تشغيل من الكارت الشريط بيتحرك، والوقت بيتحرك في الاتنين. قبل كده
/// الكارت كان بيقرا لقطة محفوظة مرة واحدة في initState فكان بيفضل ثابت.
///
/// لو مفيش تلاوة محمّلة في الهاندلر خالص بنرجع لآخر تلاوة محفوظة.
class _ResumeListeningCard extends StatelessWidget {
  /// آخر تلاوة محفوظة — للحالة اللي مفيش فيها تشغيل دلوقتي
  final LastPlayed? fallback;

  /// بيفتح تبويب القرآن. بنستخدمه في الحالة المحفوظة لأن بدء التشغيل
  /// محتاج بيانات القارئ والرواية، والتبويب هو اللي بيجيبها ويكمّل.
  final VoidCallback onOpenTab;

  const _ResumeListeningCard({
    required this.fallback,
    required this.onOpenTab,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // التهيئة بتحصل بعد أول frame، فبنسمع للـ notifier عشان الكارت يتحدّث
    // لما المشغّل يبقى جاهز بدل ما يفضل على النسخة البديلة.
    return ValueListenableBuilder<bool>(
      valueListenable: QuranAudioService.readyNotifier,
      builder: (context, ready, _) {
        if (!ready) return _fallbackCard(p);
        return _buildLiveCard(context, p);
      },
    );
  }

  Widget _buildLiveCard(BuildContext context, AppPalette p) {
    final handler = QuranAudioService.handler;

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, itemSnapshot) {
        final item = itemSnapshot.data;
        if (item == null) return _fallbackCard(p);

        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final processing = state?.processingState;

            // وقف خالص؟ نرجع للمحفوظ، بنفس شرط اختفاء الشريط المصغر
            if (processing == AudioProcessingState.idle) {
              return _fallbackCard(p);
            }

            final playing = state?.playing ?? false;
            final busy =
                processing == AudioProcessingState.loading ||
                processing == AudioProcessingState.buffering;

            return StreamBuilder<Duration>(
              stream: handler.positionStream,
              builder: (context, posSnapshot) {
                return _card(
                  p: p,
                  title: item.title,
                  subtitle: item.album ?? '',
                  position: posSnapshot.data ?? Duration.zero,
                  duration: item.duration ?? Duration.zero,
                  live: true,
                  playing: playing,
                  busy: busy,
                  // الضغطة بتفتح المشغل الكامل على نفس التلاوة الشغالة
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QuranPlayerScreen.current(),
                    ),
                  ),
                  onToggle: () => playing ? handler.pause() : handler.play(),
                );
              },
            );
          },
        );
      },
    );
  }

  /// الحالة المحفوظة — مفيش تلاوة محمّلة في الهاندلر دلوقتي
  Widget _fallbackCard(AppPalette p) {
    final last = fallback;
    if (last == null) return const SizedBox.shrink();

    return _card(
      p: p,
      title: last.surahTitle,
      subtitle: last.reciterName,
      position: last.position,
      duration: last.duration,
      live: false,
      playing: false,
      busy: false,
      onTap: onOpenTab,
      onToggle: onOpenTab,
    );
  }

  Widget _card({
    required AppPalette p,
    required String title,
    required String subtitle,
    required Duration position,
    required Duration duration,
    required bool live,
    required bool playing,
    required bool busy,
    required VoidCallback onTap,
    required VoidCallback onToggle,
  }) {
    // بنحسب النسبة هنا مش من LastPlayed.progress عشان نفس الحساب
    // يخدم الحالتين: الشغالة دلوقتي والمحفوظة.
    // toDouble ضرورية لأن clamp بترجع num مش double.
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble()
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: p.border),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // في وضع التشغيل الزرار ده بيتحكم في الهاندلر نفسه،
                      // فبيتغير مع الشريط المصغر والإشعار في نفس اللحظة
                      _LeadingControl(
                        live: live,
                        playing: playing,
                        busy: busy,
                        onToggle: onToggle,
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  live ? 'بتسمع دلوقتي' : 'تابع الاستماع',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (live && playing) ...[
                                  const SizedBox(width: 8),
                                  EqualizerBars(
                                    playing: true,
                                    color: p.primary,
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: p.text,
                              ),
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // شريط التقدم بيظهر بس لو عارفين مدة السورة. الموجة
                  // بتتحرك وقت التشغيل الفعلي بس — في الوضع المحفوظ
                  // بتبقى خط مستقيم عشان مايبانش إن فيه حاجة شغالة.
                  if (duration.inMilliseconds > 0) ...[
                    const SizedBox(height: AppSpace.sm),
                    WaveProgressBar(
                      progress: progress,
                      playing: live && playing,
                      color: p.primary,
                      backgroundColor: p.border,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      '${_fmt(position)} / ${_fmt(duration)}',
                      style: TextStyle(fontSize: 11, color: p.textFaint),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// الدايرة اللي على يمين كارت الاستماع.
///
/// في وضع التشغيل بتبقى زرار تشغيل/إيقاف حقيقي بيتحكم في نفس الهاندلر
/// بتاع الشريط المصغر، عشان أي ضغطة في الاتنين تبان في التاني على طول.
/// في الوضع المحفوظ بتبقى مجرد أيقونة بتودّي على تبويب القرآن.
class _LeadingControl extends StatelessWidget {
  final bool live;
  final bool playing;
  final bool busy;
  final VoidCallback onToggle;

  const _LeadingControl({
    required this.live,
    required this.playing,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final circle = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.primarySoft,
        shape: BoxShape.circle,
      ),
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: p.primary,
              ),
            )
          : Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: p.primary,
              size: 24,
            ),
    );

    // وهو بيحمّل مبنخليهوش يضغط، عشان مايبعتش أوامر متضاربة للهاندلر
    if (!live || busy) return circle;

    return InkWell(
      onTap: onToggle,
      customBorder: const CircleBorder(),
      child: circle,
    );
  }
}
