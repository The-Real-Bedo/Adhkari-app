import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/tasbih_stat_item.dart';

class TasbihHome extends StatefulWidget {
  const TasbihHome({super.key});
  @override
  State<TasbihHome> createState() => _TasbihHomeState();
}

class _TasbihHomeState extends State<TasbihHome>
    with SingleTickerProviderStateMixin {
  int _counter = 0;
  int _totalCounter = 0;
  int _dailyCounter = 0; // جديد: العداد اليومي
  String _lastDailyReset = ''; // جديد: آخر يوم
  int _index = 0;
  int _target = 33;
  int _dailyTarget = 1000;
  bool _soundEnabled = false;
  bool _hapticEnabled = true;
  bool _dailyGoalCelebrated = false;
  String _counterStyle = 'circle';
  List<Map<String, dynamic>> _activityLog = [];

  late AnimationController _celebrationController;
  bool _showCelebration = false;
  String _currentCelebrationMessage = "";
  Color _currentCelebrationColor = Colors.blue;
  bool _showTip = true;

  List<Map<String, dynamic>> _azkar = [
    {
      'text': "سُبْحَانَ اللَّهِ",
      'color': Colors.blueAccent,
      'isCustom': false,
    },
    {'text': "الْحَمْدُ لِلَّهِ", 'color': Colors.green, 'isCustom': false},
    {
      'text': "لَا إِلٰهَ إِلَّا اللَّهُ",
      'color': Colors.redAccent,
      'isCustom': false,
    },
    {
      'text': "اللَّهُ أَكْبَرُ",
      'color': Colors.orangeAccent,
      'isCustom': false,
    },
    {
      'text': "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّه",
      'color': Colors.indigo,
      'isCustom': false,
    },
    {
      'text': "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
      'color': Colors.lightBlue,
      'isCustom': false,
    },
    {
      'text': "سُبْحَانَ اللَّهِ الْعَظِيم",
      'color': Colors.teal,
      'isCustom': false,
    },
    {
      'text': "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ",
      'color': Colors.deepPurple,
      'isCustom': false,
    },
    {
      'text':
          "لَا إِلٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
      'color': Colors.red,
      'isCustom': false,
    },
    {
      'text':
          "حَسْبِيَ اللَّهُ لَا إِلٰهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ",
      'color': Colors.amber,
      'isCustom': false,
    },
    {
      'text':
          "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ",
      'color': Colors.cyan,
      'isCustom': false,
    },
    {
      'text':
          "لَا إِلٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ",
      'color': Colors.greenAccent,
      'isCustom': false,
    },
    {
      'text': "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ",
      'color': Colors.blue,
      'isCustom': false,
    },
    {
      'text':
          "اللَّهُمَّ اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ وَالْمُؤْمِنَاتِ",
      'color': Colors.brown,
      'isCustom': false,
    },
    {
      'text': "اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّد",
      'color': Colors.pink,
      'isCustom': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _loadData();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  // جديد: فحص وإعادة تعيين العداد اليومي
  Future<void> _checkAndResetDaily() async {
    String today = DateTime.now().toString().split(' ')[0];
    if (_lastDailyReset != today) {
      setState(() {
        _dailyCounter = 0;
        _lastDailyReset = today;
        _dailyGoalCelebrated = false;
      });
      await _saveData();
    }
  }

  _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // جديد: فحص إذا كانت الرسالة ظهرت من قبل
    bool? tipShown = prefs.getBool('tasbih_tip_shown');

    setState(() {
      _totalCounter = (prefs.getInt('totalCounter') ?? 0);
      _dailyCounter = (prefs.getInt('dailyCounter') ?? 0); // جديد
      _lastDailyReset = (prefs.getString('lastDailyReset') ?? ''); // جديد
      _counter = (prefs.getInt('counter') ?? 0);
      _index = (prefs.getInt('index') ?? 0);
      _target = (prefs.getInt('target') ?? 33);
      _dailyTarget = (prefs.getInt('dailyTasbihTarget') ?? 1000);
      _soundEnabled = (prefs.getBool('tasbihSoundEnabled') ?? false);
      _hapticEnabled = (prefs.getBool('tasbihHapticEnabled') ?? true);
      _dailyGoalCelebrated = (prefs.getBool('dailyGoalCelebrated') ?? false);
      _counterStyle = (prefs.getString('counterStyle') ?? 'circle');
      _showTip = tipShown == null; // جديد: إذا null يعني أول مرة

      // جديد: تحميل الأذكار المخصصة
      String? savedAzkar = prefs.getString('customAzkar');
      if (savedAzkar != null) {
        try {
          List<dynamic> decoded = jsonDecode(savedAzkar);
          _azkar = decoded.map((e) {
            return {
              'text': e['text'],
              'color': Color(e['color']),
              'isCustom': e['isCustom'] ?? false,
            };
          }).toList();
        } catch (e) {
          // في حالة خطأ، نستخدم الأذكار الافتراضية
        }
      }

      String? logString = prefs.getString('activityLog');
      if (logString != null) {
        List<dynamic> decoded = jsonDecode(logString);
        _activityLog = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    });

    // جديد: فحص وإعادة تعيين اليومي
    await _checkAndResetDaily();
  }

  _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter', _counter);
    await prefs.setInt('totalCounter', _totalCounter);
    await prefs.setInt('dailyCounter', _dailyCounter); // جديد
    await prefs.setString('lastDailyReset', _lastDailyReset); // جديد
    await prefs.setInt('index', _index);
    await prefs.setInt('target', _target);
    await prefs.setInt('dailyTasbihTarget', _dailyTarget);
    await prefs.setBool('tasbihSoundEnabled', _soundEnabled);
    await prefs.setBool('tasbihHapticEnabled', _hapticEnabled);
    await prefs.setBool('dailyGoalCelebrated', _dailyGoalCelebrated);
    await prefs.setString('counterStyle', _counterStyle);
    await prefs.setString('activityLog', jsonEncode(_activityLog));

    // جديد: حفظ الأذكار المخصصة
    List<Map<String, dynamic>> azkarToSave = _azkar.map((e) {
      return {
        'text': e['text'],
        'color': (e['color'] as Color).value,
        'isCustom': e['isCustom'],
      };
    }).toList();
    await prefs.setString('customAzkar', jsonEncode(azkarToSave));

    // جديد: حفظ أن الرسالة ظهرت
    if (!_showTip) {
      await prefs.setBool('tasbih_tip_shown', true);
    }
  }

  void _addToActivityLog(String zikrText, int count) {
    setState(() {
      _activityLog.insert(0, {
        'zikr': zikrText,
        'count': count,
        'time': DateTime.now().toString(),
      });

      if (_activityLog.length > 50) {
        _activityLog = _activityLog.sublist(0, 50);
      }
    });
    _saveData();
  }

  void _showCelebrationAnimation() {
    if (_showCelebration) return;

    final messages = [
      "تَقَبَّلَ اللَّهُ مِنْكَ",
      "بَارَكَ اللَّهُ فِيكَ",
      "جَزَاكَ اللَّهُ خَيْرًا",
      "أَحْسَنَ اللَّهُ إِلَيْكَ",
      "رَفَعَ اللَّهُ قَدْرَكَ",
    ];
    _currentCelebrationMessage =
        messages[DateTime.now().millisecond % messages.length];
    _currentCelebrationColor = _azkar[_index]['color'];

    setState(() => _showCelebration = true);
    _celebrationController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() => _showCelebration = false);
      }
    });
  }

  void _increment() {
    if (_hapticEnabled) {
      HapticFeedback.lightImpact();
    }
    if (_soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }

    // معدل: حفظ حالة التلميح
    if (_showTip) {
      setState(() => _showTip = false);
      _saveData(); // جديد: حفظ
    }

    setState(() {
      final previousDailyCounter = _dailyCounter;
      _counter++;
      _totalCounter++;
      _dailyCounter++; // جديد: زيادة العداد اليومي

      if (_counter >= _target) {
        _addToActivityLog(_azkar[_index]['text'], _target);
        _showCelebrationAnimation();
        _counter = 0;
        _index = (_index + 1) % _azkar.length;
        if (_hapticEnabled) {
          HapticFeedback.vibrate();
        }
      }

      if (!_dailyGoalCelebrated &&
          previousDailyCounter < _dailyTarget &&
          _dailyCounter >= _dailyTarget) {
        _dailyGoalCelebrated = true;
        Future.delayed(const Duration(milliseconds: 250), _showDailyGoalDialog);
      }
    });
    _saveData();
  }

  // جديد: إضافة ذكر مخصص
  void _showAddCustomZikr() {
    String newZikr = '';
    Color selectedColor = Colors.blueAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);

    final List<Color> availableColors = [
      Colors.blueAccent,
      Colors.green,
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.indigo,
      Colors.lightBlue,
      Colors.teal,
      Colors.deepPurple,
      Colors.red,
      Colors.amber,
      Colors.cyan,
      Colors.greenAccent,
      Colors.pink,
      Colors.brown,
      Colors.lime,
      Colors.deepOrange,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("إضافة ذكر جديد", textAlign: TextAlign.right),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "اكتب الذكر هنا...",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => newZikr = value,
                ),
                const SizedBox(height: 20),
                const Text(
                  "اختر اللون:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableColors.map((color) {
                    bool isSelected = color == selectedColor;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.6),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              onPressed: () {
                if (newZikr.trim().isNotEmpty) {
                  setState(() {
                    _azkar.add({
                      'text': newZikr.trim(),
                      'color': selectedColor,
                      'isCustom': true,
                    });
                  });
                  _saveData();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم إضافة الذكر بنجاح ✓")),
                  );
                }
              },
              child: const Text("إضافة"),
            ),
          ],
        ),
      ),
    );
  }

  // جديد: حذف ذكر مخصص
  void _deleteCustomZikr(int index) {
    if (_azkar[index]['isCustom'] == true) {
      setState(() {
        if (_index == index) {
          _index = 0;
          _counter = 0;
        } else if (_index > index) {
          _index--;
        }
        _azkar.removeAt(index);
      });
      _saveData();
    }
  }

  void _showActivityLog() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1a1a1a) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF0F0F0),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Text(
                    "سجل الطاعات",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _activityLog.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "لا يوجد سجل بعد",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "ابدأ بالتسبيح لرؤية السجل هنا",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _activityLog.length,
                      itemBuilder: (context, index) {
                        final log = _activityLog[index];
                        DateTime time = DateTime.parse(log['time']);
                        String timeStr =
                            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                        String dateStr =
                            "${time.day}/${time.month}/${time.year}";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      const Color(0xFF1a1a1a),
                                      const Color(0xFF0f0f0f),
                                    ]
                                  : [Colors.white, const Color(0xFFFAFAFA)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.greenAccent.withValues(
                                              alpha: 0.1,
                                            )
                                          : const Color(
                                              0xFF2E7D32,
                                            ).withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 14,
                                          color: isDark
                                              ? Colors.greenAccent
                                              : const Color(0xFF2E7D32),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "أتممت ${log['count']} مرة",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.greenAccent
                                                : const Color(0xFF2E7D32),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "$dateStr | $timeStr",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),

                              Divider(
                                height: 20,
                                color: isDark
                                    ? Colors.white10
                                    : const Color(0xFFE0E0E0),
                              ),

                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  log['zikr'],
                                  textAlign: TextAlign.right,
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF212121),
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDailyGoalDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("إنجاز اليوم", textAlign: TextAlign.right),
        content: Text(
          "أتممت هدف التسبيح اليومي: $_dailyTarget مرة. بارك الله فيك.",
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("الحمد لله"),
          ),
        ],
      ),
    );
  }

  void _showTasbihSettings() {
    final TextEditingController targetController = TextEditingController(
      text: _dailyTarget.toString(),
    );
    String selectedStyle = _counterStyle;
    bool soundEnabled = _soundEnabled;
    bool hapticEnabled = _hapticEnabled;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAccent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    const Text(
                      "إعدادات التسبيح",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  "شكل العداد",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStyleChoice("دائرة", "circle", selectedStyle, (
                      value,
                    ) {
                      setSheetState(() => selectedStyle = value);
                    }),
                    _buildStyleChoice("مسبحة", "beads", selectedStyle, (value) {
                      setSheetState(() => selectedStyle = value);
                    }),
                    _buildStyleChoice("بسيط", "simple", selectedStyle, (value) {
                      setSheetState(() => selectedStyle = value);
                    }),
                  ],
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  value: soundEnabled,
                  activeColor: settingsAccent,
                  title: const Text(
                    "صوت خفيف عند الضغط",
                    textAlign: TextAlign.right,
                  ),
                  onChanged: (value) =>
                      setSheetState(() => soundEnabled = value),
                ),
                SwitchListTile(
                  value: hapticEnabled,
                  activeColor: settingsAccent,
                  title: const Text(
                    "اهتزاز عند الضغط",
                    textAlign: TextAlign.right,
                  ),
                  onChanged: (value) =>
                      setSheetState(() => hapticEnabled = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: "هدف التسبيح اليومي",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final customTarget = int.tryParse(
                        targetController.text.trim(),
                      );
                      setState(() {
                        _counterStyle = selectedStyle;
                        _soundEnabled = soundEnabled;
                        _hapticEnabled = hapticEnabled;
                        if (customTarget != null && customTarget > 0) {
                          _dailyTarget = customTarget;
                          _dailyGoalCelebrated = _dailyCounter >= _dailyTarget;
                        }
                      });
                      _saveData();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: settingsAccent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("حفظ"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStyleChoice(
    String label,
    String value,
    String selectedStyle,
    ValueChanged<String> onSelected,
  ) {
    final bool selected = selectedStyle == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: accent,
      labelStyle: TextStyle(
        color: selected ? (isDark ? Colors.black : Colors.white) : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  Color _readableColor(Color color, bool isDark) {
    if (isDark) return color;

    if (color == Colors.cyanAccent ||
        color == Colors.cyan ||
        color == Colors.lightBlue) {
      return const Color(0xFF007C89);
    }
    if (color == Colors.greenAccent || color == Colors.green) {
      return const Color(0xFF2E7D32);
    }
    if (color == Colors.orangeAccent ||
        color == Colors.amber ||
        color == Colors.lime) {
      return const Color(0xFFC15F00);
    }
    if (color == Colors.blueAccent || color == Colors.blue) {
      return const Color(0xFF1565C0);
    }
    if (color == Colors.redAccent || color == Colors.red) {
      return const Color(0xFFC62828);
    }
    if (color == Colors.pink) {
      return const Color(0xFFAD1457);
    }
    if (color == Colors.teal) {
      return const Color(0xFF00796B);
    }
    if (color == Colors.deepPurple) {
      return const Color(0xFF5E35B1);
    }
    if (color == Colors.indigo) {
      return const Color(0xFF3949AB);
    }

    return color;
  }

  void _showTargetPicker() {
    TextEditingController customController = TextEditingController();
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color currentColor = _azkar[_index]['color'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? [const Color(0xFF1a1a1a), const Color(0xFF0d0d0d)]
                  : [Colors.white, const Color(0xFFF5F5F5)],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.5)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              currentColor.withOpacity(0.15),
                              currentColor.withOpacity(0.05),
                            ]
                          : [
                              currentColor.withOpacity(0.08),
                              currentColor.withOpacity(0.03),
                            ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(23),
                      topRight: Radius.circular(23),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: currentColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: currentColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.flag_rounded,
                          color: currentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "تحديد الهدف",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildQuickOption(
                        " مــ33ــرّة",
                        33,
                        currentColor,
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickOption(
                        " مــ100ــرّة",
                        100,
                        currentColor,
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickOption(
                        " مــ500ــرّة",
                        500,
                        currentColor,
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickOption(
                        " مــ1000ــرّة",
                        1000,
                        currentColor,
                        isDark,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: currentColor.withOpacity(0.3),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Text(
                              "أو",
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: currentColor.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "أدخل عدد مخصص",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: customController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: currentColor,
                        ),
                        decoration: InputDecoration(
                          hintText: "مثال: 50",
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: currentColor.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: currentColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "إلغاء",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                int? custom = int.tryParse(
                                  customController.text,
                                );
                                if (custom != null && custom > 0) {
                                  _updateTarget(custom);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "تأكيد",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOption(String label, int value, Color color, bool isDark) {
    bool isSelected = _target == value;
    return GestureDetector(
      onTap: () => _updateTarget(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : (isDark
                    ? Colors.white.withOpacity(0.03)
                    : const Color(0xFFF8F8F8)),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.5)
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: isSelected
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.2),
                    )
                  : null,
              child: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white30 : Colors.black26),
                size: 24,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTarget(int newTarget) {
    setState(() {
      _target = newTarget;
      _counter = 0;
    });
    _saveData();
    Navigator.pop(context);
  }

  void _showZikrPicker() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.cyanAccent : const Color(0xFF007C89);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Column(
        children: [
          // جديد: زر إضافة ذكر
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF0F0F0),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "الأذكار المتاحة",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: accent, size: 28),
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddCustomZikr();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _azkar.length,
              itemBuilder: (context, i) {
                bool isCustom = _azkar[i]['isCustom'] == true;
                return ListTile(
                  title: Text(
                    _azkar[i]['text'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _readableColor(_azkar[i]['color'], isDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  trailing: isCustom
                      ? IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 22,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteCustomZikr(i);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("تم حذف الذكر ✓")),
                            );
                          },
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _index = i;
                      _counter = 0;
                    });
                    _saveData();
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // معدل: إعادة ضبط مع خيارات
  void _showResetOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("إعادة ضبط الإحصائيات", textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // خيار 1
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text("إعادة العداد الحالي"),
              subtitle: const Text("تصفير العداد والذكر فقط"),
              onTap: () {
                setState(() {
                  _counter = 0;
                  _index = 0;
                });
                _saveData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم إعادة العداد ✓")),
                );
              },
            ),
            const Divider(),
            // خيار 2
            ListTile(
              leading: const Icon(Icons.today, color: Colors.orange),
              title: const Text("إعادة الإحصائيات اليومية"),
              subtitle: const Text("تصفير العداد اليومي فقط"),
              onTap: () {
                setState(() => _dailyCounter = 0);
                _saveData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم إعادة العداد اليومي ✓")),
                );
              },
            ),
            const Divider(),
            // خيار 3
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("إعادة كل الإحصائيات"),
              subtitle: const Text("تصفير كل شيء + السجل"),
              onTap: () {
                Navigator.pop(context);
                _confirmResetAll();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
        ],
      ),
    );
  }

  // جديد: تأكيد إعادة الضبط الكامل
  void _confirmResetAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ تأكيد", textAlign: TextAlign.right),
        content: const Text(
          "هل أنت متأكد من حذف كل الإحصائيات والسجل؟",
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _counter = 0;
                _totalCounter = 0;
                _dailyCounter = 0;
                _index = 0;
                _dailyGoalCelebrated = false;
                _activityLog.clear();
              });
              _saveData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("تم حذف كل الإحصائيات ✓")),
              );
            },
            child: const Text("تأكيد", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color currentColor = _readableColor(_azkar[_index]['color'], isDark);
    final orange = isDark ? Colors.orangeAccent : const Color(0xFFC15F00);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: SizedBox(
                height:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    // معدل: إضافة العداد اليومي
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TasbihStatItem(
                          label: "الإجمالي اليومي",
                          value: "$_dailyCounter",
                          color: orange,
                          isDark: isDark,
                        ),
                        TasbihStatItem(
                          label: "الإجمالي طوال الوقت",
                          value: "$_totalCounter",
                          color: currentColor,
                          isDark: isDark,
                        ),
                        TasbihStatItem(
                          label: "الهدف",
                          value: "$_target",
                          color: currentColor,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: currentColor.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: "إعدادات التسبيح",
                              icon: Icon(Icons.tune, color: currentColor),
                              onPressed: _showTasbihSettings,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "هدف اليوم: $_dailyCounter / $_dailyTarget",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: (_dailyCounter / _dailyTarget)
                                          .clamp(0.0, 1.0)
                                          .toDouble(),
                                      minHeight: 7,
                                      color: currentColor,
                                      backgroundColor: isDark
                                          ? Colors.white10
                                          : Colors.black12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    InkWell(
                      onTap: _showZikrPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                _azkar[_index]['text'],
                                key: ValueKey(_index),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  color: currentColor.withOpacity(0.9),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "انقر لتغيير الذكر أو اضافة ذكر جديد",
                              style: TextStyle(
                                color: isDark ? Colors.white24 : Colors.black26,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: _increment,
                      child: _buildCounterSurface(currentColor, isDark),
                    ),
                    const Expanded(child: SizedBox()),
                    // معدل: زر إعادة الضبط مع خيارات
                    TextButton.icon(
                      onPressed: _showResetOptions,
                      icon: Icon(
                        Icons.refresh,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      label: Text(
                        "إعادة ضبط الإحصائيات",
                        style: TextStyle(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),

            if (_showCelebration)
              Positioned(
                top: 120,
                left: 20,
                right: 20,
                child: IgnorePointer(
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, -2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _celebrationController,
                            curve: Curves.elasticOut,
                          ),
                        ),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _celebrationController,
                          curve: const Interval(0.0, 0.3),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              _currentCelebrationColor,
                              _currentCelebrationColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _currentCelebrationColor.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _currentCelebrationColor.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mosque,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _currentCelebrationMessage,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterSurface(Color currentColor, bool isDark) {
    final progress = (_counter / _target).clamp(0.0, 1.0).toDouble();
    final bool simple = _counterStyle == 'simple';

    Widget counterBody;
    if (_counterStyle == 'beads') {
      counterBody = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 250,
        height: 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF121212) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: currentColor.withValues(alpha: 0.16),
              blurRadius: 38,
            ),
          ],
          border: Border.all(color: currentColor.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: List.generate(33, (index) {
                final active = index < ((_counter / _target) * 33).ceil();
                return Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? currentColor
                        : currentColor.withValues(alpha: 0.14),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Text(
              '$_counter',
              style: TextStyle(
                fontSize: 70,
                color: currentColor,
                fontWeight: FontWeight.w100,
              ),
            ),
          ],
        ),
      );
    } else if (simple) {
      counterBody = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 280,
        height: 190,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: currentColor.withValues(alpha: 0.14),
              blurRadius: 34,
            ),
          ],
          border: Border.all(color: currentColor.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_counter',
              style: TextStyle(
                fontSize: 82,
                color: currentColor,
                fontWeight: FontWeight.w100,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: currentColor,
                backgroundColor: currentColor.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      );
    } else {
      counterBody = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: currentColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(currentColor),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF121212) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: currentColor.withValues(alpha: 0.15),
                  blurRadius: 40,
                ),
              ],
              border: Border.all(color: currentColor.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                '$_counter',
                style: TextStyle(
                  fontSize: 85,
                  color: currentColor,
                  fontWeight: FontWeight.w100,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: 300,
      height: simple ? 250 : 310,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          counterBody,
          Positioned(
            top: simple ? 6 : 25,
            right: simple ? 12 : 25,
            child: IconButton(
              tooltip: "هدف الذكر",
              icon: Icon(
                Icons.flag,
                color: currentColor.withValues(alpha: 0.65),
              ),
              onPressed: _showTargetPicker,
            ),
          ),
          Positioned(
            top: simple ? 6 : 25,
            left: simple ? 12 : 25,
            child: IconButton(
              tooltip: "سجل الطاعات",
              icon: Icon(
                Icons.history,
                color: currentColor.withValues(alpha: 0.65),
              ),
              onPressed: _showActivityLog,
            ),
          ),
          if (_showTip && _counter == 0)
            Positioned(
              bottom: -42,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'اضغط على العداد لبدء العد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() => _showTip = false);
                        _saveData();
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
