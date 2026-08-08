import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// كارت مسطّح موحّد لكل الشاشات — من غير ظلال، بحواف مدوّرة وحدود رقيقة.
///
/// قبل كده كل شاشة كانت بتكتب نفس الـ Container اللي فيه borderRadius
/// و border و color بالـ isDark. المرّة دي بنستعمل AppPalette اللي جاية
/// من الثيم — الكارت بياخد ألوانه من السياق تلقائيًا.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: Material(
        color: p.surface,
        borderRadius: AppRadius.cardR,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardR,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardR,
              border: Border.all(color: p.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// عنوان قسم — نفس اللي كان في settings_screen بس معمّم
class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
          color: p.textFaint,
        ),
      ),
    );
  }
}

/// حالة فاضية — أيقونة + عنوان + تلميح
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: p.textFaint),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(fontSize: 16, color: p.textMuted)),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
