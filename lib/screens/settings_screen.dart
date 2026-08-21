import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/hijri_prefs.dart';
import '../services/notification_service.dart';
import '../services/prayer_times_service.dart';
import '../services/quran_download_service.dart';
import '../theme/app_theme.dart';
import '../utils/hijri_date.dart';
import '../widgets/app_card.dart';
import 'quran/downloads_screen.dart';

/// شاشة الإعدادات — مقسومة أقسام: المظهر، التذكير، التلاوات، معلومات.
class SettingsScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const SettingsScreen({super.key, required this.toggleTheme});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _morningEnabled = true;
  bool _eveningEnabled = true;
  TimeOfDay _morningTime = const TimeOfDay(hour: NotificationService.defaultMorningHour, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: NotificationService.defaultEveningHour, minute: 0);
  bool _isLoading = true;

  /// تنبيهات مواقيت الصلاة — مقفولة افتراضيًا لأنها محتاجة إذن الموقع.
  bool _prayerEnabled = false;

  /// الجدولة بتقرا الإحداثيات المحفوظة، فبدونها السويتش مش بيعمل حاجة —
  /// وعشان كده بنتابع وجودها ونوضّحها بدل ما المستخدم يفضل فاكر إنه مفعّل.
  bool _prayerHasLocation = false;
  bool _prayerBusy = false;

  int _downloadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDownloadInfo();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasLocation = await PrayerTimesService.cachedLocation() != null;
    if (!mounted) return;
    setState(() {
      _morningEnabled = prefs.getBool(NotificationService.kMorningEnabled) ?? true;
      _eveningEnabled = prefs.getBool(NotificationService.kEveningEnabled) ?? true;
      _morningTime = TimeOfDay(
        hour: prefs.getInt(NotificationService.kMorningHour) ?? NotificationService.defaultMorningHour,
        minute: prefs.getInt(NotificationService.kMorningMinute) ?? 0,
      );
      _eveningTime = TimeOfDay(
        hour: prefs.getInt(NotificationService.kEveningHour) ?? NotificationService.defaultEveningHour,
        minute: prefs.getInt(NotificationService.kEveningMinute) ?? 0,
      );
      _prayerEnabled = prefs.getBool(NotificationService.kPrayerEnabled) ?? false;
      _prayerHasLocation = hasLocation;
      _isLoading = false;
    });
  }

  Future<void> _loadDownloadInfo() async {
    try {
      final files = await QuranDownloadService.listDownloads();
      if (!mounted) return;
      setState(() => _downloadCount = files.length);
    } catch (_) {}
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _togglePrayerNotifications(bool value) async {
    setState(() => _prayerEnabled = value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.kPrayerEnabled, value);

    if (!value) {
      // الـ sync بيلغي نطاق تنبيهات الصلاة كله لما تكون مقفولة
      await NotificationService.syncPrayerNotifications();
      if (!mounted) return;
      _snack('تم إيقاف تنبيهات الصلاة');
      return;
    }

    await _resolveLocationAndSchedule();
  }

  /// بنطلب الموقع من هنا كمان، مش من شاشة اليوم بس، عشان اللي بيفعّل
  /// السويتش ياخد مواقيت فعلاً بدل ما يستنى تنبيه مش هييجي.
  Future<void> _resolveLocationAndSchedule() async {
    setState(() => _prayerBusy = true);

    final PrayerLocationResult result =
        await PrayerTimesService.resolveLocation(askPermission: true);
    await NotificationService.syncPrayerNotifications();

    if (!mounted) return;
    setState(() {
      _prayerBusy = false;
      _prayerHasLocation = result.hasLocation;
    });

    if (result.hasLocation) {
      _snack('تم تفعيل تنبيهات الصلاة');
      return;
    }

    _snack(switch (result.status) {
      PrayerLocationStatus.serviceDisabled =>
        'شغّل خدمة الموقع في الهاتف الأول',
      PrayerLocationStatus.permissionDenied =>
        'محتاجين إذن الموقع لحساب المواقيت',
      _ => 'مقدرناش نحدد مكانك — جرّب تاني',
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(NotificationService.kMorningEnabled, _morningEnabled);
    await prefs.setBool(NotificationService.kEveningEnabled, _eveningEnabled);
    await prefs.setInt(NotificationService.kMorningHour, _morningTime.hour);
    await prefs.setInt(NotificationService.kMorningMinute, _morningTime.minute);
    await prefs.setInt(NotificationService.kEveningHour, _eveningTime.hour);
    await prefs.setInt(NotificationService.kEveningMinute, _eveningTime.minute);
    await NotificationService.syncDailyRemindersFromSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ إعدادات التذكير')),
    );
  }

  Future<void> _pickTime({required bool isMorning}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isMorning ? _morningTime : _eveningTime,
    );
    if (picked == null) return;
    setState(() {
      if (isMorning) { _morningTime = picked; } else { _eveningTime = picked; }
    });
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ألوان التذكير — الصباح ذهبي دافي والمساء زمردي هادي
    final morningColor = p.accent;
    final eveningColor = p.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: p.primary))
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                children: [
                  // ————— المظهر —————
                  const SectionTitle('المظهر'),
                  AppCard(
                    child: _ThemeTile(
                      isDark: isDark,
                      onToggle: widget.toggleTheme,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ————— التقويم الهجري —————
                  const SectionTitle('التقويم الهجري'),
                  const _HijriOffsetCard(),
                  const SizedBox(height: 20),

                  // ————— التذكير —————
                  const SectionTitle('مواعيد التذكير'),
                  _ReminderCard(
                    title: 'تذكير أذكار الصباح',
                    subtitle: 'رسالة يومية هادئة لبداية الورد',
                    icon: Icons.wb_sunny_outlined,
                    color: morningColor,
                    enabled: _morningEnabled,
                    time: _morningTime,
                    onToggle: (value) async {
                      setState(() => _morningEnabled = value);
                      await _saveSettings();
                    },
                    onPickTime: () => _pickTime(isMorning: true),
                  ),
                  const SizedBox(height: 12),
                  _ReminderCard(
                    title: 'تذكير أذكار المساء',
                    subtitle: 'تنبيه يومي قبل نهاية اليوم',
                    icon: Icons.nights_stay_outlined,
                    color: eveningColor,
                    enabled: _eveningEnabled,
                    time: _eveningTime,
                    onToggle: (value) async {
                      setState(() => _eveningEnabled = value);
                      await _saveSettings();
                    },
                    onPickTime: () => _pickTime(isMorning: false),
                  ),
                  const SizedBox(height: 20),

                  // ————— مواقيت الصلاة —————
                  const SectionTitle('مواقيت الصلاة'),
                  _PrayerNotificationCard(
                    enabled: _prayerEnabled,
                    hasLocation: _prayerHasLocation,
                    busy: _prayerBusy,
                    onToggle: _togglePrayerNotifications,
                    onRetryLocation: _resolveLocationAndSchedule,
                  ),
                  const SizedBox(height: 20),

                  // ————— التلاوات —————
                  const SectionTitle('التلاوات'),
                  AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.download_done, color: p.primary),
                      title: const Text(
                        'التلاوات المحمّلة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _downloadCount == 0
                            ? 'مفيش تلاوات محمّلة'
                            : '$_downloadCount تلاوة متاحة بدون إنترنت',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DownloadsScreen(),
                          ),
                        );
                        await _loadDownloadInfo();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ————— معلومات —————
                  const SectionTitle('معلومات'),
                  const _NoteCard(),
                ],
              ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _ThemeTile({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final iconColor = isDark ? p.accent : p.primary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isDark ? Icons.dark_mode : Icons.light_mode,
        color: iconColor,
      ),
      title: const Text(
        'الوضع الليلي',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(isDark ? 'مفعّل' : 'مغلق — الوضع النهاري'),
      trailing: Switch(
        value: isDark,
        activeThumbColor: iconColor,
        onChanged: (_) => onToggle(),
      ),
    );
  }
}

