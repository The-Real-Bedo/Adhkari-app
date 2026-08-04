import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/quran_audio_handler.dart';
import '../../services/quran_audio_service.dart';

/// شاشة المشغل الكاملة.
///
/// كل الواجهة بتقرأ من playbackState / mediaItem مباشرة (StreamBuilder)
/// عشان تفضل متزامنة لو المستخدم غيّر الحالة من الإشعار أو شاشة القفل.
class QuranPlayerScreen extends StatefulWidget {
  final Reciter? reciter;
  final Moshaf? moshaf;
  final List<Surah> allSuwar;
  final int? startSurahId;

  /// نكمل من موضع محفوظ (بيتستخدم مع الاستكمال بعد قفل التطبيق)
  final Duration startPosition;

  const QuranPlayerScreen({
    super.key,
    required Reciter this.reciter,
    required Moshaf this.moshaf,
    required this.allSuwar,
    required int this.startSurahId,
    this.startPosition = Duration.zero,
  });

  /// فتح المشغل على التلاوة الشغالة حاليًا من غير إعادة تحميل —
  /// بيستخدمها الشريط المصغر لما المستخدم يدوس عليه
  const QuranPlayerScreen.current({super.key})
    : reciter = null,
      moshaf = null,
      allSuwar = const [],
      startSurahId = null,
      startPosition = Duration.zero;

  @override
  State<QuranPlayerScreen> createState() => _QuranPlayerScreenState();
}

class _QuranPlayerScreenState extends State<QuranPlayerScreen> {
  QuranAudioHandler get _handler => QuranAudioService.handler;

  String? _loadError;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // لو تهيئة الخدمة فشلت في main() الـ getter بيرمي StateError.
    // بنتأكد الأول عشان الشاشة تعرض رسالة بدل ما الـ build يقع.
    if (!QuranAudioService.isReady) {
      setState(() {
        _starting = false;
        _loadError = 'مشغل الصوت مش جاهز، اقفل التطبيق وافتحه تاني';
      });
      return;
    }

    // وضع "التلاوة الحالية" — الشريط المصغر فتحنا، مفيش حاجة نحمّلها
    final reciter = widget.reciter;
    final moshaf = widget.moshaf;
    final startSurahId = widget.startSurahId;

    if (reciter == null || moshaf == null || startSurahId == null) {
      setState(() => _starting = false);
      return;
    }

