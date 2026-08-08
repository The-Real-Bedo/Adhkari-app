import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/quran_models.dart';

/// حالة تحميل سورة واحدة
class DownloadProgress {
  final int received;
  final int total;

  DownloadProgress(this.received, this.total);

  /// من 0.0 لـ 1.0 — بيرجع null لو الحجم الكلي مش معروف
  double? get fraction => total > 0 ? received / total : null;
}

/// إدارة التحميل للاستماع بدون إنترنت.
///
/// بنحفظ في مجلد التطبيق الخاص (getApplicationDocumentsDirectory) عشان
/// منحتاجش صلاحية تخزين على أندرويد، والملفات بتتمسح مع التطبيق.
class QuranDownloadService {
  /// كاش لأحجام السور عشان منكررش طلب HEAD لنفس السورة
  static final Map<String, int> _sizeCache = {};

  /// مجلد التحميلات
  static Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/quran_audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// اسم الملف المحلي — بنستخدم معرّف القارئ + الرواية + رقم السورة.
  ///
  /// القارئ داخل في الاسم عن قصد: لو معرّفات الروايات في الـ API بتتكرر
  /// بين القراء (مش مضمون إنها فريدة على مستوى الـ API كله)، تحميل نفس
  /// السورة لقارئين مختلفين كان هيكتب فوق بعضه والمستخدم يسمع صوت غير
  /// اللي اختاره من غير أي رسالة خطأ.
  static String _fileName(int reciterId, int moshafId, int surahId) =>
      'r${reciterId}_m${moshafId}_s${surahId.toString().padLeft(3, '0')}.mp3';

  static Future<File> _fileFor(
    int reciterId,
    int moshafId,
    int surahId,
  ) async {
    final dir = await _downloadsDir();
    return File('${dir.path}/${_fileName(reciterId, moshafId, surahId)}');
  }

  /// هل السورة متحملة خلاص؟
  static Future<bool> isDownloaded(
    int reciterId,
    int moshafId,
    int surahId,
  ) async {
    final file = await _fileFor(reciterId, moshafId, surahId);
    if (!await file.exists()) return false;
    // ملف فاضي معناه تحميل اتقطع — نعتبره مش موجود
    return await file.length() > 0;
  }

  /// مسار الملف المحلي لو موجود، وإلا null.
  /// المشغل بيستخدمها عشان يشغل من الجهاز بدل الإنترنت.
  static Future<String?> localPath(
    int reciterId,
    int moshafId,
    int surahId,
  ) async {
    final file = await _fileFor(reciterId, moshafId, surahId);
    if (await file.exists() && await file.length() > 0) return file.path;
    return null;
  }

  /// حجم السورة بالبايت من السيرفر — طلب HEAD خفيف من غير تحميل الملف.
  /// بنستدعيها لما المستخدم يدوس تحميل عشان نعرض الحجم قبل ما يوافق.
  static Future<int?> remoteSize(Moshaf moshaf, int surahId) async {
    final url = moshaf.audioUrlFor(surahId);
    if (url == null) return null;

    if (_sizeCache.containsKey(url)) return _sizeCache[url];

    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      final raw = response.headers['content-length'];
      final size = raw == null ? null : int.tryParse(raw);
      if (size != null && size > 0) {
        _sizeCache[url] = size;
        return size;
      }
      return null;
    } catch (_) {
      return null; // مش مشكلة — الواجهة هتعرض "الحجم غير معروف"
    }
  }

  // ————— إدارة التحميلات الجارية —————

  /// التحميلات الشغالة دلوقتي، مفتاحها القارئ + الرواية + السورة.
  ///
  /// بنمسك التحميل هنا مش جوه الشاشة عن قصد: قبل كده الاشتراك كان بتاع
  /// الـ State، فأول ما المستخدم يخرج من الشاشة الـ dispose بيلغيه
  /// والتحميل بيقف ويختفي من غير ما حد يقوله. دلوقتي الشاشة بتتفرج بس،
  /// والتحميل بيكمل لحد ما يخلص حتى لو المستخدم لف على تبويبات تانية.
  static final Map<String, DownloadJob> _active = {};

  static String _jobKey(int reciterId, int moshafId, int surahId) =>
      '${reciterId}_${moshafId}_$surahId';

  /// بدء تحميل — أو الرجوع للتحميل الشغال لو نفس السورة بتتحمل خلاص
  static DownloadJob startDownload(
    int reciterId,
    Moshaf moshaf,
    int surahId,
  ) {
    final key = _jobKey(reciterId, moshaf.id, surahId);

    final existing = _active[key];
    if (existing != null) return existing;

    final job = DownloadJob._(key, reciterId, moshaf.id, surahId);
    _active[key] = job;
    job._start(moshaf);
    return job;
  }

  /// التحميل الشغال لسورة معينة لو موجود
  static DownloadJob? activeJob(int reciterId, int moshafId, int surahId) =>
      _active[_jobKey(reciterId, moshafId, surahId)];

  /// كل التحميلات الشغالة — الشاشة بتستخدمها عشان ترجع تتابعها لما تفتح تاني
  static List<DownloadJob> get activeJobs => _active.values.toList();

  /// تحميل سورة مع تتبّع التقدم.
  ///
  /// بنكتب في ملف مؤقت (.part) وننقله بعد ما يخلص، عشان لو التحميل
  /// اتقطع منفضلش بملف ناقص التطبيق يفتكره كامل.
  static Stream<DownloadProgress> _rawDownload(
    int reciterId,
    Moshaf moshaf,
    int surahId,
  ) async* {
    final url = moshaf.audioUrlFor(surahId);
    if (url == null) {
      throw QuranDownloadException('السورة دي مش متاحة في الرواية دي');
    }

    final target = await _fileFor(reciterId, moshaf.id, surahId);
    final partial = File('${target.path}.part');

    // لو فيه بقايا من تحميل اتلغى قبل كده بنشيلها، عشان منكتبش فوقها
    // ونطلع بملف نصه من تحميل ونصه من التاني
    if (await partial.exists()) {
      try {
        await partial.delete();
      } catch (_) {}
    }

    final client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw QuranDownloadException('فشل التحميل (${response.statusCode})');
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      final sink = partial.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          yield DownloadProgress(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // خلص بنجاح — دلوقتي بس نعتبره ملف كامل
      await partial.rename(target.path);
      yield DownloadProgress(received, total);
    } catch (e) {
      // نظّف الملف الناقص
      if (await partial.exists()) {
        try {
          await partial.delete();
        } catch (_) {}
      }
      if (e is QuranDownloadException) rethrow;
      throw QuranDownloadException('فشل التحميل، تأكد من الاتصال بالإنترنت');
    } finally {
      client.close();
    }
  }

  /// مسح سورة متحملة
  static Future<void> delete(int reciterId, int moshafId, int surahId) async {
    final file = await _fileFor(reciterId, moshafId, surahId);
    if (await file.exists()) await file.delete();
  }

  /// كل السور المتحملة مع أحجامها — لشاشة إدارة التحميلات
  static Future<List<DownloadedFile>> listDownloads() async {
    final dir = await _downloadsDir();
    final result = <DownloadedFile>[];

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(RegExp(r'[/\\]')).last;

      // بنتجاهل الملفات الناقصة (.part) وأي حاجة مش بصيغتنا
      if (!name.endsWith('.mp3')) continue;

      final match = RegExp(r'^r(\d+)_m(\d+)_s(\d+)\.mp3$').firstMatch(name);
      if (match == null) continue;

      result.add(
        DownloadedFile(
          reciterId: int.parse(match.group(1)!),
          moshafId: int.parse(match.group(2)!),
          surahId: int.parse(match.group(3)!),
          path: entity.path,
          bytes: await entity.length(),
        ),
      );
    }

    result.sort((a, b) => a.surahId.compareTo(b.surahId));
    return result;
  }

  /// مسح كل التحميلات
  static Future<void> deleteAll() async {
    final dir = await _downloadsDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// تنسيق الحجم بالعربي: "12.4 ميجابايت".
  /// بيتعرض قبل التحميل بس — عشان المستخدم يعرف هياكل قد إيه من الباقة.
  static String formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return 'غير معروف';

    const kb = 1024;
    const mb = kb * 1024;

    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} ميجابايت';
    }
    return '${(bytes / kb).toStringAsFixed(0)} كيلوبايت';
  }
}

