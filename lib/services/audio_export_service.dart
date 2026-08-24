import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// نتيجة محاولة حفظ تلاوة في مكتبة الموسيقى.
class AudioExportResult {
  /// المجلد اللي الملف اتحفظ فيه، زي `Music/أذكاري`
  final String folder;

  /// true لو الملف كان محفوظ قبل كده فمعملناش نسخة تانية
  final bool alreadyExisted;

  const AudioExportResult({required this.folder, required this.alreadyExisted});
}

class AudioExportException implements Exception {
  final String message;
  const AudioExportException(this.message);

  @override
  String toString() => message;
}

/// تصدير التلاوات المحمّلة لبرّه التطبيق.
///
/// التحميلات بتقعد في مجلد التطبيق الخاص (شوف [QuranDownloadService]) —
/// مفيش صلاحيات مطلوبة والملفات بتتمسح مع التطبيق، وده الاختيار الصح
/// للاستماع جوّه التطبيق. بس معناه إن مفيش مشغل تاني على الجهاز بيشوفها.
/// الخدمة دي بتدّي المستخدم مخرج من الحكاية دي بطريقتين:
///
/// * **أندرويد** — [saveToMusicLibrary] بتنسخ الملف لمكتبة الموسيقى
///   العامة بأسماء عربية مضبوطة، فبيظهر في أي مشغل على الجهاز.
/// * **أي نظام** — [shareFile] بتفتح لوحة المشاركة بنسخة اسمها مقروء،
///   فالمستخدم يبعتها لنفسه أو يحفظها في أي تطبيق ملفات. ده الحل الوحيد
///   على iOS: مفيش API عند آبل لإضافة صوت لمكتبة الموسيقى — `MPMediaLibrary`
///   بتخص Apple Music بس. عشان كده كمان فعّلنا مشاركة الملفات في
///   `Info.plist`، فتحميلات التطبيق بتبان في Files ← On My iPhone ← أذكاري.
///
/// **بننسخ مش بنقل**: التطبيق بيحتفظ بنسخته الخاصة عشان الاستماع بدون
/// إنترنت جوّه التطبيق يفضل شغال، يعني المساحة بتتضاعف للسورة المصدّرة.
class AudioExportService {
  static const MethodChannel _channel = MethodChannel(
    'com.adhkari.app/audio_export',
  );

  /// الحفظ في مكتبة الموسيقى متاح على أندرويد بس
  static bool get canSaveToMusicLibrary => Platform.isAndroid;

  /// بتحفظ نسخة من [sourcePath] في `Music/أذكاري` وبتسجّلها في MediaStore.
  ///
  /// [surahName] و[reciterName] بيتكتبوا كـ TITLE و ARTIST، و[surahId] كرقم
  /// المقطع عشان المشغل يرتّب السور بترتيب المصحف. الأسماء دي مهمة: مشغلات
  /// الموسيقى بتقرا من فهرس MediaStore مش من وسوم الملف، ووسوم ملفات
  /// mp3quran.net ناقصة — من غير الأسماء دي التلاوة بتظهر باسم زي
  /// `r7_m1_s002` ومن غير قارئ.
  static Future<AudioExportResult> saveToMusicLibrary({
    required String sourcePath,
    required int surahId,
    required String surahName,
    required String reciterName,
    String? moshafName,
  }) async {
    if (!canSaveToMusicLibrary) {
      throw const AudioExportException(
        'الحفظ في مكتبة الموسيقى متاح على أندرويد بس',
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>('export', {
        'sourcePath': sourcePath,
        'fileName': exportFileName(
          surahId: surahId,
          surahName: surahName,
          reciterName: reciterName,
        ),
        'title': '${_padSurah(surahId)} $surahName',
        'artist': reciterName,
        'album': moshafName == null || moshafName.isEmpty
            ? 'أذكاري — القرآن الكريم'
            : 'أذكاري — $moshafName',
        'track': surahId,
      });

      if (result == null) {
        throw const AudioExportException('مفيش رد من نظام الحفظ');
      }

      return AudioExportResult(
        folder: result['folder'] as String? ?? 'Music/أذكاري',
        alreadyExisted: result['existed'] as bool? ?? false,
      );
    } on PlatformException catch (e) {
      throw AudioExportException(e.message ?? 'مقدرناش نحفظ الملف');
    } on MissingPluginException {
      throw const AudioExportException(
        'الحفظ مش مدعوم على النسخة دي من التطبيق',
      );
    }
  }

  /// هل السورة دي محفوظة في مكتبة الموسيقى خلاص؟
  ///
  /// بترجع false على أي نظام غير أندرويد، وكمان لو الاستعلام فشل — الزرار
  /// بيفضل ظاهر ساعتها، وهو أرحم من إننا نخفيه بالغلط.
  static Future<bool> isInMusicLibrary({
    required int surahId,
    required String surahName,
    required String reciterName,
  }) async {
    if (!canSaveToMusicLibrary) return false;

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'isExported',
        {
          'fileName': exportFileName(
            surahId: surahId,
            surahName: surahName,
            reciterName: reciterName,
          ),
        },
      );
      return result?['exported'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// بتفتح لوحة المشاركة بنسخة اسمها مقروء.
  ///
  /// الملف الأصلي اسمه `r7_m1_s002.mp3`، ولوحة المشاركة بتبعت الاسم زي ما
  /// هو — فالمستقبل بيلاقي ملف مالوش معنى. عشان كده بننسخه في المجلد
  /// المؤقت بالاسم العربي الكامل الأول.
  static Future<void> shareFile({
    required String sourcePath,
    required int surahId,
    required String surahName,
    required String reciterName,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const AudioExportException('الملف مش موجود');
    }

    final name = exportFileName(
      surahId: surahId,
      surahName: surahName,
      reciterName: reciterName,
    );

    // مجلد فرعي عشان النسخ المؤقتة ما تختلطش بحاجة تانية. بنفضّيه كل مرة:
    // كل مشاركة بتسيب نسخة ورايها، ومن غير التنضيف ده مساحة التطبيق
    // بتكبر بسورة كاملة مع كل مشاركة. آمن لأننا بنستنى لوحة المشاركة
    // تخلص، فمفيش نسخة لسه مستعملة وقت التفضية.
    final tempDir = Directory('${(await getTemporaryDirectory()).path}/share');
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    final copy = await source.copy('${tempDir.path}/$name');

    await Share.shareXFiles(
      [XFile(copy.path, mimeType: 'audio/mpeg', name: name)],
      subject: '$surahName — $reciterName',
    );
  }

  /// اسم الملف المعروض: `002 - البقرة - عبد الباسط عبد الصمد.mp3`
  ///
  /// الرقم في الأول بصفرين عشان يترتب صح في أي تطبيق ملفات.
  @visibleForTesting
  static String exportFileName({
    required int surahId,
    required String surahName,
    required String reciterName,
  }) {
    final safeSurah = _sanitize(surahName);
    final safeReciter = _sanitize(reciterName);
    return '${_padSurah(surahId)} - $safeSurah - $safeReciter.mp3';
  }

  static String _padSurah(int surahId) =>
      surahId.toString().padLeft(3, '0');

  /// بيشيل الحروف اللي مش مسموحة في أسماء الملفات.
  ///
  /// أهمها الشرطة المايلة: MediaStore بيرفض الصف كله لو اسم الملف فيه
  /// واحدة، لأنها بتخلط بينه وبين مسار.
  static String _sanitize(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[/\\:*?"<>|\r\n\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'غير معروف' : cleaned;
  }
}