    try {
      // لو نفس القارئ والرواية والسورة شغالين بالفعل، مانعملش reload.
      // بنقارن بالرواية كمان مش بالقارئ بس — القارئ الواحد ممكن يكون
      // عنده أكتر من رواية، ولو قارنا بالاسم بس المستخدم يختار رواية
      // تانية ويفضل يسمع الأولى من غير ما ياخد باله.
      final current = _handler.mediaItem.value;
      final currentSurah = current?.extras?['surahId'] as int?;
      final currentMoshaf = current?.extras?['moshafId'] as int?;
      final sameTrack =
          currentSurah == startSurahId && currentMoshaf == moshaf.id;

      if (!sameTrack) {
        await _handler.loadReciter(
          reciterId: reciter.id,
          reciterName: reciter.name,
          moshaf: moshaf,
          allSuwar: widget.allSuwar,
          startSurahId: startSurahId,
          startPosition: widget.startPosition,
        );
      }

      if (!mounted) return;
      setState(() => _starting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _loadError = 'تعذر تشغيل التلاوة، تأكد من الاتصال بالإنترنت';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF00838F);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الاستماع'),
          centerTitle: true,
        ),
        body: _loadError != null
            ? _buildError(accent)
            : StreamBuilder<MediaItem?>(
                stream: _handler.mediaItem,
                builder: (context, snapshot) {
                  final item = snapshot.data;
                  if (_starting && item == null) {
                    return Center(
                      child: CircularProgressIndicator(color: accent),
                    );
                  }
                  return _buildPlayer(item, isDark, accent);
                },
              ),
      ),
    );
  }

  Widget _buildError(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loadError = null;
                  _starting = true;
                });
                _start();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(MediaItem? item, bool isDark, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // دائرة فيها أيقونة — بديل بسيط عن صورة الغلاف
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(Icons.menu_book, size: 80, color: accent),
          ),
          const SizedBox(height: 28),

          Text(
            item?.title ?? '—',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            item?.artist ?? widget.reciter?.name ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _SeekBar(handler: _handler, accent: accent, duration: item?.duration),
          const SizedBox(height: 8),

          // شريط أوضاع التكرار والعشوائي ومؤقت النوم
          _ModeBar(handler: _handler, accent: accent),
          const SizedBox(height: 4),

          // أزرار التحكم بتتبني من playbackState عشان تتزامن مع الإشعار
          StreamBuilder<PlaybackState>(
            stream: _handler.playbackState,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final playing = state?.playing ?? false;
              final processing = state?.processingState;
              final isBusy =
                  processing == AudioProcessingState.loading ||
                  processing == AudioProcessingState.buffering;

              final index = state?.queueIndex ?? 0;
              final total = _handler.queue.value.length;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 38,
                    icon: const Icon(Icons.skip_previous),
                    // في RTL الترتيب بيتقلب بصريًا، لكن السابق يفضل سابق
                    onPressed: index > 0
                        ? () => _handler.skipToPrevious()
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                    child: isBusy
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          )
                        : IconButton(
                            iconSize: 44,
                            color: isDark ? Colors.black : Colors.white,
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                            onPressed: () =>
                                playing ? _handler.pause() : _handler.play(),
                          ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    iconSize: 38,
                    icon: const Icon(Icons.skip_next),
                    onPressed: index < total - 1
                        ? () => _handler.skipToNext()
                        : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// شريط التكرار والعشوائي ومؤقت النوم
class _ModeBar extends StatelessWidget {
  final QuranAudioHandler handler;
  final Color accent;

  const _ModeBar({required this.handler, required this.accent});

  @override
  Widget build(BuildContext context) {
    // بنعيد البناء مع أي تغيير في الأوضاع أو المؤقت
    return StreamBuilder<void>(
      stream: handler.modeStream,
      builder: (context, _) {
        return StreamBuilder<Duration?>(
          stream: handler.sleepRemainingStream,
          builder: (context, sleepSnapshot) {
            final remaining = sleepSnapshot.data;
            final sleepOn = handler.sleepTimerActive;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // التكرار
                _ModeButton(
                  icon: switch (handler.repeatMode) {
                    QuranRepeatMode.one => Icons.repeat_one,
                    QuranRepeatMode.count => Icons.repeat_on_outlined,
                    QuranRepeatMode.all => Icons.repeat_on,
                    QuranRepeatMode.off => Icons.repeat,
                  },
                  label: switch (handler.repeatMode) {
                    QuranRepeatMode.one => 'تكرار السورة',
                    QuranRepeatMode.all => 'تكرار الكل',
                    QuranRepeatMode.count => '${handler.repeatTarget}× مرات',
                    QuranRepeatMode.off => 'بدون تكرار',
                  },
                  active: handler.repeatMode != QuranRepeatMode.off,
                  accent: accent,
                  onTap: () => _pickRepeatMode(context),
                ),

                // العشوائي
                _ModeButton(
                  icon: Icons.shuffle,
                  label: 'عشوائي',
                  active: handler.shuffleEnabled,
                  accent: accent,
                  onTap: () => handler.setShuffle(!handler.shuffleEnabled),
                ),

                // مؤقت النوم
                _ModeButton(
                  icon: Icons.bedtime_outlined,
                  label: remaining != null
                      ? _formatRemaining(remaining)
                      : handler.sleepAtEndOfSurah
                      ? 'آخر السورة'
                      : 'مؤقت النوم',
                  active: sleepOn,
                  accent: accent,
                  onTap: () => _pickSleepTimer(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _pickRepeatMode(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'وضع التكرار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('بدون تكرار'),
                selected: handler.repeatMode == QuranRepeatMode.off,
                onTap: () {
                  handler.setQuranRepeatMode(QuranRepeatMode.off);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.repeat_one),
                title: const Text('تكرار السورة الحالية'),
                subtitle: const Text('مفيد في الحفظ'),
                selected: handler.repeatMode == QuranRepeatMode.one,
                onTap: () {
                  handler.setQuranRepeatMode(QuranRepeatMode.one);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.repeat_on),
                title: const Text('تكرار كل السور'),
                subtitle: const Text('بعد آخر سورة يرجع لأولها'),
                selected: handler.repeatMode == QuranRepeatMode.all,
                onTap: () {
                  handler.setQuranRepeatMode(QuranRepeatMode.all);
                  Navigator.pop(sheetContext);
                },
              ),
              const Divider(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'كرر السورة عدد مرات محدد',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  children: [3, 5, 7, 10].map((times) {
                    final selected =
                        handler.repeatMode == QuranRepeatMode.count &&
                        handler.repeatTarget == times;
                    return ChoiceChip(
                      label: Text('$times مرات'),
                      selected: selected,
                      selectedColor: accent.withValues(alpha: 0.3),
                      onSelected: (_) {
                        handler.setQuranRepeatMode(
                          QuranRepeatMode.count,
                          times: times,
                        );
                        Navigator.pop(sheetContext);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSleepTimer(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'مؤقت النوم',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 10, 15, 30, 45, 60].map((minutes) {
                    return ActionChip(
                      label: Text('$minutes دقيقة'),
                      onPressed: () {
                        handler.startSleepTimer(Duration(minutes: minutes));
                        Navigator.pop(sheetContext);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('بعد نهاية السورة الحالية'),
                onTap: () {
                  handler.sleepAfterCurrentSurah();
                  Navigator.pop(sheetContext);
                },
              ),
              if (handler.sleepTimerActive)
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.redAccent),
                  title: const Text(
                    'إلغاء المؤقت',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    handler.cancelSleepTimer();
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

/// شريط التقدم — بيقرأ الموضع من المشغل ويسمح بالسحب
class _SeekBar extends StatefulWidget {
  final QuranAudioHandler handler;
  final Color accent;
  final Duration? duration;

  const _SeekBar({
    required this.handler,
    required this.accent,
    required this.duration,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  /// أثناء السحب بنستخدم القيمة المؤقتة دي بدل الموضع الحقيقي
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final total = widget.duration ?? Duration.zero;

    return StreamBuilder<Duration>(
      stream: widget.handler.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final maxMs = total.inMilliseconds.toDouble();
        final currentMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                ),
                activeTrackColor: widget.accent,
                thumbColor: widget.accent,
              ),
              child: Slider(
                min: 0,
                // لو المدة لسه مش معروفة نحمي الـ Slider من max = 0
                max: maxMs > 0 ? maxMs : 1,
                value: _dragValue ?? currentMs,
                onChanged: maxMs > 0
                    ? (value) => setState(() => _dragValue = value)
                    : null,
                onChangeEnd: maxMs > 0
                    ? (value) {
                        widget.handler.seek(
                          Duration(milliseconds: value.round()),
                        );
                        setState(() => _dragValue = null);
                      }
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _format(position),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _format(total),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
