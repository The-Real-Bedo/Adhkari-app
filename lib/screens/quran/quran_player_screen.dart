import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../services/quran_audio_handler.dart';
import '../../services/quran_audio_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/audio_visuals.dart';

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
    final p = context.palette;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الاستماع')),
        body: _loadError != null
            ? _buildError(p)
            : StreamBuilder<MediaItem?>(
                stream: _handler.mediaItem,
                builder: (context, snapshot) {
                  final item = snapshot.data;
                  if (_starting && item == null) {
                    return Center(
                      child: CircularProgressIndicator(color: p.primary),
                    );
                  }
                  return _buildPlayer(item, p);
                },
              ),
      ),
    );
  }

  Widget _buildError(AppPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: p.danger),
            const SizedBox(height: AppSpace.lg),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: context.type.bodyLarge,
            ),
            const SizedBox(height: AppSpace.xl),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _loadError = null;
                  _starting = true;
                });
                _start();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(MediaItem? item, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // دائرة فيها أيقونة — بديل بسيط عن صورة الغلاف. الهالة حواليها
          // بتنبض طول ما التلاوة شغالة وبتتلاشى مع الإيقاف.
          StreamBuilder<PlaybackState>(
            stream: _handler.playbackState,
            builder: (context, snapshot) => AudioPulse(
              playing: snapshot.data?.playing ?? false,
              size: 180,
              color: p.primary,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.primarySoft,
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Icon(Icons.menu_book, size: 76, color: p.primary),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // اسم السورة بخط أميري — نص قرآني
          Text(
            item?.title ?? '—',
            textAlign: TextAlign.center,
            style: QuranTextStyle.amiri(color: p.text, fontSize: 26),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            item?.artist ?? widget.reciter?.name ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.textMuted),
          ),
          const SizedBox(height: AppSpace.xl),

          _SeekBar(handler: _handler, palette: p, duration: item?.duration),
          const SizedBox(height: AppSpace.sm),

          // شريط أوضاع التكرار والعشوائي ومؤقت النوم
          _ModeBar(handler: _handler, palette: p),
          const SizedBox(height: AppSpace.xs),

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
                    iconSize: 34,
                    color: p.text,
                    disabledColor: p.textFaint,
                    icon: const Icon(Icons.skip_previous),
                    // في RTL الترتيب بيتقلب بصريًا، لكن السابق يفضل سابق
                    onPressed: index > 0
                        ? () => _handler.skipToPrevious()
                        : null,
                  ),
                  const SizedBox(width: AppSpace.lg),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.primary,
                    ),
                    child: isBusy
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpace.lg),
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: p.onPrimary,
                              ),
                            ),
                          )
                        : IconButton(
                            iconSize: 44,
                            color: p.onPrimary,
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                            onPressed: () =>
                                playing ? _handler.pause() : _handler.play(),
                          ),
                  ),
                  const SizedBox(width: AppSpace.lg),
                  IconButton(
                    iconSize: 34,
                    color: p.text,
                    disabledColor: p.textFaint,
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
  final AppPalette palette;

  const _ModeBar({required this.handler, required this.palette});

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
                  palette: palette,
                  onTap: () => _pickRepeatMode(context),
                ),

                // العشوائي
                _ModeButton(
                  icon: Icons.shuffle,
                  label: 'عشوائي',
                  active: handler.shuffleEnabled,
                  palette: palette,
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
                  palette: palette,
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

  /// عنوان الدرج السفلي — نفس الشكل في التكرار والمؤقت
  Widget _sheetTitle(String text) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: palette.text,
        ),
      ),
    );
  }

  Future<void> _pickRepeatMode(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetTitle('وضع التكرار'),
              ListTile(
                leading: Icon(Icons.repeat, color: palette.textMuted),
                title: const Text('بدون تكرار'),
                selected: handler.repeatMode == QuranRepeatMode.off,
                selectedColor: palette.primary,
                onTap: () {
                  handler.setQuranRepeatMode(QuranRepeatMode.off);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: Icon(Icons.repeat_one, color: palette.textMuted),
                title: const Text('تكرار السورة الحالية'),
                subtitle: Text(
                  'مفيد في الحفظ',
                  style: TextStyle(color: palette.textMuted),
                ),
                selected: handler.repeatMode == QuranRepeatMode.one,
                selectedColor: palette.primary,
                onTap: () {
                  handler.setQuranRepeatMode(QuranRepeatMode.one);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: Icon(Icons.repeat_on, color: palette.textMuted),
                title: const Text('تكرار كل السور'),
                subtitle: Text(
                  'بعد آخر سورة يرجع لأولها',
                  style: TextStyle(color: palette.textMuted),
                ),
                selected: handler.repeatMode == QuranRepeatMode.all,
                selectedColor: palette.primary,
                onTap: () {
                  handler.setQuranRepeatMode(QuranRepeatMode.all);
                  Navigator.pop(sheetContext);
                },
              ),
              Divider(height: AppSpace.sm, color: palette.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.sm,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'كرر السورة عدد مرات محدد',
                    style: TextStyle(fontSize: 13, color: palette.textMuted),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, 0, AppSpace.lg, AppSpace.lg,
                ),
                child: Wrap(
                  spacing: AppSpace.sm,
                  children: [3, 5, 7, 10].map((times) {
                    final selected =
                        handler.repeatMode == QuranRepeatMode.count &&
                        handler.repeatTarget == times;
                    return ChoiceChip(
                      label: Text('$times مرات'),
                      selected: selected,
                      showCheckmark: false,
                      backgroundColor: palette.surfaceAlt,
                      selectedColor: palette.primarySoft,
                      side: BorderSide(
                        color: selected ? palette.primary : palette.border,
                      ),
                      labelStyle: TextStyle(
                        color: selected ? palette.primary : palette.text,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillR,
                      ),
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetTitle('مؤقت النوم'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [5, 10, 15, 30, 45, 60].map((minutes) {
                    return ActionChip(
                      label: Text('$minutes دقيقة'),
                      backgroundColor: palette.surfaceAlt,
                      side: BorderSide(color: palette.border),
                      labelStyle: TextStyle(color: palette.text),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.pillR,
                      ),
                      onPressed: () {
                        handler.startSleepTimer(Duration(minutes: minutes));
                        Navigator.pop(sheetContext);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              ListTile(
                leading: Icon(Icons.menu_book, color: palette.textMuted),
                title: const Text('بعد نهاية السورة الحالية'),
                onTap: () {
                  handler.sleepAfterCurrentSurah();
                  Navigator.pop(sheetContext);
                },
              ),
              if (handler.sleepTimerActive)
                ListTile(
                  leading: Icon(Icons.close, color: palette.danger),
                  title: Text(
                    'إلغاء المؤقت',
                    style: TextStyle(color: palette.danger),
                  ),
                  onTap: () {
                    handler.cancelSleepTimer();
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: AppSpace.sm),
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
  final AppPalette palette;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? palette.primary : palette.textFaint;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.chipR,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط التقدم — بيقرأ الموضع من المشغل ويسمح بالسحب
class _SeekBar extends StatefulWidget {
  final QuranAudioHandler handler;
  final AppPalette palette;
  final Duration? duration;

  const _SeekBar({
    required this.handler,
    required this.palette,
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
    final p = widget.palette;
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
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: p.primary,
                inactiveTrackColor: p.border,
                thumbColor: p.primary,
                overlayColor: p.primarySoft,
              ),
              child: Slider(
                min: 0,
                // لو المدة لسه مش معروفة نحمي الـ Slider من max = 0
                max: maxMs > 0 ? maxMs : 1,
                value: (_dragValue ?? currentMs).clamp(0.0, maxMs > 0 ? maxMs : 1.0).toDouble(),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _format(position),
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                  Text(
                    _format(total),
                    style: TextStyle(fontSize: 12, color: p.textMuted),
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
