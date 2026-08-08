import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/hijri_prefs.dart';
import '../services/notification_service.dart';
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
  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = true;

  int _downloadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDownloadInfo();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _morningEnabled = prefs.getBool('reminder_morning_enabled') ?? true;
      _eveningEnabled = prefs.getBool('reminder_evening_enabled') ?? true;
      _morningTime = TimeOfDay(
        hour: prefs.getInt('reminder_morning_hour') ?? 6,
        minute: prefs.getInt('reminder_morning_minute') ?? 0,
      );
      _eveningTime = TimeOfDay(
        hour: prefs.getInt('reminder_evening_hour') ?? 17,
        minute: prefs.getInt('reminder_evening_minute') ?? 0,
      );
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

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_morning_enabled', _morningEnabled);
    await prefs.setBool('reminder_evening_enabled', _eveningEnabled);
    await prefs.setInt('reminder_morning_hour', _morningTime.hour);
    await prefs.setInt('reminder_morning_minute', _morningTime.minute);
    await prefs.setInt('reminder_evening_hour', _eveningTime.hour);
    await prefs.setInt('reminder_evening_minute', _eveningTime.minute);
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
