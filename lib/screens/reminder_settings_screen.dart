import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  bool _morningEnabled = true;
  bool _eveningEnabled = true;
  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

  Future<void> _sendTestNotification() async {
    await NotificationService.showInstantTest();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال إشعار تجريبي')),
    );
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              children: [
                _SettingsHeader(isDark: isDark),
                const SizedBox(height: 16),
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
                const SizedBox(height: 12),
                _NoteCard(isDark: isDark, onTest: _sendTestNotification),
              ],
            ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final bool isDark;

  const _SettingsHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: isDark ? Colors.amberAccent : const Color(0xFFB7791F),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'مواعيد التذكير',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر وقت الصباح والمساء من داخل التطبيق',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
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
  final VoidCallback onTest;

  const _NoteCard({required this.isDark, required this.onTest});

  @override
  Widget build(BuildContext context) {
    final Color accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'لو التنبيه لم يظهر، تأكد من السماح للتطبيق بالتنبيهات من إعدادات الهاتف.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTest,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('إرسال إشعار تجريبي الآن'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.5)),
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
