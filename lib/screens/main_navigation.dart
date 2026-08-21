import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'azkar_screen.dart';
import 'quran/mushaf_index_screen.dart';
import 'quran/quran_player_screen.dart';
import 'quran/reciters_screen.dart';
import 'settings_screen.dart';
import 'tasbih_screen.dart';
import 'today_screen.dart';

class MainNavigation extends StatefulWidget {
  final VoidCallback toggleTheme;
  const MainNavigation({super.key, required this.toggleTheme});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // أرقام التبويبات مسمّاة عن قصد: شاشة "اليوم" بتنقل للتبويبات بالرقم،
  // وأي تبويب جديد بيتحط في النص كان بيزحزح الأرقام ويودّي على شاشة غلط
  // من غير أي خطأ في التحليل.
  static const int _tabToday = 0;
  static const int _tabTasbih = 1;
  static const int _tabAzkar = 2;
  static const int _tabMushaf = 3;
  static const int _tabQuran = 4;
  static const int _tabSettings = 5;

  int _selectedIndex = _tabToday;
  double _fontSize = 18.0;
  bool _showSlider = false;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSize = prefs.getDouble('azkar_font_size') ?? 18.0;
    });
  }

  Future<void> _persistFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('azkar_font_size', _fontSize);
  }

  void _openPage(int index) {
    setState(() {
      _selectedIndex = index;
      _showSlider = false;
    });
  }

  /// الشاشة بتتبنى بالرقم صراحة، فالربط بين رقم التبويب وشاشته مكتوب في
  /// مكان واحد. وكده كمان بنبني الشاشة المعروضة بس، مش الستة كلهم كل
  /// مرة الـ build يتنده زي قبل كده.
  Widget _pageFor(int index) {
    switch (index) {
      case _tabToday:
        return TodayScreen(
          openTasbih: () => _openPage(_tabTasbih),
          openAzkar: () => _openPage(_tabAzkar),
          openQuran: () => _openPage(_tabQuran),
          openSettings: () => _openPage(_tabSettings),
        );
      case _tabTasbih:
        return const TasbihHome();
      case _tabAzkar:
        return AzkarPage(fontSize: _fontSize);
      case _tabMushaf:
        return const MushafIndexScreen();
      case _tabQuran:
        return const RecitersScreen();
      case _tabSettings:
        return SettingsScreen(toggleTheme: widget.toggleTheme);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _pageFor(_selectedIndex)),
          MiniPlayer(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const QuranPlayerScreen.current(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex != _tabAzkar
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showSlider)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(30),
                      // حدود بدل الظلال — نفس أسلوب الموقع المرجعي
                      border: Border.all(color: p.border),
                    ),
                    height: 200,
                    width: 50,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: _fontSize,
                        min: 14,
                        max: 35,
                        activeColor: p.primary,
                        inactiveColor: p.textFaint,
                        onChanged: (val) => setState(() => _fontSize = val),
                        onChangeEnd: (_) => _persistFontSize(),
                      ),
                    ),
                  ),
                FloatingActionButton(
                  heroTag: "fontBtn",
                  backgroundColor: _showSlider ? p.danger : p.primary,
                  onPressed: () => setState(() => _showSlider = !_showSlider),
                  child: _showSlider
                      ? Icon(Icons.close, color: p.onPrimary)
                      : Text(
                          "A",
                          style: TextStyle(
                            color: p.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _openPage,
        type: BottomNavigationBarType.fixed,
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textFaint,
        elevation: 0,
        // ستة تبويبات محتاجة خط أصغر شوية عشان الكلام مايتقطعش على
        // الشاشات الضيقة
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: "اليوم"),
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint),
            label: "تسبيح",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "أذكار"),
          // المصحف بقى تبويب بنفسه بدل أيقونة صغيرة جوه شاشة الاستماع —
          // قبل كده كان مستحيل حد ياخد باله إن في مصحف أصلًا.
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories),
            label: "المصحف",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.headphones), label: "قرآن"),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: "إعدادات"),
        ],
      ),
    );
  }
}
