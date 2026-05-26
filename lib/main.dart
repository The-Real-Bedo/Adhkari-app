import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.syncDailyRemindersFromSettings();

  runApp(const AdhkariApp());
}
class AdhkariApp extends StatefulWidget {
  const AdhkariApp({super.key});

  @override
  State<AdhkariApp> createState() => _AdhkariAppState();
}

class _AdhkariAppState extends State<AdhkariApp> {
  bool _isDarkMode = true;
  void _toggleTheme() => setState(() => _isDarkMode = !_isDarkMode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أذكاري - Adhkari',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFE3F2FD),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFBBDEFB),
          foregroundColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121212)),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: CustomSplashScreen(
        isDarkMode: _isDarkMode,
        toggleTheme: _toggleTheme,
      ),
    );
  }
}