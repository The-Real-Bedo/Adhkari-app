import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إحداثيات مكان. بتتحفظ عشان المواقيت تشتغل من غير ما نفتح الـ GPS كل مرة.
@immutable
class PrayerLocation {
  final double latitude;
  final double longitude;

  const PrayerLocation(this.latitude, this.longitude);

  Coordinates get coordinates => Coordinates(latitude, longitude);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerLocation &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// نتيجة محاولة تحديد المكان — الواجهة بتعرض رسالة مختلفة لكل حالة.
enum PrayerLocationStatus {
  fresh,
  cached,
  permissionDenied,
  serviceDisabled,
  unavailable,
}

class PrayerLocationResult {
  final PrayerLocation? location;
  final PrayerLocationStatus status;

  const PrayerLocationResult(this.location, this.status);

  bool get hasLocation => location != null;
}

/// مواقيت الصلاة — الحساب على الجهاز بطريقة الهيئة المصرية العامة للمساحة
/// (فجر 19.5° وعشاء 17.5°)، والإحداثيات من الـ GPS بتتحفظ فبيشتغل بدون نت.
class PrayerTimesService {
  static const String _kLat = 'prayer_latitude';
  static const String _kLng = 'prayer_longitude';

  static CalculationParameters get calculationParameters =>
      CalculationMethod.egyptian.getParameters();

  static Future<PrayerLocation?> cachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    if (lat == null || lng == null) return null;
    return PrayerLocation(lat, lng);
  }

  static Future<void> _cache(PrayerLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, location.latitude);
    await prefs.setDouble(_kLng, location.longitude);
  }

  /// GPS، فالمحفوظ، فالفشل. المحفوظ بيتقدّم عن قصد — إحداثيات امبارح
  /// أقرب للصح من كارت فاضي.
  static Future<PrayerLocationResult> resolveLocation({
    bool askPermission = true,
  }) async {
    final PrayerLocation? cached = await cachedLocation();

    PrayerLocationResult fallback(PrayerLocationStatus ifNoCache) =>
        PrayerLocationResult(
          cached,
          cached != null ? PrayerLocationStatus.cached : ifNoCache,
        );

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 5));
      if (!serviceEnabled) {
        return fallback(PrayerLocationStatus.serviceDisabled);
      }

      // الاتنين دول بيعدّوا على القناة الأصلية وممكن ما يرجّعوش خالص لو
      // الخدمة اتعلّقت — من غير مهلة الكارت كان هيفضل على "بنحسب..." للأبد.
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 5));

      // مفيش مهلة على دي عن قصد — دي نافذة النظام والمستخدم ليه وقته
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return fallback(PrayerLocationStatus.permissionDenied);
      }

      // دقة واطية مقصودة: المواقيت بتفرق ثواني على مدى كيلومترات، فمش
      // محتاجين دقة أمتار — وده أسرع وأوفر للبطارية.
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final location = PrayerLocation(position.latitude, position.longitude);
      await _cache(location);
      return PrayerLocationResult(location, PrayerLocationStatus.fresh);
    } catch (e) {
      // لازم تتطبع: قبل كده الاستثناء ده كان بيتبلع بالكامل، فلما كانت
      // صلاحيات الموقع ناقصة من AndroidManifest كان geolocator بيرمي
      // PermissionDefinitionsNotFoundException والكارت يعرض "مقدرناش نجيب
      // مكانك" من غير أي أثر في اللوج نمسك منه.
      debugPrint('فشل تحديد الموقع لمواقيت الصلاة: $e');
      return fallback(PrayerLocationStatus.unavailable);
    }
  }

  /// مواقيت يوم. [date] فاضية تعني النهارده.
  static PrayerTimes timesFor(PrayerLocation location, {DateTime? date}) {
    final params = calculationParameters;
    if (date == null) {
      return PrayerTimes.today(location.coordinates, params);
    }
    return PrayerTimes(location.coordinates, DateComponents.from(date), params);
  }
}

const Map<Prayer, String> prayerNamesAr = {
  Prayer.fajr: 'الفجر',
  Prayer.sunrise: 'الشروق',
  Prayer.dhuhr: 'الظهر',
  Prayer.asr: 'العصر',
  Prayer.maghrib: 'المغرب',
  Prayer.isha: 'العشاء',
};

/// ترتيب العرض. الشروق جوّاهم لأنه علامة وقت مهمة رغم إنه مش صلاة.
const List<Prayer> prayerOrder = [
  Prayer.fajr,
  Prayer.sunrise,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

/// الصلوات اللي ليها تنبيه — الشروق مستبعد.
const List<Prayer> notifiablePrayers = [
  Prayer.fajr,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

/// المكتبة فيها getter لكل صلاة لكن مفيش دالة بتاخد [Prayer] وترجّع وقتها.
extension PrayerTimesLookup on PrayerTimes {
  DateTime? timeOf(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return fajr;
      case Prayer.sunrise:
        return sunrise;
      case Prayer.dhuhr:
        return dhuhr;
      case Prayer.asr:
        return asr;
      case Prayer.maghrib:
        return maghrib;
      case Prayer.isha:
        return isha;
      case Prayer.none:
        return null;
    }
  }
}