/// ضبط إزاحة التاريخ الهجري.
///
/// التقويم الجدولي ممكن يسبق أو يتأخر يوم عن رؤية الهلال المحلية، فالكارت
/// ده بيخلي المستخدم يوفّق التاريخ على بلده. المعاينة بتتحدّث فوراً عشان
/// يشوف بعينه أي إزاحة هي الصح.
class _HijriOffsetCard extends StatelessWidget {
  const _HijriOffsetCard();

  Future<void> _change(BuildContext context, int delta) async {
    final int next = HijriPrefs.offsetNotifier.value + delta;
    await HijriPrefs.setOffset(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ إعدادات التقويم')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ValueListenableBuilder<int>(
      valueListenable: HijriPrefs.offsetNotifier,
      builder: (context, offset, _) {
        final hijri = HijriDate.fromGregorian(DateTime.now(), offset: offset);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تعديل التاريخ الهجري',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'لو التاريخ فارق عندك يوم، ظبّطه من هنا.',
                style: TextStyle(fontSize: 13, color: p.textMuted),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                hijri.formatAr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: p.primary,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: offset > HijriPrefs.minOffset
                        ? () => _change(context, -1)
                        : null,
                    icon: const Icon(Icons.remove),
                    tooltip: 'يوم أقل',
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      offset > 0 ? '+$offset' : '$offset',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: offset < HijriPrefs.maxOffset
                        ? () => _change(context, 1)
                        : null,
                    icon: const Icon(Icons.add),
                    tooltip: 'يوم أكتر',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
  final TimeOfDay time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  const _ReminderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // المسار بياخد لون التذكير عشان يتماشى مع الكارت، والزرار
              // الجوّاه بياخد حبر مقروء فوقه — أبيض على الزمردي وغامق على
              // الذهبي، بدل أبيض ثابت كان بيختفي فوق الذهبي
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: inkOnFill(color),
                activeTrackColor: color,
                trackOutlineColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? color
                      : p.border,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: p.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: enabled ? onPickTime : null,
              icon: const Icon(Icons.schedule),
              label: Text(time.format(context)),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: p.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لو التنبيه لم يظهر، تأكد من السماح للتطبيق بالتنبيهات من إعدادات الهاتف.',
              style: TextStyle(color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// تنبيه عند وقت كل صلاة.
///
/// الكارت بيفرّق بين تلات حالات مش اتنين: مقفول، مفعّل وشغال، ومفعّل من
/// غير موقع. التالتة دي أهم واحدة توضّحها — السويتش شكله مفتوح لكن مفيش
/// تنبيه هييجي، فبنبيّن ده ونحطّ زرار إعادة محاولة.
class _PrayerNotificationCard extends StatelessWidget {
  final bool enabled;
  final bool hasLocation;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final Future<void> Function() onRetryLocation;

  const _PrayerNotificationCard({
    required this.enabled,
    required this.hasLocation,
    required this.busy,
    required this.onToggle,
    required this.onRetryLocation,
  });

  String _subtitle() {
    if (busy) return 'بنحدد مكانك…';
    if (!enabled) return 'مغلق';
    if (!hasLocation) return 'محتاج إذن الموقع لحساب المواقيت';
    return 'بتتحسب من مكانك بطريقة الهيئة المصرية';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool needsLocation = enabled && !hasLocation;
    final Color color = needsLocation ? p.accent : p.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Switch(
                value: enabled,
                onChanged: busy ? null : onToggle,
                activeThumbColor: inkOnFill(color),
                activeTrackColor: color,
                trackOutlineColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? color
                      : p.border,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تنبيه عند كل صلاة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_subtitle(), style: TextStyle(color: p.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (busy)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: color,
                  ),
                )
              else
                Icon(
                  needsLocation
                      ? Icons.location_off_outlined
                      : Icons.mosque_outlined,
                  color: color,
                ),
            ],
          ),
          if (needsLocation && !busy) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetryLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('اسمح بالموقع'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
