import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/prayer_times_service.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// كارت مواقيت الصلاة في شاشة "اليوم".
///
/// الحساب على الجهاز من إحداثيات الـ GPS (بتتحفظ بعد أول مرة)، والصلاة
/// الجاية معلّم عليها مع العد التنازلي.
///
/// مبنطلبش صلاحية الموقع أول ما التطبيق يفتح — الكارت بيعرض دعوة والمستخدم
/// هو اللي يدوس. طلب صلاحية من غير سياق أغلب الناس بترفضه.
class PrayerTimesCard extends StatefulWidget {
  const PrayerTimesCard({super.key});

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  PrayerTimes? _times;
  PrayerLocationStatus _status = PrayerLocationStatus.unavailable;
  bool _loading = true;
  bool _asking = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load(askPermission: false);

    // نص دقيقة كفاية للعد التنازلي — كل ثانية بيصحّي الشاشة على الفاضي
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool askPermission}) async {
    if (askPermission) setState(() => _asking = true);

    final result = await PrayerTimesService.resolveLocation(
      askPermission: askPermission,
    );

    // لو المستخدم سمح بالموقع من هنا وتنبيهات الصلاة مفعّلة، بنجدولها فورًا
    // بدل ما نستنى التطبيق يفتح تاني. الدالة بتخرج بدري لو التنبيهات مقفولة.
    if (askPermission && result.hasLocation) {
      await NotificationService.syncPrayerNotifications();
    }

    if (!mounted) return;

    setState(() {
      _status = result.status;
      final loc = result.location;
      _times = loc == null ? null : PrayerTimesService.timesFor(loc);
      _loading = false;
      _asking = false;
    });
  }

  String _fmt(DateTime t) {
    final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'ص' : 'م'}';
  }

  String _countdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? 'باقي $h س $m د' : 'باقي $m د';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (_loading) {
      return AppCard(
        child: Row(
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.primary,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Text(
              'بنحسب مواقيت الصلاة...',
              style: TextStyle(color: p.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final times = _times;
    if (times == null) return _prompt(p);

    final next = times.nextPrayer();
    final nextTime = times.timeOf(next);
    final remaining = nextTime?.difference(DateTime.now());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.mosque_outlined, color: p.primary, size: 20),
              const SizedBox(width: AppSpace.sm),
              Text(
                'مواقيت الصلاة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: p.text,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // علامة إن الإحداثيات محفوظة مش جديدة — يعني الـ GPS مانفعش
              if (_status == PrayerLocationStatus.cached)
                Icon(
                  Icons.location_off_outlined,
                  size: 15,
                  color: p.textFaint,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 2),
          for (final prayer in prayerOrder)
            _row(
              p,
              prayer,
              times,
              isNext: prayer == next,
              remaining: prayer == next ? remaining : null,
            ),
        ],
      ),
    );
  }

  Widget _row(
    AppPalette p,
    Prayer prayer,
    PrayerTimes times, {
    required bool isNext,
    Duration? remaining,
  }) {
    final time = times.timeOf(prayer);
    if (time == null) return const SizedBox.shrink();

    // الشروق مش صلاة — بيتعرض كعلامة وقت بلون باهت
    final bool isSunrise = prayer == Prayer.sunrise;
    final Color tone = isNext
        ? p.primary
        : (isSunrise ? p.textFaint : p.text);

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: AppSpace.sm),
      decoration: isNext
          ? BoxDecoration(color: p.primarySoft, borderRadius: AppRadius.chipR)
          : null,
      child: Row(
        children: [
          if (isNext)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: Icon(Icons.play_arrow_rounded, size: 15, color: p.primary),
            ),
          Text(
            prayerNamesAr[prayer] ?? '',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
              color: tone,
            ),
          ),
          const Spacer(),
          if (remaining != null && !remaining.isNegative)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
              child: Text(
                _countdown(remaining),
                style: TextStyle(fontSize: 11.5, color: p.primary),
              ),
            ),
          Text(
            _fmt(time),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
              color: tone,
              // أرقام بعرض واحد عشان عمود الوقت يبقى مستقيم
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prompt(AppPalette p) {
    final String message;
    final String action;

    switch (_status) {
      case PrayerLocationStatus.permissionDenied:
        message = 'محتاجين نعرف مكانك مرة واحدة بس عشان نحسب المواقيت.';
        action = 'اسمح بالموقع';
      case PrayerLocationStatus.serviceDisabled:
        message = 'خدمة الموقع مقفولة في الجهاز. افتحها وحاول تاني.';
        action = 'حاول تاني';
      default:
        message = 'مقدرناش نجيب مكانك. جرّب تاني.';
        action = 'حاول تاني';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mosque_outlined, color: p.primary, size: 20),
              const SizedBox(width: AppSpace.sm),
              Text(
                'مواقيت الصلاة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: p.text,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(message, style: TextStyle(fontSize: 13, color: p.textMuted)),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: _asking ? null : () => _load(askPermission: true),
              icon: const Icon(Icons.my_location, size: 17),
              label: Text(action),
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
