import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/quran_audio_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.syncDailyRemindersFromSettings();

  // تهيئة مشغل القرآن مرة واحدة على مستوى التطبيق.
  try {
    await QuranAudioService.init();
  } catch (e) {
    debugPrint('فشلت تهيئة مشغل القرآن: $e');
  }

  // قراءة الثيم المحفوظ قبل بناء الواجهة لمنع ظهور وميض بلون مختلف
  final prefs = await SharedPreferences.getInstance();
  final bool initialDarkMode = prefs.getBool('theme_is_dark_mode') ?? true;

  runApp(AdhkariApp(initialDarkMode: initialDarkMode));
}

class AdhkariApp extends StatefulWidget {
  final bool initialDarkMode;

  const AdhkariApp({super.key, required this.initialDarkMode});

  @override
  State<AdhkariApp> createState() => _AdhkariAppState();
}

class _AdhkariAppState extends State<AdhkariApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialDarkMode;
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
    _persistTheme();
  }

  Future<void> _persistTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark_mode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أذكاري - Adhkari',
      debugShowCheckedModeBanner: false,
      theme: AppThemeData.light,
      darkTheme: AppThemeData.dark,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: CustomSplashScreen(toggleTheme: _toggleTheme),
    );
  }
}