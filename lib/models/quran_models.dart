/// موديلات مكتبة القرآن الصوتية — بيانات من mp3quran.net API v3
///
/// الرابط الصوتي = server + رقم السورة (3 خانات) + .mp3
/// مثال: https://server6.mp3quran.net/akdr/001.mp3

/// رواية / مصحف لقارئ معين. كل رواية ليها سيرفر مستقل وقائمة سور خاصة بيها،
/// لأن مش كل قارئ مسجل الـ 114 سورة كاملة.
class Moshaf {
  final int id;
  final String name;
  final String server;

  /// أرقام السور المتاحة فعليًا في الرواية دي
  final Set<int> surahList;

  Moshaf({
    required this.id,
    required this.name,
    required this.server,
    required this.surahList,
  });

  factory Moshaf.fromJson(Map<String, dynamic> json) {
    return Moshaf(
      id: json['id'] as int,
      name: (json['name'] as String? ?? '').trim(),
      server: (json['server'] as String? ?? '').trim(),
      surahList: parseSurahList(json['surah_list'] as String?),
    );
  }

  /// الـ API بيرجع قائمة السور كنص مفصول بفواصل: "1,2,3,..."
  static Set<int> parseSurahList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <int>{};
    final result = <int>{};
    for (final part in raw.split(',')) {
      final value = int.tryParse(part.trim());
      if (value != null && value >= 1 && value <= 114) result.add(value);
    }
    return result;
  }

  /// بناء رابط السورة. مكان واحد بس مسؤول عن صيغة الرابط.
  /// بيرجع null لو السورة مش متاحة في الرواية دي.
  String? audioUrlFor(int surahId) {
    if (!surahList.contains(surahId)) return null;
    final base = server.endsWith('/') ? server : '$server/';
    return '$base${surahId.toString().padLeft(3, '0')}.mp3';
  }

  Map<String, dynamic> toCache() => {
    'id': id,
    'name': name,
    'server': server,
    'surah_list': surahList.join(','),
  };
}

class Reciter {
  final int id;
  final String name;
  final List<Moshaf> moshaf;

  Reciter({required this.id, required this.name, required this.moshaf});

  factory Reciter.fromJson(Map<String, dynamic> json) {
    final rawMoshaf = json['moshaf'] as List<dynamic>? ?? const [];
    final sets = rawMoshaf
        .whereType<Map<String, dynamic>>()
        .map(Moshaf.fromJson)
        // نستبعد الروايات الفاضية أو اللي بدون سيرفر عشان متظهرش للمستخدم
        .where((m) => m.server.isNotEmpty && m.surahList.isNotEmpty)
        .toList();

    return Reciter(
      id: json['id'] as int,
      name: (json['name'] as String? ?? '').trim(),
      moshaf: sets,
    );
  }

  /// بنخزن نسخة مصغرة في الكاش (الأسماء والسيرفرات بس) مش الرد الكامل
  Map<String, dynamic> toCache() => {
    'id': id,
    'name': name,
    'moshaf': moshaf.map((m) => m.toCache()).toList(),
  };
}

class Surah {
  final int id;
  final String name;

  /// مكية (true) أو مدنية (false)
  final bool makkia;

  Surah({required this.id, required this.name, required this.makkia});

  factory Surah.fromJson(Map<String, dynamic> json) {
    // الـ API بيرجع makkia كرقم 1/0 وساعات كنص
    final raw = json['makkia'];
    final isMakkia = raw is int ? raw == 1 : raw.toString().trim() == '1';

    return Surah(
      id: json['id'] as int,
      name: (json['name'] as String? ?? '').trim(),
      makkia: isMakkia,
    );
  }

  String get typeLabel => makkia ? 'مكية' : 'مدنية';

  Map<String, dynamic> toCache() => {
    'id': id,
    'name': name,
    'makkia': makkia ? 1 : 0,
  };
}
