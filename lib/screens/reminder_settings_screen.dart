import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

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
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: p.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.lg,
                AppSpace.lg,
                110,
              ),
              children: [
                const _SettingsHeader(),
                const SizedBox(height: AppSpace.lg),
                _ReminderCard(
                  title: 'تذكير أذكار الصباح',
                  subtitle: 'رسالة يومية هادئة لبداية الورد',
                  icon: Icons.wb_sunny_outlined,
                  color: p.accent,
                  enabled: _morningEnabled,
                  time: _morningTime,
                  onToggle: (value) async {
                    setState(() => _morningEnabled = value);
                    await _saveSettings();
                  },
                  onPickTime: () => _pickTime(isMorning: true),
                ),
                const SizedBox(height: AppSpace.md),
                _ReminderCard(
                  title: 'تذكير أذكار المساء',
                  subtitle: 'تنبيه يومي قبل نهاية اليوم',
                  icon: Icons.nights_stay_outlined,
                  color: p.primary,
                  enabled: _eveningEnabled,
                  time: _eveningTime,
                  onToggle: (value) async {
                    setState(() => _eveningEnabled = value);
                    await _saveSettings();
                  },
                  onPickTime: () => _pickTime(isMorning: false),
                ),
                const SizedBox(height: AppSpace.md),
                const _NoteCard(),
              ],
            ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: p.accent),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'مواعيد التذكير',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'اختر وقت الصباح والمساء من داخل التطبيق',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: p.textMuted),
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
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: p.border),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: p.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: enabled ? onPickTime : null,
              icon: const Icon(Icons.schedule),
              label: Text(time.format(context)),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: p.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
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
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              'لو التنبيه لم يظهر، تأكد من السماح للتطبيق بالتنبيهات من إعدادات الهاتف.',
              textAlign: TextAlign.right,
              style: TextStyle(color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
