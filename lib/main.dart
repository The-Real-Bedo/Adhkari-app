import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/splash_screen.dart';
import 'services/habit_tracker_service.dart';
import 'services/hijri_prefs.dart';
import 'services/khatmah_service.dart';
import 'services/home_widget_service.dart';
import 'services/mushaf_prefs.dart';
import 'services/notification_service.dart';
import 'services/quran_audio_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerFontLicenses();

  late final SharedPreferences prefs;
  await Future.wait([
    SharedPreferences.getInstance().then((p) {
      prefs = p;
    }),
    HijriPrefs.load(),
    MushafPrefs.load(),
    KhatmahService.load(),
    HabitTrackerService.load(),
  ]);

  final bool initialDarkMode = prefs.getBool('theme_is_dark_mode') ?? false;

  runApp(AdhkariApp(initialDarkMode: initialDarkMode));

  _initHeavyServicesAfterFirstFrame();
}

void _initHeavyServicesAfterFirstFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      await NotificationService.init();
      await NotificationService.syncDailyRemindersFromSettings();
    } catch (e) {
      debugPrint('فشلت تهيئة التنبيهات: $e');
    }

    await QuranAudioService.ensureReady();
    await HomeWidgetService.updateAll();
  });
}

/// رخصة OFL لكل خط مبني في التطبيق.
///
/// الرخصة بتقول لازم نصها يتوزّع مع الخط، فبنسجّلها في `LicenseRegistry`
/// وبتظهر في صفحة التراخيص. المولّد ده lazy — مابيقراش الملفات غير لما
/// المستخدم يفتح الصفحة فعلًا، يعني مايكلّفش حاجة وقت التشغيل.
void _registerFontLicenses() {
  const Map<String, String> fontLicenses = {
    'Cairo': 'assets/licenses/OFL-Cairo.txt',
    'Amiri': 'assets/licenses/OFL-Amiri.txt',
    'Scheherazade New': 'assets/licenses/OFL-ScheherazadeNew.txt',
    'Raleway': 'assets/licenses/OFL-Raleway.txt',
  };

  LicenseRegistry.addLicense(() async* {
    for (final MapEntry<String, String> entry in fontLicenses.entries) {
      yield LicenseEntryWithLineBreaks(
        [entry.key],
        await rootBundle.loadString(entry.value),
      );
    }
  });
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

      // التطبيق عربي بالكامل. من غير الأسطر دي فلاتر بيقع على لغة الجهاز —
      // واللي طلعت en-EG على جهاز الاختبار — يعني كل widgets الماتيريال
      // (منتقي الوقت في الإعدادات، التلميحات، أزرار الحوار) بتظهر إنجليزي،
      // و Localizations نفسها بتدّي اتجاه LTR.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // مقفولة على RTL صراحة كمان عشان الاتجاه ميعتمدش على إعداد ممكن يتغير
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: CustomSplashScreen(toggleTheme: _toggleTheme),
    );
  }
}
