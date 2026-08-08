import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
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
    final p = context.palette;

    final List<Widget> pages = [
      TodayScreen(
        openTasbih: () => _openPage(1),
        openAzkar: () => _openPage(2),
        openQuran: () => _openPage(3),
        openSettings: () => _openPage(4),
      ),
      const TasbihHome(),
      AzkarPage(fontSize: _fontSize),
      const RecitersScreen(),
      SettingsScreen(toggleTheme: widget.toggleTheme),
    ];

    return Scaffold(
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
                  backgroundColor:
                      _showSlider ? p.danger : p.primary,
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
