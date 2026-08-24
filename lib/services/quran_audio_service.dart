import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'quran_audio_handler.dart';

/// نقطة وصول واحدة للهاندلر بعد تهيئته.
///
/// audio_service بيتهيّأ مرة واحدة بس على مستوى العملية كلها، فبنحتفظ
/// بالمرجع هنا عشان المشغل والشريط المصغر يشتغلوا على نفس النسخة.
///
/// التهيئة بقت **بعد أول frame** مش قبل `runApp` — كانت بتاخد جزء كبير من
/// الـ 3.1 ثانية اللي التطبيق كان بيستغرقها عشان يرسم أول شاشة. فمعنى كده
/// إن الـ widgets بتتبني وهي لسه مش جاهزة، وعشان كده فيه حاجتين هنا:
/// [readyNotifier] للـ widgets تعيد البناء لما تبقى جاهزة، و[ensureReady]
/// للكود اللي ينفع يستنى.
class QuranAudioService {
  static QuranAudioHandler? _handler;

  /// التهيئة الجارية — بنحتفظ بيها عشان أي حد ينده [ensureReady] يستنى
  /// نفس العملية بدل ما يبدأ واحدة جديدة.
  static Future<void>? _initFuture;

  /// بتبقى true مرة واحدة لما التهيئة تنجح.
  ///
  /// الـ widgets اللي بتتفرج على [isReady] لازم تسمع للـ notifier ده، وإلا
  /// هتفضل على النسخة البديلة للأبد لأن مفيش حاجة بتعيد بناءها لما
  /// التهيئة تخلص بعد أول frame.
  static final ValueNotifier<bool> readyNotifier = ValueNotifier<bool>(false);

  static bool get isReady => _handler != null;

  /// بترمي StateError لو اتنادت قبل التهيئة — ده بيبان في التطوير على طول
  static QuranAudioHandler get handler {
    final h = _handler;
    if (h == null) {
      throw StateError('QuranAudioService.init() لسه مانداتش');
    }
    return h;
  }

  /// بتتنادي مرة واحدة من main() بعد أول frame.
  ///
  /// النداء المتكرر بيرجع نفس العملية، فمفيش خطر تهيئة مزدوجة لو حد ندهها
  /// من شاشة في نفس اللحظة.
  static Future<void> init() {
    return _initFuture ??= _initOnce().catchError((Object e) {
      _initFuture = null; // السماح بإعادة المحاولة في المرة القادمة
      throw e;
    });
  }

  static Future<void> _initOnce() async {
    _handler = await AudioService.init(
      builder: QuranAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: kQuranChannelId,
        androidNotificationChannelName: 'تلاوة القرآن',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        // مهم: القناة دي منفصلة عن قناة تنبيهات الأذكار
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
    readyNotifier.value = true;
  }

  /// بتستنى التهيئة لو لسه شغالة، وبترجع هي نجحت ولا لأ.
  ///
  /// مبترميش — الشاشة اللي بتنده بتقرأ النتيجة وتعرض رسالة لو false. ده
  /// أهم من إنها تفشل فورًا: لو المستخدم فتح المشغل في أول ثانية من عمر
  /// التطبيق، التهيئة ساعتها ممكن تكون لسه في نصها.
  static Future<bool> ensureReady() async {
    if (isReady) return true;
    try {
      await init();
    } catch (e) {
      debugPrint('فشلت تهيئة مشغل القرآن: $e');
    }
    return isReady;
  }
}
