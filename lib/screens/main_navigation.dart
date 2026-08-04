import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'today_screen.dart';
import 'tasbih_screen.dart';
import 'azkar_screen.dart';
import 'settings_screen.dart';
import 'quran/reciters_screen.dart';
import 'quran/quran_player_screen.dart';
import '../widgets/mini_player.dart';

class MainNavigation extends StatefulWidget {
  final VoidCallback toggleTheme;
  const MainNavigation({super.key, required this.toggleTheme});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
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

  @override
  Widget build(BuildContext context) {
    // نقرأ الثيم من الـ context مباشرة زي باقي الشاشات، لأن تمريره
    // كـ parameter كان بيتجمد على قيمة وقت بناء الصفحة ولا يتحدث بعدها
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color navAccent = isDarkMode
        ? Colors.cyanAccent
        : const Color(0xFF00838F);

    final List<Widget> pages = [
      TodayScreen(
        openTasbih: () => _openPage(1),
        openAzkar: () => _openPage(2),
        openQuran: () => _openPage(3),
        // الإعدادات بقت رقم 4 بعد إضافة تبويب القرآن في رقم 3
        openSettings: () => _openPage(4),
      ),
      const TasbihHome(),
      AzkarPage(fontSize: _fontSize),
      const RecitersScreen(),
      // زرار الوضع الليلي بقى جوه الإعدادات بدل ما كان زرار عايم
      SettingsScreen(toggleTheme: widget.toggleTheme),
    ];

    return Scaffold(
      // الشريط المصغر بيتحط جوه Column مع الصفحة عشان يفضل ظاهر
      // في كل التبويبات طول ما فيه تلاوة شغالة
      body: Column(
        children: [
          Expanded(child: pages[_selectedIndex]),
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
      // الزرار العايم بقى لتكبير خط الأذكار بس — زرار الثيم اتنقل للإعدادات.
      // فبنبنيه فقط في تبويب الأذكار عشان مايظهرش في باقي التبويبات.
      floatingActionButton: _selectedIndex != 2
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showSlider)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    height: 200,
                    width: 50,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: _fontSize,
                        min: 14,
                        max: 35,
                        activeColor: navAccent,
                        onChanged: (val) => setState(() => _fontSize = val),
                        // الحفظ عند رفع الإصبع فقط، لا مع كل حركة أثناء السحب
                        onChangeEnd: (_) => _persistFontSize(),
                      ),
                    ),
                  ),
                FloatingActionButton(
                  heroTag: "fontBtn",
                  backgroundColor: _showSlider ? Colors.redAccent : navAccent,
                  onPressed: () => setState(() => _showSlider = !_showSlider),
                  child: _showSlider
                      ? const Icon(Icons.close, color: Colors.white)
                      : const Text(
                          "A",
                          style: TextStyle(
                            color: Colors.black,
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
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : Colors.white,
        selectedItemColor: navAccent,
        unselectedItemColor: isDarkMode ? Colors.white24 : Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: "اليوم"),
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint),
            label: "تسبيح",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "أذكار"),
          BottomNavigationBarItem(icon: Icon(Icons.headphones), label: "قرآن"),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: "إعدادات"),
        ],
      ),
    );
  }
}
