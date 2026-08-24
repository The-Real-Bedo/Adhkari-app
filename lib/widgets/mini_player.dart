import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../services/quran_audio_service.dart';
import '../theme/app_theme.dart';
import 'audio_visuals.dart';

/// شريط تشغيل مصغر بيظهر فوق شريط التنقل في كل التبويبات
/// طول ما فيه تلاوة شغالة. بيختفي تمامًا لو مفيش حاجة بتتشغل.
class MiniPlayer extends StatelessWidget {
  /// بيتنادى لما المستخدم يدوس على الشريط عشان يفتح المشغل الكامل
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // التهيئة بتحصل بعد أول frame، فبنسمع للـ notifier عشان الشريط يظهر
    // لما المشغّل يبقى جاهز بدل ما يفضل مخفي لحد ما حاجة تانية تعيد البناء.
    return ValueListenableBuilder<bool>(
      valueListenable: QuranAudioService.readyNotifier,
      builder: (context, ready, _) {
        if (!ready) return const SizedBox.shrink();
        return _buildBar(context);
      },
    );
  }

  Widget _buildBar(BuildContext context) {
    final handler = QuranAudioService.handler;
    final p = context.palette;

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final playing = state?.playing ?? false;
            final processing = state?.processingState;

            if (processing == AudioProcessingState.idle) {
              return const SizedBox.shrink();
            }

            final isBusy = processing == AudioProcessingState.loading ||
                processing == AudioProcessingState.buffering;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Material(
                color: p.surface,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: p.border, width: 0.8),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: p.primarySoft,
                          // وهي شغالة بتبقى أعمدة متحركة بدل الأيقونة —
                          // إشارة إن الصوت ماشي حتى لو الشاشة ساكتة
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: playing
                                ? EqualizerBars(
                                    key: const ValueKey('bars'),
                                    playing: true,
                                    color: p.primary,
                                  )
                                : Icon(
                                    Icons.menu_book,
                                    key: const ValueKey('icon'),
                                    size: 20,
                                    color: p.primary,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: p.text,
                                ),
                              ),
                              Text(
                                item.album ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: p.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isBusy)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: p.primary,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            iconSize: 32,
                            color: p.primary,
                            icon: Icon(
                              playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                            ),
                            onPressed: () =>
                                playing ? handler.pause() : handler.play(),
                          ),
                        IconButton(
                          iconSize: 22,
                          color: p.textMuted,
                          icon: const Icon(Icons.close),
                          onPressed: () => handler.stop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
