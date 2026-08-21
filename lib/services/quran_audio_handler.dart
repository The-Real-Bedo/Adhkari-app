import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../models/quran_models.dart';
import 'quran_download_service.dart';
import 'quran_prefs.dart';

/// معرّف قناة الإشعارات الخاصة بالمشغل.
/// لازم يكون مختلف عن قناة التنبيهات في notification_service.dart
/// عشان الاتنين ميتعارضوش.
const String kQuranChannelId = 'com.adhkari.app.quran_audio';

/// أوضاع التكرار
enum QuranRepeatMode {
  /// من غير تكرار — بيقف بعد آخر سورة
  off,

  /// تكرار السورة الحالية للأبد (مفيد في الحفظ)
  one,

  /// لما يخلص آخر سورة يرجع لأولها
  all,

  /// كرر السورة عدد محدد من المرات وبعدين كمّل
  count,
}

/// الهاندلر المسؤول عن التشغيل والتحكم من الإشعار وشاشة القفل.
///
/// بندير قائمة التشغيل يدويًا (مش ConcatenatingAudioSource) لأن الـ API بتاعها
/// اتغير بين نسخ just_audio، والطريقة اليدوية تشتغل على كل النسخ.
class QuranAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  /// بيانات الرواية الحالية عشان نبني روابط السور
  Moshaf? _moshaf;
  int _reciterId = 0;
  String _reciterName = '';

  /// أرقام السور المتاحة بالترتيب — الفهرس هنا هو نفسه فهرس الـ queue
  List<int> _surahIds = const [];

  int _currentIndex = -1;

  // ————— التكرار والعشوائي —————

  QuranRepeatMode _repeatMode = QuranRepeatMode.off;

  /// عدد مرات التكرار المطلوبة في وضع count
  int _repeatTarget = 3;

  /// عدد المرات اللي اتكررت فعلًا للسورة الحالية
  int _repeatDone = 0;

  bool _shuffle = false;
  final Random _random = Random();

  /// بتبث تغيّر وضع التكرار/العشوائي للواجهة.
  /// بنخزن الـ stream في متغير لأن getter الـ broadcast بيرجع كائن جديد
  /// كل مرة، واللي بيخلي StreamBuilder يعيد الاشتراك ويفقد آخر قيمة.
  final _modeController = StreamController<void>.broadcast();
  late final Stream<void> _modeStream = _modeController.stream;
  Stream<void> get modeStream => _modeStream;

  QuranRepeatMode get repeatMode => _repeatMode;
  int get repeatTarget => _repeatTarget;
  bool get shuffleEnabled => _shuffle;

  // ————— مؤقت النوم —————

  Timer? _sleepTimer;
  DateTime? _sleepEndsAt;

  /// لما تكون true بنوقف بعد ما السورة الحالية تخلص بدل وقت محدد
  bool _sleepAtEndOfSurah = false;

  final _sleepController = StreamController<Duration?>.broadcast();
  late final Stream<Duration?> _sleepStream = _sleepController.stream;

  /// الوقت المتبقي لمؤقت النوم — null لو المؤقت مقفول
  Stream<Duration?> get sleepRemainingStream => _sleepStream;

  bool get sleepTimerActive => _sleepTimer != null || _sleepAtEndOfSurah;
  bool get sleepAtEndOfSurah => _sleepAtEndOfSurah;

  QuranAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // إعداد الجلسة الصوتية: نوع "speech" مناسب للتلاوة، وبيخلي التطبيقات
    // التانية تخفض صوتها بدل ما تقطع التلاوة
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    // أي تغيير في حالة المشغل بيتحول لحالة يفهمها نظام التشغيل
    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object e, StackTrace st) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorMessage: 'تعذر تشغيل التلاوة، تأكد من الاتصال بالإنترنت',
          ),
        );
      },
    );

    // لما المدة تتعرف (بعد تحميل الملف) نحدّث الـ mediaItem
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });

    // انتهت السورة؟ روح للي بعدها لو فيه.
    // بنمسك الأخطاء هنا لأن الانتقال للسورة الجاية ممكن يفشل (النت قطع مثلًا)
    // ولو سيبناها بتطلع كـ unhandled error جوه الـ stream.
    _player.processingStateStream.listen((state) {
      if (state != ProcessingState.completed) return;
      _onTrackCompleted().catchError((Object _) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorMessage: 'تعذر الانتقال للسورة التالية',
          ),
        );
      });
    });

    // نحفظ الموضع كل فترة عشان نكمل من نفس المكان بعد ما التطبيق يتقفل
    _player.positionStream
        .where((_) => _player.playing)
        .listen(_maybePersistPosition);
  }

  /// تحميل تلاوة قارئ معين وبدء التشغيل من سورة محددة
  Future<void> loadReciter({
    required int reciterId,
    required String reciterName,
    required Moshaf moshaf,
    required List<Surah> allSuwar,
    required int startSurahId,
    Duration startPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    _reciterId = reciterId;
    _reciterName = reciterName;
    _moshaf = moshaf;

    // وضع التكرار بالعدد بيتصفّر مع كل تلاوة جديدة
    _repeatDone = 0;

    // بنحترم قائمة سور الرواية — مش كل قارئ عنده 114 سورة
    final available = allSuwar
        .where((s) => moshaf.surahList.contains(s.id))
        .toList();

    _surahIds = available.map((s) => s.id).toList();

    // نبني الـ queue اللي بيظهر لنظام التشغيل
    queue.add([
      for (final surah in available)
        MediaItem(
          id: moshaf.audioUrlFor(surah.id)!,
          album: reciterName,
          title: 'سورة ${surah.name}',
          artist: '$reciterName — ${moshaf.name}',
          // moshafId مهم: الشاشة بتقارن بيه عشان تعرف إذا كانت التلاوة
          // الشغالة هي نفسها المطلوبة ولا لأ. من غيره القارئ الواحد
          // بروايتين مختلفتين بيبان كأنه نفس الحاجة.
          extras: {
            'surahId': surah.id,
            'moshafId': moshaf.id,
            'makkia': surah.makkia,
          },
        ),
    ]);

    final index = _surahIds.indexOf(startSurahId);
    await skipToQueueItem(index >= 0 ? index : 0, startAt: startPosition);

    if (autoPlay) await play();
  }

  @override
  Future<void> skipToQueueItem(
    int index, {
    Duration startAt = Duration.zero,
  }) async {
    final items = queue.value;
    if (index < 0 || index >= items.length) return;

    _currentIndex = index;
    _repeatDone = 0; // سورة جديدة — نصفّر عدّاد التكرار
    final item = items[index];

    // نعرض الـ mediaItem فورًا عشان الواجهة والإشعار يتحدثوا قبل التحميل
    mediaItem.add(item);
    playbackState.add(playbackState.value.copyWith(queueIndex: index));

    try {
      final surahId = item.extras?['surahId'] as int?;
      final moshaf = _moshaf;

      // لو السورة متحملة على الجهاز نشغلها منه بدل الإنترنت —
      // أسرع وبيوفر بيانات
      String? local;
      if (surahId != null && moshaf != null) {
        local = await QuranDownloadService.localPath(
          _reciterId,
          moshaf.id,
          surahId,
        );
      }

      if (local != null) {
        await _player.setFilePath(local, initialPosition: startAt);
      } else {
        await _player.setUrl(item.id, initialPosition: startAt);
      }
    } catch (_) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
        ),
      );
      // نرمي الخطأ عشان الواجهة تعرف تعرض رسالة للمستخدم
      rethrow;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() async {
    await _player.pause();
    await _persistPosition(); // نحفظ عند الإيقاف بالتأكيد
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// بنعمل override لـ skipToNext/skipToPrevious بدل ما نسيب اللي جاي مع
  /// QueueHandler، لأن اللي جاهز بيعمل `playbackState.value.queueIndex!`
  /// وده بيرمي لو مفيش حاجة محمّلة لسه. بنعتمد على _currentIndex بتاعنا.
  @override
  Future<void> skipToNext() async {
    if (_currentIndex < 0) return;
    if (_currentIndex + 1 >= queue.value.length) return;

    final wasPlaying = _player.playing;
    await skipToQueueItem(_currentIndex + 1);
    if (wasPlaying) await play();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex <= 0) return;

    final wasPlaying = _player.playing;
    await skipToQueueItem(_currentIndex - 1);
    if (wasPlaying) await play();
  }

  @override
  Future<void> stop() async {
    await _persistPosition();
    cancelSleepTimer();
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    // مهم: لازم نفضّي الـ mediaItem كمان. لو سيبناها بقيمتها القديمة،
    // الشاشة اللي بتعمل preload بتلاقي "فيه حاجة محمّلة" وبتتخطى التحميل،
    // فالشريط المصغر مبيرجعش تاني لحد ما التطبيق يتقفل ويتفتح.
    mediaItem.add(null);
    _currentIndex = -1;
    await super.stop();
  }

  /// عدد السور المتاحة — بتستخدمها الواجهة
  int get trackCount => _surahIds.length;

  /// رقم السورة الحالية (مش الفهرس)
  int? get currentSurahId =>
      (_currentIndex >= 0 && _currentIndex < _surahIds.length)
      ? _surahIds[_currentIndex]
      : null;

  Stream<Duration> get positionStream => _player.positionStream;

  // ————— التكرار والعشوائي —————

  /// تغيير وضع التكرار. مع وضع count بنبعت عدد المرات المطلوبة.
  Future<void> setQuranRepeatMode(
    QuranRepeatMode mode, {
    int times = 3,
  }) async {
    _repeatMode = mode;
    _repeatTarget = times;
    _repeatDone = 0;
    _modeController.add(null);
    _broadcastState();
  }

  Future<void> setShuffle(bool enabled) async {
    _shuffle = enabled;
    _modeController.add(null);
    _broadcastState();
  }

  /// اللي بيحصل لما السورة تخلص — ده مكان قرار التكرار والعشوائي
  Future<void> _onTrackCompleted() async {
    // مؤقت النوم في وضع "بعد السورة الحالية" — نوقف هنا بالظبط
    if (_sleepAtEndOfSurah) {
      _sleepAtEndOfSurah = false;
      _sleepController.add(null);
      await _player.pause();
      await _player.seek(Duration.zero);
      return;
    }

    // تكرار السورة نفسها للأبد
    if (_repeatMode == QuranRepeatMode.one) {
      await _player.seek(Duration.zero);
      await play();
      return;
    }

    // تكرار بعدد مرات محدد وبعدين نكمّل عادي
    if (_repeatMode == QuranRepeatMode.count) {
      _repeatDone++;
      if (_repeatDone < _repeatTarget) {
        await _player.seek(Duration.zero);
        await play();
        return;
      }
      _repeatDone = 0; // خلصنا العدد — نكمّل للسورة اللي بعدها
    }

    final total = queue.value.length;
    if (total == 0) return;

    // عشوائي: نختار سورة تانية غير اللي احنا فيها
    if (_shuffle && total > 1) {
      int next;
      do {
        next = _random.nextInt(total);
      } while (next == _currentIndex);

      await skipToQueueItem(next);
      await play();
      return;
    }

    if (_currentIndex + 1 < total) {
      await skipToQueueItem(_currentIndex + 1);
      await play();
      return;
    }

    // خلصنا آخر سورة
    if (_repeatMode == QuranRepeatMode.all) {
      await skipToQueueItem(0); // نلف من الأول
      await play();
      return;
    }

    // مفيش تكرار — نوقف ونصفّر الموضع
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  // ————— مؤقت النوم —————

  /// تشغيل المؤقت لمدة محددة. لما يخلص بيوقف التلاوة.
  void startSleepTimer(Duration duration) {
    cancelSleepTimer();

    _sleepEndsAt = DateTime.now().add(duration);
    _sleepController.add(duration);

    // تحديث كل ثانية عشان الواجهة تعرض العد التنازلي
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final endsAt = _sleepEndsAt;
      if (endsAt == null) {
        timer.cancel();
        return;
      }

      final remaining = endsAt.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds == 0) {
        timer.cancel();
        _sleepTimer = null;
        _sleepEndsAt = null;
        _sleepController.add(null);
        await pause(); // بيحفظ الموضع كمان
      } else {
        _sleepController.add(remaining);
      }
    });
  }

  /// وضع "أوقف بعد ما السورة الحالية تخلص"
  void sleepAfterCurrentSurah() {
    cancelSleepTimer();
    _sleepAtEndOfSurah = true;
    _sleepController.add(null);
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndsAt = null;
    _sleepAtEndOfSurah = false;
    _sleepController.add(null);
  }

  @override
  Future<void> onTaskRemoved() async {
    // المستخدم قفل التطبيق من قائمة المهام — ننضف المؤقتات
    cancelSleepTimer();
    await super.onTaskRemoved();
  }

  DateTime? _lastPersist;

  void _maybePersistPosition(Duration position) {
    // مش محتاجين نكتب على القرص كل ثانية — كل 5 ثواني كفاية
    final now = DateTime.now();
    if (_lastPersist != null && now.difference(_lastPersist!).inSeconds < 5) {
      return;
    }
    _lastPersist = now;
    _persistPosition();
  }

  Future<void> _persistPosition() async {
    final surahId = currentSurahId;
    final moshaf = _moshaf;
    if (surahId == null || moshaf == null) return;

    // بنحفظ الأسماء كمان مش الأرقام بس، عشان كارت "تابع الاستماع"
    // يعرض القارئ والسورة من غير ما يستنى تحميل من الشبكة
    await QuranPrefs.saveLastPlayed(
      reciterId: _reciterId,
      reciterName: _reciterName,
      moshafId: moshaf.id,
      surahId: surahId,
      surahTitle: mediaItem.value?.title ?? '',
      position: _player.position,
      duration: _player.duration ?? Duration.zero,
    );
  }

  /// تحويل حالة just_audio لحالة بيفهمها الإشعار وشاشة القفل
  void _broadcastState() {
    final playing = _player.playing;
    final hasPrevious = _currentIndex > 0;
    final hasNext = _currentIndex >= 0 && _currentIndex < _surahIds.length - 1;

    final controls = <MediaControl>[
      if (hasPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (hasNext) MediaControl.skipToNext,
    ];

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {MediaAction.seek},
        // بنحسب الفهارس من الطول الفعلي — القائمة بتبقى عنصرين بس في أول
        // سورة (مفيش سابق)، فأي رقم ثابت زي [0,1,2] بيبقى خارج النطاق
        androidCompactActionIndices: List.generate(
          controls.length.clamp(0, 3),
          (i) => i,
        ),
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex >= 0 ? _currentIndex : null,
      ),
    );
  }
}
