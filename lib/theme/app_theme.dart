import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// نظام التصميم الموحّد — المصدر الوحيد لكل الألوان والأشكال في التطبيق.
///
/// قبل كده كل شاشة كانت بتحسب ألوانها بنفسها بسطر زي
/// `isDark ? Colors.cyanAccent : const Color(0xFF00838F)` — الحكاية دي كانت
/// مكرّرة في ٥٥ مكان على ١٢ ملف، فأي تغيير في الهوية كان لازم يمشي على
/// الملفات كلها بالإيد. دلوقتي الشاشة بتقول `context.palette.primary` وخلاص.
///
/// الهوية: أخضر زمردي على خلفية رملية دافية. مسطّح من غير ظلال — بنفصل
/// الأسطح بحدود رقيقة وتظليل خفيف في الخلفية، زي بوابة مصر الرقمية.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// اللون الأساسي — الأزرار والمؤشرات والعناصر المختارة
  final Color primary;

  /// نسخة خفيفة من الأساسي — خلفيات الشرائح والأيقونات الدايرية
  final Color primarySoft;

  /// اللون اللي يتقرا فوق primary
  final Color onPrimary;

  /// الذهبي — النجوم والمفضلة والتمييز
  final Color accent;
  final Color accentSoft;

  /// خلفية الشاشة
  final Color bg;

  /// الكروت والأسطح المرفوعة
  final Color surface;

  /// سطح بديل أغمق/أدفى شوية — صفوف البحث وأقسام القوايم
  final Color surfaceAlt;

  final Color text;
  final Color textMuted;
  final Color textFaint;

  /// حدود رقيقة — بديل الظلال
  final Color border;

  final Color danger;
  final Color success;

  const AppPalette({
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.border,
    required this.danger,
    required this.success,
  });

  /// النهار — رملي دافي وأبيض نضيف
  static const AppPalette light = AppPalette(
    primary: Color(0xFF0F6B4F),
    primarySoft: Color(0xFFE4EFE9),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFC9A227),
    accentSoft: Color(0xFFF7EFD6),
    bg: Color(0xFFF7F3EA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0EADC),
    text: Color(0xFF1A2420),
    textMuted: Color(0xFF6B7A73),
    textFaint: Color(0xFF9AA8A1),
    border: Color(0xFFE5DFD1),
    danger: Color(0xFFB3453C),
    success: Color(0xFF2E7D5B),
  );

  /// الليل — فحمي شبه رمادي، والأخضر بيبان في العناصر بس.
  ///
  /// النسخة الأولى كانت كل حاجة فيها مخضرّة: الخلفية والكارت والحدود
  /// والنص الباهت كلهم خضار، فالشاشة كانت بتبان لطخة واحدة غامقة
  /// والكروت مش محسوسة. دلوقتي الأساس فحمي محايد تقريبًا، وفيه ٣ درجات
  /// واضحة (خلفية → كارت → سطح بديل) والحدود أفتح من السطح عشان تبان،
  /// والزمردي بقى أهدى شوية عشان مايرجعش نيون فوق أساس محايد.
  static const AppPalette dark = AppPalette(
    primary: Color(0xFF52B892),
    primarySoft: Color(0xFF1C2A24),
    onPrimary: Color(0xFF06120D),
    accent: Color(0xFFD9B75A),
    accentSoft: Color(0xFF2B2519),
    bg: Color(0xFF101413),
    surface: Color(0xFF1A201E),
    surfaceAlt: Color(0xFF232A27),
    text: Color(0xFFE7ECE9),
    textMuted: Color(0xFF9BA8A2),
    textFaint: Color(0xFF7A867F),
    border: Color(0xFF313A36),
    danger: Color(0xFFDE8478),
    success: Color(0xFF6ECFA4),
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primarySoft,
    Color? onPrimary,
    Color? accent,
    Color? accentSoft,
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? border,
    Color? danger,
    Color? success,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      border: border ?? this.border,
      danger: danger ?? this.danger,
      success: success ?? this.success,
    );
  }

  /// بيخلي التبديل بين النهار والليل يتحرك بنعومة بدل ما يقطع
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      border: Color.lerp(border, other.border, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// حبر مقروء فوق أي لون مليان.
///
/// بنحتاجها في أي حتة بنملا فيها خلفية بلون متغيّر — زرار بلون الذكر،
/// مسار مفتاح بلون الكارت، شريط تهنئة. اللون الجوّاه لازم يقلب مع
/// اللون اللي تحته، مش يفضل أبيض ثابت وبعدين يختفي في الوضع الليلي
/// لما النغمة تبقى فاتحة.
Color inkOnFill(Color fill) =>
    ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : const Color(0xFF10201A);

/// أنصاف الأقطار — الكروت مدوّرة والأزرار كبسولة، زي الموقع المرجعي
class AppRadius {
  const AppRadius._();

  static const double card = 16;
  static const double chip = 12;
  static const double small = 10;
  static const double pill = 999;

  static final BorderRadius cardR = BorderRadius.circular(card);
  static final BorderRadius chipR = BorderRadius.circular(chip);
  static final BorderRadius smallR = BorderRadius.circular(small);
  static final BorderRadius pillR = BorderRadius.circular(pill);
}

/// مسافات ثابتة عشان الشاشات تبقى متسقة
class AppSpace {
  const AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// امتداد بسيط عشان الوصول للوحة من أي مكان: `context.palette.primary`
extension AppThemeExt on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get type => Theme.of(this).textTheme;
}

/// الثيمات الكاملة — فاتح وداكن — بنفس ألوان اللوحة الجديدة.
///
/// ملحوظة عن التسطيح: `elevation: 0` و `scrolledUnderElevation: 0` في كل
/// Screens الـ Scaffold اللي بنتحكم فيها إحنا — مفيش ظلال في أي حتة.
/// بنفضل حدود رقيقة لونها `palette.border`.
class AppThemeData {
  const AppThemeData._();

  static ThemeData light = _build(AppPalette.light, Brightness.light);
  static ThemeData dark = _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      // الزمردي هو اللون الوحيد المسيطر، والذهبي بيستعمل للأيقونات
      // والنبرات بس — فبنسيب secondary زي primary عشان أي عنصر
      // ماتيريال بياخد اللون ده يفضل مقروء في الوضعين.
      secondary: p.primary,
      onSecondary: p.onPrimary,
      surface: p.surface,
      onSurface: p.text,
      error: p.danger,
      onError: Colors.white,

      // مهم: الدرجات اللي تحت لو سيبناها فاضية، ماتيريال بيرجع لرمادي
      // افتراضي مالوش علاقة باللوحة. وده كان بيطلع بقع رمادية باردة في
      // الوضع الليلي — خلفية الشرائح والمؤشرات وأطراف المفاتيح.
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.primary,
      secondaryContainer: p.primarySoft,
      onSecondaryContainer: p.primary,
      tertiary: p.accent,
      // الذهبي فاتح في الوضعين، فاللي فوقه لازم يبقى حبر غامق
      onTertiary: const Color(0xFF1A2420),
      tertiaryContainer: p.accentSoft,
      onTertiaryContainer: p.accent,
      errorContainer: p.surfaceAlt,
      onErrorContainer: p.danger,
      surfaceDim: p.bg,
      surfaceBright: p.surface,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceAlt,
      surfaceContainerHigh: p.surfaceAlt,
      surfaceContainerHighest: p.surfaceAlt,
      onSurfaceVariant: p.textMuted,
      outline: p.border,
      outlineVariant: p.border,
      // تصميم مسطّح: مفيش ظل ولا تظليل ارتفاع
      surfaceTint: Colors.transparent,
      shadow: Colors.transparent,
      scrim: const Color(0x99000000),
      inverseSurface: p.text,
      onInverseSurface: p.bg,
      inversePrimary: p.primarySoft,
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      colorScheme: colorScheme,

      // خطوط الموقع المرجعي
      useMaterial3: true,
      fontFamily: googleFont,
      fontFamilyFallback: const ['Noto Sans Arabic', 'sans-serif'],

      textTheme: _textTheme(p),

      // ————— شريط العنوان —————
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: googleFont,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
      ),

      // ————— التبويبات —————
      tabBarTheme: TabBarThemeData(
        indicatorColor: p.primary,
        labelColor: p.primary,
        unselectedLabelColor: p.textMuted,
        labelStyle: TextStyle(fontFamily: googleFont, fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontFamily: googleFont, fontSize: 13),
      ),

      // ————— الكروت —————
      // الحد أعرض شوية في الليل: خط نص بكسل بيختفي خالص على خلفية غامقة،
      // والكارت بيبقى ملزوق في الخلفية. في النهار النص بكسل كفاية.
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: p.border, width: isDark ? 1 : 0.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs, horizontal: AppSpace.md),
      ),

      // ————— الفواصل —————
      dividerColor: p.border,
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: isDark ? 1 : 0.5,
        space: 1,
      ),

      // ————— زراير —————
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillR),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillR),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primary),
      ),

      // ————— أيقونات —————
      iconTheme: IconThemeData(color: p.text, size: 22),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.text),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
      ),

      // ————— حقول الإدخال —————
      // في الليل بنملا الحقل بالسطح البديل عشان يبان جوه الكارت،
      // لأن نفس لون السطح كان بيخليه مختفي.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? p.surfaceAlt : p.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: AppRadius.cardR,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.cardR,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.cardR,
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: p.textFaint, fontFamily: googleFont, fontSize: 14),
        labelStyle: TextStyle(color: p.textMuted, fontFamily: googleFont),
      ),

      // ————— الحوارات —————
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: p.border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: googleFont,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      ),

      // ————— أدراج سفلية —————
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        ),
      ),

      // ————— شرايط التنبيه —————
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface,
        contentTextStyle: TextStyle(color: p.text, fontFamily: googleFont),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
        behavior: SnackBarBehavior.floating,
      ),

      // ————— المفاتيح —————
      // المسار المقفول: في الليل بناخد السطح البديل مش textFaint، لأن
      // الرمادي الفاتح على خلفية غامقة كان أعلى تباينًا من المفتاح المفعّل
      // نفسه — يعني المغلق كان مبيّن أكتر من المفتوح.
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return isDark ? p.surfaceAlt : p.textFaint;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return p.border;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.onPrimary;
          return isDark ? p.textMuted : p.surface;
        }),
      ),

      // ————— شرايط التمرير —————
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(p.border),
        radius: const Radius.circular(AppRadius.pill),
      ),

      // ————— المؤشرات المنزلقة —————
      // المسار الفاضي بياخد لون الحدود — الرمادي الافتراضي بارد وواضح
      // زيادة على خلفية غامقة
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.border,
        thumbColor: p.primary,
        overlayColor: p.primarySoft,
      ),

      // ————— مؤشرات التقدم —————
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.border,
        circularTrackColor: p.border,
      ),

      // ————— الشرائح —————
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        selectedColor: p.primarySoft,
        side: BorderSide(color: p.border),
        labelStyle: TextStyle(fontFamily: googleFont, fontSize: 13, color: p.text),
        secondaryLabelStyle: TextStyle(fontFamily: googleFont, fontSize: 13, color: p.primary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillR),
      ),

      // ————— القوايم المنسدلة —————
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.chipR,
          side: BorderSide(color: p.border),
        ),
        textStyle: TextStyle(fontFamily: googleFont, color: p.text),
      ),

      // ————— أسطر القوايم —————
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        textColor: p.text,
        subtitleTextStyle: TextStyle(
          fontFamily: googleFont,
          fontSize: 12,
          color: p.textMuted,
        ),
      ),

      // ————— اختيار الوقت —————
      // شاشة اختيار الوقت في التذكير كانت بتاخد ألوان ماتيريال الافتراضية
      // وتطلع بنفسجية في الليل. بنربطها باللوحة زي أي حاجة تانية.
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        dialBackgroundColor: p.surfaceAlt,
        dialHandColor: p.primary,
        hourMinuteColor: p.primarySoft,
        hourMinuteTextColor: p.text,
        dayPeriodColor: p.primarySoft,
        dayPeriodTextColor: p.text,
        entryModeIconColor: p.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: p.border),
        ),
      ),

      // ————— ألوان الأزرار الخاصة —————
      extensions: [p],
    );
  }

  /// اسم عائلة كايرو بعد ما google_fonts تحمّلها.
  ///
  /// مهم: مانقدرش نكتب 'Cairo' نص مباشر — الاسم النصي ده بيشتغل بس مع
  /// الخطوط المعلنة في pubspec.yaml. google_fonts بتنزّل الخط وقت التشغيل
  /// وبتسميه اسم داخلي (زي 'Cairo_regular')، فلازم نسأل المكتبة عنه.
  static final String googleFont =
      GoogleFonts.cairo().fontFamily ?? 'sans-serif';

  /// أنماط النصوص: أميري لنص القرآن والأذكار، كايرو لباقي الواجهة.
  /// بنعرّفهم هنا بس، وكل مكان بياخدهم من `context.type`.
  ///
  /// بندمج أميري مع Cairo في textTheme عشان فلاتر بتاخد خط واحد
  /// للـ fontFamily، فالواجهة بتستخدم Cairo افتراضيًا، والأذكار
  /// والقرآن بياخدوا headlineSmall اللي إحنا عاملينه override بأميري.
  static TextTheme _textTheme(AppPalette p) {
    return TextTheme(
      // —— واجهة (كايرو) ——
      headlineLarge: TextStyle(
        fontFamily: googleFont,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: p.text,
        height: 1.5,
      ),
      headlineMedium: TextStyle(
        fontFamily: googleFont,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: p.text,
        height: 1.5,
      ),
      headlineSmall: GoogleFonts.amiri(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: p.text,
        height: 1.5,
      ),
      titleLarge: TextStyle(
        fontFamily: googleFont,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: p.text,
      ),
      titleMedium: TextStyle(
        fontFamily: googleFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      titleSmall: TextStyle(
        fontFamily: googleFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: p.textMuted,
      ),
      bodyLarge: TextStyle(
        fontFamily: googleFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: p.text,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: googleFont,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: p.text,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: googleFont,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: p.textMuted,
      ),
      labelLarge: TextStyle(
        fontFamily: googleFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
      labelMedium: TextStyle(
        fontFamily: googleFont,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: p.textMuted,
      ),
      labelSmall: TextStyle(
        fontFamily: googleFont,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: p.textFaint,
      ),
    );
  }
}

/// نص القرآن والأذكار — بنستخدم أميري مش كايرو
extension QuranTextStyle on TextStyle {
  static TextStyle amiri({Color? color, double fontSize = 18, FontWeight fontWeight = FontWeight.w700, double height = 1.5}) {
    return GoogleFonts.amiri(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);
  }
}


