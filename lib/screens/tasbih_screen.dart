import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/tasbih_stat_item.dart';

/// ألوان الأذكار — نغمات هادية بدل ألوان ماتيريال الفاقعة.
///
/// الأذكار المحفوظة عند المستخدم بتحمل ألوانها القديمة، فـ[calmFor]
/// بتحوّلها لأقرب نغمة من اللوحة الجديدة من غير ما نضيّع بياناته.
class ZikrColors {
  ZikrColors._();

  static const Color emerald = Color(0xFF0F6B4F);
  static const Color teal = Color(0xFF16706B);
  static const Color olive = Color(0xFF5C6B3C);
  static const Color gold = Color(0xFF9A7B1F);
  static const Color terracotta = Color(0xFFA35543);
  static const Color slate = Color(0xFF3F5A6B);
  static const Color plum = Color(0xFF6B4360);
  static const Color brown = Color(0xFF6E5138);

  static const List<Color> all = [
    emerald,
    teal,
    olive,
    gold,
    terracotta,
    slate,
    plum,
    brown,
  ];

  static const Map<int, Color> _legacy = {
    0xFF448AFF: slate, // blueAccent
    0xFF2196F3: slate, // blue
    0xFF03A9F4: teal, // lightBlue
    0xFF00BCD4: teal, // cyan
    0xFF18FFFF: teal, // cyanAccent
    0xFF4CAF50: emerald, // green
    0xFF69F0AE: emerald, // greenAccent
    0xFF009688: teal, // teal
    0xFFF44336: terracotta, // red
    0xFFFF5252: terracotta, // redAccent
    0xFFFFAB40: gold, // orangeAccent
    0xFFFFC107: gold, // amber
    0xFFCDDC39: olive, // lime
    0xFFFF5722: terracotta, // deepOrange
    0xFF3F51B5: slate, // indigo
    0xFF673AB7: plum, // deepPurple
    0xFFE91E63: plum, // pink
    0xFF795548: brown, // brown
  };

  static Color calmFor(Color color) =>
      _legacy[color.toARGB32()] ?? color;

  /// نسخة أفتح من كل نغمة للوضع الليلي.
  ///
  /// النغمات اللي فوق مختارة عشان تتقرا على سطح أبيض، فعشان كده الزمردي
  /// الغامق ده كان بيختفي تقريبًا على كارت غامق — عداد بـ ٧٠ نقطة بلون
  /// #0F6B4F على #1A201E مش بيبان. بنخزّن اللون الأصلي زي ما هو (عشان
  /// بيانات المستخدم ماتتغيّرش) وبنفتّحه وقت العرض بس.
  static const Map<int, Color> _nightTone = {
    0xFF0F6B4F: Color(0xFF52B892), // emerald
    0xFF16706B: Color(0xFF4FB8B2), // teal
    0xFF5C6B3C: Color(0xFFA6B878), // olive
    0xFF9A7B1F: Color(0xFFD9B75A), // gold
    0xFFA35543: Color(0xFFE0917D), // terracotta
    0xFF3F5A6B: Color(0xFF93B0C4), // slate
    0xFF6B4360: Color(0xFFC294B7), // plum
    0xFF6E5138: Color(0xFFC4A488), // brown
  };

  /// اللون الجاهز للعرض — بيمرّ على تحويل القديم الأول وبعدين يفتّح في الليل
  static Color visible(Color color, Brightness brightness) {
    final calm = calmFor(color);
    if (brightness != Brightness.dark) return calm;
    return _nightTone[calm.toARGB32()] ?? calm;
  }