/// تحميل واحد شغال. بيعيش في الخدمة مش في الشاشة، عشان يفضل ماشي
/// حتى لو المستخدم قفل الصفحة أو راح لتبويب تاني.
class DownloadJob {
  final String _key;
  final int reciterId;
  final int moshafId;
  final int surahId;

  final _controller = StreamController<DownloadProgress>.broadcast();
  StreamSubscription<DownloadProgress>? _sub;

  /// آخر تقدم وصلنا له — الشاشة بتقراه أول ما تفتح عشان تعرض النسبة
  /// الصح على طول من غير ما تستنى أول حدث جديد (الـ broadcast مبيعيدش
  /// الأحداث القديمة للمشترك المتأخر)
  DownloadProgress? last;

  bool _cancelled = false;
  bool get cancelled => _cancelled;

  DownloadJob._(this._key, this.reciterId, this.moshafId, this.surahId);

  /// بيبث التقدم. ممكن أكتر من شاشة تتفرج عليه في نفس الوقت.
  Stream<DownloadProgress> get stream => _controller.stream;

  void _start(Moshaf moshaf) {
    _sub =
        QuranDownloadService._rawDownload(reciterId, moshaf, surahId).listen(
          (progress) {
            last = progress;
            if (!_controller.isClosed) _controller.add(progress);
          },
          onDone: _finish,
          onError: (Object e) {
            if (!_controller.isClosed) _controller.addError(e);
            _finish();
          },
          cancelOnError: true,
        );
  }

  void _finish() {
    QuranDownloadService._active.remove(_key);
    if (!_controller.isClosed) _controller.close();
  }

  /// إلغاء التحميل بناء على طلب المستخدم — بنشيل الملف الناقص كمان
  Future<void> cancel() async {
    _cancelled = true;
    await _sub?.cancel();

    // إلغاء الاشتراك بيوقف الـ generator، والـ finally جواه بيقفل الملف
    // والاتصال، لكن الـ catch مبيشتغلش — فبنمسح الـ .part بإيدينا هنا.
    try {
      final target = await QuranDownloadService._fileFor(
        reciterId,
        moshafId,
        surahId,
      );
      final partial = File('${target.path}.part');
      if (await partial.exists()) await partial.delete();
    } catch (_) {}

    _finish();
  }
}

class DownloadedFile {
  final int reciterId;
  final int moshafId;
  final int surahId;
  final String path;
  final int bytes;

  DownloadedFile({
    required this.reciterId,
    required this.moshafId,
    required this.surahId,
    required this.path,
    required this.bytes,
  });
}

class QuranDownloadException implements Exception {
  final String message;
  QuranDownloadException(this.message);
  @override
  String toString() => message;
}
