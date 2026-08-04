import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/azkar_data.dart';
import '../models/zikr_model.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_prefs.dart';
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
              // آخر تلاوة ممكن تكون اتغيرت وهو بيسمع في تبويب تاني
              await _loadLastPlayed();
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

                // كارت متابعة الاستماع — بيتفرج على الهاندلر مباشرة زي
                // الشريط المصغر، فلو التلاوة شغالة الاتنين بيتحركوا مع بعض.
                // ولو مفيش حاجة شغالة بيرجع لآخر تلاوة محفوظة.
                _ResumeListeningCard(
                  fallback: _lastPlayed,
                  onOpenTab: widget.openQuran,
                  isDark: isDark,
                ),

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

  final bool isDark;

  const _ResumeListeningCard({
    required this.fallback,
    required this.onOpenTab,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // لو الخدمة فشلت في main مفيش هاندلر نتفرج عليه
    if (!QuranAudioService.isReady) return _fallbackCard();

    final handler = QuranAudioService.handler;

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, itemSnapshot) {
        final item = itemSnapshot.data;
        if (item == null) return _fallbackCard();

        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final processing = state?.processingState;

            // وقف خالص؟ نرجع للمحفوظ، بنفس شرط اختفاء الشريط المصغر
            if (processing == AudioProcessingState.idle) {
              return _fallbackCard();
            }

            final playing = state?.playing ?? false;
            final busy =
                processing == AudioProcessingState.loading ||
                processing == AudioProcessingState.buffering;

            return StreamBuilder<Duration>(
              stream: handler.positionStream,
              builder: (context, posSnapshot) {
                return _card(
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
  Widget _fallbackCard() {
    final last = fallback;
    if (last == null) return const SizedBox.shrink();

    return _card(
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
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF00838F);

    // بنحسب النسبة هنا مش من LastPlayed.progress عشان نفس الحساب
    // يخدم الحالتين: الشغالة دلوقتي والمحفوظة.
    // toDouble ضرورية لأن clamp بترجع num مش double.
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble()
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // في وضع التشغيل الزرار ده بيتحكم في الهاندلر نفسه،
                      // فبيتغير مع الشريط المصغر والإشعار في نفس اللحظة
                      _LeadingControl(
                        accent: accent,
                        live: live,
                        playing: playing,
                        busy: busy,
                        onToggle: onToggle,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              live ? 'بتسمع دلوقتي' : 'تابع الاستماع',
                              style: TextStyle(
                                fontSize: 12,
                                color: accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // شريط التقدم بيظهر بس لو عارفين مدة السورة
                  if (duration.inMilliseconds > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.grey.withValues(alpha: 0.25),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fmt(position)} / ${_fmt(duration)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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
  final Color accent;
  final bool live;
  final bool playing;
  final bool busy;
  final VoidCallback onToggle;

  const _LeadingControl({
    required this.accent,
    required this.live,
    required this.playing,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: accent,
              ),
            )
          : Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: accent,
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
