import 'package:audio_service/audio_service.dart';

import 'quran_audio_handler.dart';

/// نقطة وصول واحدة للهاندلر بعد تهيئته في main().
///
/// audio_service بيتهيّأ مرة واحدة بس على مستوى العملية كلها، فبنحتفظ
/// بالمرجع هنا عشان المشغل والشريط المصغر يشتغلوا على نفس النسخة.
class QuranAudioService {
  static QuranAudioHandler? _handler;

  static bool get isReady => _handler != null;

  /// بترمي StateError لو اتنادت قبل init — ده بيبان في التطوير على طول
  static QuranAudioHandler get handler {
    final h = _handler;
    if (h == null) {
      throw StateError('QuranAudioService.init() لسه مانداتش في main()');
    }
    return h;
  }

  /// بتتنادي مرة واحدة في main() قبل runApp
  static Future<void> init() async {
    if (_handler != null) return; // حماية من التهيئة المزدوجة

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
  }
}
