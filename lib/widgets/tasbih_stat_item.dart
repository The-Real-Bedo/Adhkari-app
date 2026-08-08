import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// بطاقة إحصائية صغيرة في شاشة التسبيح — تصميم مسطّح بحدود بدل الظلال
class TasbihStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const TasbihStatItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: p.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