  /// حبر مقروء فوق أي نغمة — [inkOnFill] من نظام التصميم
  static Color inkOn(Color fill) => inkOnFill(fill);
}

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
  Color _currentCelebrationColor = ZikrColors.emerald;
  bool _showTip = true;

  List<Map<String, dynamic>> _azkar = [
    {
      'text': "سُبْحَانَ اللَّهِ",
      'color': ZikrColors.emerald,
      'isCustom': false,
    },
    {
      'text': "الْحَمْدُ لِلَّهِ",
      'color': ZikrColors.teal,
      'isCustom': false,
    },
    {
      'text': "لَا إِلٰهَ إِلَّا اللَّهُ",
      'color': ZikrColors.terracotta,
      'isCustom': false,
    },
    {
      'text': "اللَّهُ أَكْبَرُ",
      'color': ZikrColors.gold,
      'isCustom': false,
    },
    {
      'text': "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّه",
      'color': ZikrColors.slate,
      'isCustom': false,
    },
    {
      'text': "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
      'color': ZikrColors.teal,
      'isCustom': false,
    },
    {
      'text': "سُبْحَانَ اللَّهِ الْعَظِيم",
      'color': ZikrColors.olive,
      'isCustom': false,
    },
    {
      'text': "أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ",
      'color': ZikrColors.plum,
      'isCustom': false,
    },
    {
      'text':
          "لَا إِلٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
      'color': ZikrColors.terracotta,
      'isCustom': false,
    },
    {
      'text':
          "حَسْبِيَ اللَّهُ لَا إِلٰهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ",
      'color': ZikrColors.gold,
      'isCustom': false,
    },
    {
      'text':
          "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ",
      'color': ZikrColors.teal,
      'isCustom': false,
    },
    {
      'text':
          "لَا إِلٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ",
      'color': ZikrColors.emerald,
      'isCustom': false,
    },
    {
      'text': "يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ",
      'color': ZikrColors.slate,
      'isCustom': false,
    },
    {
      'text':
          "اللَّهُمَّ اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ وَالْمُؤْمِنَاتِ",
      'color': ZikrColors.brown,
      'isCustom': false,
    },
    {
      'text': "اللَّهُمَّ صَلِّ وَسَلِّمْ وَبَارِكْ عَلَى نَبِيِّنَا مُحَمَّد",
      'color': ZikrColors.plum,
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
    if (!mounted) return;

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
              // الأذكار المحفوظة من النسخة القديمة ألوانها فاقعة،
              // فبنحوّلها لأقرب لون هادي بدل ما نمسح اختيار المستخدم
              'color': ZikrColors.calmFor(Color(e['color'])),
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
        'color': (e['color'] as Color).toARGB32(),
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
    _currentCelebrationColor = _currentZikrColor;

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
    Color selectedColor = ZikrColors.emerald;
    final p = context.palette;

    const List<Color> availableColors = ZikrColors.all;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: const Text("إضافة ذكر جديد", textAlign: TextAlign.right),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  "اختر اللون:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableColors.map((color) {
                    bool isSelected = color == selectedColor;
                    // بنخزّن النغمة الأصلية وبنعرض نسختها الليلية بس، عشان
                    // الدواير الغامقة ماتختفيش على خلفية الحوار الغامقة
                    final swatch = ZikrColors.visible(
                      color,
                      Theme.of(context).brightness,
                    );
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: swatch,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? p.text : p.border,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: ZikrColors.inkOn(swatch))
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
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
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
    final p = context.palette;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
          border: Border.all(color: p.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.card),
                ),
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text(
                    "سجل الطاعات",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: p.text,
                    ),
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
                  ? const EmptyState(
                      icon: Icons.history,
                      title: 'لا يوجد سجل بعد',
                      hint: 'ابدأ بالتسبيح لرؤية السجل هنا',
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
                            color: p.surface,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: p.primarySoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.small,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 14,
                                          color: p.success,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "أتممت ${log['count']} مرة",
                                          style: TextStyle(
                                            color: p.success,
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
                                      color: p.textFaint,
                                    ),
                                  ),
                                ],
                              ),

                              Divider(height: 20, color: p.border),

                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  log['zikr'],
                                  textAlign: TextAlign.right,
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  style: QuranTextStyle.amiri(
                                    color: p.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
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
    final p = context.palette;

    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "إعدادات التسبيح",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: p.text,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "شكل العداد",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
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
                  activeThumbColor: p.primary,
                  title: const Text(
                    "صوت خفيف عند الضغط",
                    textAlign: TextAlign.right,
                  ),
                  onChanged: (value) =>
                      setSheetState(() => soundEnabled = value),
                ),
                SwitchListTile(
                  value: hapticEnabled,
                  activeThumbColor: p.primary,
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
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
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
                    style: FilledButton.styleFrom(
                      backgroundColor: p.primary,
                      foregroundColor: p.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.chip),
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
    final p = context.palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: p.primary,
      labelStyle: TextStyle(
        color: selected ? p.onPrimary : p.text,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  /// لون الذكر الحالي جاهز للعرض — [ZikrColors.visible] بتغطّي الألوان
  /// القديمة المحفوظة وكمان بتفتّح النغمة في الوضع الليلي
  Color get _currentZikrColor => ZikrColors.visible(
        _azkar[_index]['color'] as Color,
        Theme.of(context).brightness,
      );

  void _showTargetPicker() {
    final TextEditingController customController = TextEditingController();
    final p = context.palette;
    final Color currentColor = _currentZikrColor;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.cardR,
            border: Border.all(color: p.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.card),
                      topRight: Radius.circular(AppRadius.card),
                    ),
                    border: Border(bottom: BorderSide(color: p.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_rounded, color: currentColor, size: 22),
                      const SizedBox(width: AppSpace.md),
                      Text(
                        "تحديد الهدف",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: p.text,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    children: [
                      _buildQuickOption(p, " مــ33ــرّة", 33, currentColor),
                      const SizedBox(height: AppSpace.md),
                      _buildQuickOption(p, " مــ100ــرّة", 100, currentColor),
                      const SizedBox(height: AppSpace.md),
                      _buildQuickOption(p, " مــ500ــرّة", 500, currentColor),
                      const SizedBox(height: AppSpace.md),
                      _buildQuickOption(p, " مــ1000ــرّة", 1000, currentColor),
                      const SizedBox(height: AppSpace.xl),
                      Row(
                        children: [
                          Expanded(child: Divider(color: p.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg,
                            ),
                            child: Text(
                              "أو",
                              style: TextStyle(
                                color: p.textFaint,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: p.border)),
                        ],
                      ),
                      const SizedBox(height: AppSpace.xl),
                      Text(
                        "أدخل عدد مخصص",
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
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
                          hintStyle: TextStyle(color: p.textFaint),
                          filled: true,
                          fillColor: p.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            borderSide: BorderSide(color: p.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            borderSide: BorderSide(color: p.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            borderSide: BorderSide(color: currentColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.chip,
                                  ),
                                ),
                              ),
                              child: Text(
                                "إلغاء",
                                style: TextStyle(
                                  color: p.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final int? custom = int.tryParse(
                                  customController.text,
                                );
                                if (custom != null && custom > 0) {
                                  _updateTarget(custom);
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: currentColor,
                                foregroundColor:
                                    ZikrColors.inkOn(currentColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.chip,
                                  ),
                                ),
                              ),
                              child: const Text(
                                "تأكيد",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
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

  Widget _buildQuickOption(AppPalette p, String label, int value, Color color) {
    final bool isSelected = _target == value;
    return GestureDetector(
      onTap: () => _updateTarget(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.lg,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : p.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: isSelected ? color : p.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? color : p.textFaint,
              size: 22,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : p.text,
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
    final p = context.palette;

    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (context) => Column(
        children: [
          // جديد: زر إضافة ذكر
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "الأذكار المتاحة",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: p.text,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: p.primary, size: 26),
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
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              itemCount: _azkar.length,
              itemBuilder: (context, i) {
                final bool isCustom = _azkar[i]['isCustom'] == true;
                return ListTile(
                  title: Text(
                    _azkar[i]['text'],
                    textAlign: TextAlign.center,
                    style: QuranTextStyle.amiri(
                      color: ZikrColors.visible(
                        _azkar[i]['color'] as Color,
                        Theme.of(context).brightness,
                      ),
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  trailing: isCustom
                      ? IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: p.danger,
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
    final p = context.palette;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: p.border),
        ),
        title: Text(
          "إعادة ضبط الإحصائيات",
          textAlign: TextAlign.right,
          style: TextStyle(color: p.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // خيار 1
            ListTile(
              leading: Icon(Icons.refresh, color: p.primary),
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
            Divider(color: p.border),
            // خيار 2
            ListTile(
              leading: Icon(Icons.today, color: p.accent),
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
            Divider(color: p.border),
            // خيار 3
            ListTile(
              leading: Icon(Icons.delete_forever, color: p.danger),
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
            child: Text("إلغاء", style: TextStyle(color: p.textMuted)),
          ),
        ],
      ),
    );
  }

  // جديد: تأكيد إعادة الضبط الكامل
  void _confirmResetAll() {
    final p = context.palette;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: p.border),
        ),
        title: Text(
          "⚠️ تأكيد",
          textAlign: TextAlign.right,
          style: TextStyle(color: p.text),
        ),
        content: Text(
          "هل أنت متأكد من حذف كل الإحصائيات والسجل؟",
          textAlign: TextAlign.right,
          style: TextStyle(color: p.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("إلغاء", style: TextStyle(color: p.textMuted)),
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
            child: Text("تأكيد", style: TextStyle(color: p.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color currentColor = _currentZikrColor;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: p.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // الطول بييجي من القياس الحقيقي، مش من طول الشاشة. الشاشة دي
            // ساكنة جوّه Expanded جنب المشغل المصغّر وتحتها شريط التبويبات،
            // فالمساحة اللي بناخدها فعلًا أقل من طول الشاشة بستين نقطة على
            // الأقل. قبل كده كان فيه SizedBox بطول الشاشة ناقص الحواف الآمنة
            // بس، والفرق ده الفراغات المرنة كانت بتبلعه في السكوت — لحد ما
            // ييجي ذكر طويل يلف على أربع سطور، فتقع الشاشة في
            // "BOTTOM OVERFLOWED BY 45 PIXELS".
            //
            // SliverFillRemaining بتاخد الأكبر: المساحة الباقية فعلًا ولا
            // طول المحتوى الطبيعي. فالذكر القصير بيتوزّع في الشاشة بالظبط
            // زي الأول، والطويل بيمدّ والشاشة تبقى قابلة للتمرير.
            //
            // ملحوظة مهمة: الطول الطبيعي بيحسب الفراغات المرنة صفر، فلازم كل
            // فراغ يكون له حد أدنى ثابت جنب المرن — وإلا الذكر الطويل بيخلّي
            // المرن يتصفّر والعناصر تتلزّق في بعضها. الفراغات تحت مكتوبة كده.
            CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(children: [
                    const SizedBox(height: AppSpace.xl),
                    // معدل: إضافة العداد اليومي
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TasbihStatItem(
                          label: "الإجمالي اليومي",
                          value: "$_dailyCounter",
                          color: p.accent,
                        ),
                        TasbihStatItem(
                          label: "الإجمالي طوال الوقت",
                          value: "$_totalCounter",
                          color: currentColor,
                        ),
                        TasbihStatItem(
                          label: "الهدف",
                          value: "$_target",
                          color: currentColor,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg,
                        AppSpace.lg,
                        AppSpace.lg,
                        0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: AppRadius.cardR,
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: "إعدادات التسبيح",
                              icon: Icon(Icons.tune, color: currentColor),
                              onPressed: _showTasbihSettings,
                            ),
                            const SizedBox(width: AppSpace.xs),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "هدف اليوم: $_dailyCounter / $_dailyTarget",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: p.text,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.small,
                                    ),
                                    child: LinearProgressIndicator(
                                      value: (_dailyCounter / _dailyTarget)
                                          .clamp(0.0, 1.0)
                                          .toDouble(),
                                      minHeight: 7,
                                      color: currentColor,
                                      backgroundColor: p.surfaceAlt,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // الفراغ المرن لوحده بيتصفّر أول ما المحتوى يزيد عن
                    // المساحة المتاحة، وساعتها الذكر بيلزق في كارت هدف اليوم.
                    // الحد الأدنى ثابت عشان القياس يحسبه ومايقدرش ياكله،
                    // والمرن بياخد الزيادة بس لما يكون فيه مكان فاضي.
                    const SizedBox(height: AppSpace.xl),
                    const Expanded(child: SizedBox()),
                    InkWell(
                      onTap: _showZikrPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.xl,
                        ),
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                _azkar[_index]['text'],
                                key: ValueKey(_index),
                                textAlign: TextAlign.center,
                                style: QuranTextStyle.amiri(
                                  fontSize: 28,
                                  color: currentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              "انقر لتغيير الذكر أو اضافة ذكر جديد",
                              style: TextStyle(
                                color: p.textFaint,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    GestureDetector(
                      onTap: _increment,
                      child: _buildCounterSurface(p, currentColor),
                    ),
                    // نفس الحكاية تحت العداد، والزيادة عشان لافتة "اضغط على
                    // العداد" متعلّقة ٤٢ نقطة تحت العداد بـ Positioned جوّه
                    // Stack بـ clipBehavior: none — يعني بتترسم برّه حدود
                    // العداد ومش محسوبة في القياس. لو مااحتجناش مكانها بأيدينا
                    // بتركب على زرار إعادة الضبط في أول تشغيل.
                    SizedBox(
                      height: _showTip && _counter == 0
                          ? 42 + AppSpace.lg
                          : AppSpace.lg,
                    ),
                    const Expanded(child: SizedBox()),
                    // معدل: زر إعادة الضبط مع خيارات
                    TextButton.icon(
                      onPressed: _showResetOptions,
                      icon: Icon(Icons.refresh, color: p.textFaint, size: 18),
                      label: Text(
                        "إعادة ضبط الإحصائيات",
                        style: TextStyle(color: p.textFaint),
                      ),
                    ),
                    // كان ٥٠ وقت ما الشاشة كانت بتقيس نفسها بطول الشاشة كلها،
                    // فكانت لازم تسيب مكان للمشغل المصغّر وشريط التبويبات
                    // بنفسها. الاتنين برّه الشاشة دي أصلًا، فالخمسين دي كانت
                    // بتاكل من المساحة اللي الفراغات محتاجاها.
                    const SizedBox(height: AppSpace.lg),
                  ]),
                ),
              ],
            ),

            if (_showCelebration)
              Positioned(
                top: 120,
                left: AppSpace.xl,
                right: AppSpace.xl,
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
                          horizontal: AppSpace.xl,
                          vertical: AppSpace.lg,
                        ),
                        decoration: BoxDecoration(
                          color: _currentCelebrationColor,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mosque,
                              color: ZikrColors.inkOn(_currentCelebrationColor),
                              size: 18,
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Text(
                                _currentCelebrationMessage,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: ZikrColors.inkOn(
                                    _currentCelebrationColor,
                                  ),
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Icon(
                              Icons.check_circle,
                              color: ZikrColors.inkOn(_currentCelebrationColor),
                              size: 18,
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

  Widget _buildCounterSurface(AppPalette p, Color currentColor) {
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
          color: p.surface,
          border: Border.all(color: currentColor.withValues(alpha: 0.35)),
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
                        : currentColor.withValues(alpha: 0.18),
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
                fontWeight: FontWeight.w200,
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
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: currentColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_counter',
              style: TextStyle(
                fontSize: 82,
                color: currentColor,
                fontWeight: FontWeight.w200,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: currentColor,
                backgroundColor: p.surfaceAlt,
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
              backgroundColor: p.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(currentColor),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.surface,
              border: Border.all(color: currentColor.withValues(alpha: 0.35)),
            ),
            child: Center(
              child: Text(
                '$_counter',
                style: TextStyle(
                  fontSize: 85,
                  color: currentColor,
                  fontWeight: FontWeight.w200,
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
              icon: Icon(Icons.flag_outlined, color: p.textMuted),
              onPressed: _showTargetPicker,
            ),
          ),
          Positioned(
            top: simple ? 6 : 25,
            left: simple ? 12 : 25,
            child: IconButton(
              tooltip: "سجل الطاعات",
              icon: Icon(Icons.history, color: p.textMuted),
              onPressed: _showActivityLog,
            ),
          ),
          if (_showTip && _counter == 0)
            Positioned(
              bottom: -42,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: p.accent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, color: p.accent, size: 20),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        'اضغط على العداد لبدء العد',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.close, color: p.textMuted, size: 18),
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
