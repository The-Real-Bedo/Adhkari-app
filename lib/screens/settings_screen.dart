import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/quran_download_service.dart';
import 'quran/downloads_screen.dart';

/// شاشة الإعدادات — بقت مقسومة أقسام: المظهر، التذكير، التلاوات، معلومات.
///
/// الوضع الليلي كان زرار عايم فوق كل الشاشات، نقلناه هنا عشان يبقى
/// مكانه منطقي ومايغطيش على المحتوى.
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

  /// حجم التلاوات المحمّلة — بنعرضه في قسم التلاوات
  int _downloadBytes = 0;
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
      setState(() {
        _downloadCount = files.length;
        _downloadBytes = files.fold<int>(0, (sum, f) => sum + f.bytes);
      });
    } catch (_) {
      // مش مشكلة، القسم هيعرض صفر
    }
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات التذكير')));
  }

  Future<void> _pickTime({required bool isMorning}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isMorning ? _morningTime : _eveningTime,
    );

    if (picked == null) return;

    setState(() {
      if (isMorning) {
        _morningTime = picked;
      } else {
        _eveningTime = picked;
      }
    });
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final morningColor = isDark ? Colors.orangeAccent : const Color(0xFFC15F00);
    final eveningColor = isDark ? Colors.cyanAccent : const Color(0xFF007C89);
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF00838F);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                children: [
                  // ————— المظهر —————
                  const _SectionTitle('المظهر'),
                  _Card(
                    isDark: isDark,
                    child: _ThemeTile(
                      isDark: isDark,
                      onToggle: widget.toggleTheme,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ————— التذكير —————
                  const _SectionTitle('مواعيد التذكير'),
                  _ReminderCard(
                    title: 'تذكير أذكار الصباح',
                    subtitle: 'رسالة يومية هادئة لبداية الورد',
                    icon: Icons.wb_sunny_outlined,
                    color: morningColor,
                    enabled: _morningEnabled,
                    time: _morningTime,
                    isDark: isDark,
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
                    isDark: isDark,
                    onToggle: (value) async {
                      setState(() => _eveningEnabled = value);
                      await _saveSettings();
                    },
                    onPickTime: () => _pickTime(isMorning: false),
                  ),
                  const SizedBox(height: 20),

                  // ————— التلاوات —————
                  const _SectionTitle('التلاوات'),
                  _Card(
                    isDark: isDark,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.download_done, color: accent),
                      title: const Text(
                        'التلاوات المحمّلة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _downloadCount == 0
                            ? 'مفيش تلاوات محمّلة'
                            : '$_downloadCount تلاوة · '
                                  '${QuranDownloadService.formatBytes(_downloadBytes)}',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DownloadsScreen(),
                          ),
                        );
                        // ممكن يكون مسح حاجة، نحدّث الأرقام
                        await _loadDownloadInfo();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ————— معلومات —————
                  const _SectionTitle('معلومات'),
                  _NoteCard(isDark: isDark),
                ],
              ),
      ),
    );
  }
}

/// عنوان قسم صغير فوق كل مجموعة كروت
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
          color: isDark ? Colors.white38 : Colors.black45,
        ),
      ),
    );
  }
}

/// كارت بالشكل الموحّد بتاع الشاشة
class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: child,
    );
  }
}

/// سطر تبديل الوضع الليلي/النهاري
class _ThemeTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _ThemeTile({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.amberAccent : const Color(0xFF263B8F);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isDark ? Icons.dark_mode : Icons.light_mode,
        color: color,
      ),
      title: const Text(
        'الوضع الليلي',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(isDark ? 'مفعّل' : 'مغلق — الوضع النهاري'),
      trailing: Switch(
        value: isDark,
        activeThumbColor: color,
        // الـ toggle بيقلب الثيم في main.dart وبيحفظه في SharedPreferences
        onChanged: (_) => onToggle(),
      ),
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
  final bool isDark;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  const _ReminderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.time,
    required this.isDark,
    required this.onToggle,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Switch(
                value: enabled,
                activeThumbColor: color,
                onChanged: onToggle,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final bool isDark;

  const _NoteCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? Colors.cyanAccent : const Color(0xFF007C89),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لو التنبيه لم يظهر، تأكد من السماح للتطبيق بالتنبيهات من إعدادات الهاتف.',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
