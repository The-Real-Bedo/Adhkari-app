import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/quran/mushaf_book_screen.dart';
import '../services/khatmah_service.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// كارت متابعة ختمة القرآن الكريم (604 صفحات) في شاشة "ورد اليوم"
class KhatmahCard extends StatelessWidget {
  const KhatmahCard({super.key});

  void _showPlanDialog(BuildContext context) {
    final p = context.palette;
    final plan = KhatmahService.currentPlan;
    int selectedDays = plan.targetDays;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: p.primary),
                    const SizedBox(width: 10),
                    Text(
                      'تعديل خطة ختمة القرآن',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'اختر مدة الختمة المستهدفة:',
                  style: TextStyle(color: p.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [15, 30, 45, 60, 90].map((days) {
                    final isSelected = selectedDays == days;
                    final dailyPages = (604 / days).ceil();
                    return ChoiceChip(
                      label: Text('$days يوماً ($dailyPages ص/يوم)'),
                      selected: isSelected,
                      selectedColor: p.primarySoft,
                      backgroundColor: p.surfaceAlt,
                      side: BorderSide(
                        color: isSelected ? p.primary : p.border,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? p.primary : p.text,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) =>
                          setSheetState(() => selectedDays = days),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                if (plan.paceDifference < -5) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_fix_high, color: p.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'إعادة جدولة: توزيع الصفحات المتبقية (${plan.remainingPages} ص) على الأيام المتبقية.',
                            style: TextStyle(fontSize: 12, color: p.text),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            KhatmahService.rebalancePlan();
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('إعادة توزيع'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          KhatmahService.startNewKhatmah(
                            targetDays: selectedDays,
                          );
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('تم بدء ختمة جديدة، مبارك مقدماً 🌿'),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.danger,
                          side: BorderSide(
                            color: p.danger.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text('بدء ختمة جديدة'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (selectedDays != plan.targetDays) {
                            KhatmahService.startNewKhatmah(
                              targetDays: selectedDays,
                            );
                          }
                          Navigator.pop(sheetContext);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primary,
                          foregroundColor: p.onPrimary,
                        ),
                        child: const Text('حفظ التعديل'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPageProgressDialog(BuildContext context) {
    final p = context.palette;
    final plan = KhatmahService.currentPlan;
    final controller = TextEditingController(text: '${plan.currentPage}');

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: p.surface,
          title: const Text('تسجيل صفحة القراءة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أدخل رقم آخر صفحة قرأتها في المصحف (1 - 604):',
                style: TextStyle(color: p.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'رقم الصفحة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(controller.text);
                if (page != null && page > 0 && page <= 604) {
                  KhatmahService.updateCurrentPage(page);
                  Navigator.pop(dialogContext);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
              ),
              child: const Text('تحديث'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ValueListenableBuilder<KhatmahPlan>(
      valueListenable: KhatmahService.planNotifier,
      builder: (context, plan, _) {
        final percentage = (plan.overallProgress * 100).toInt();
        final todayDone = plan.pagesReadToday >= plan.dailyPagesTarget;
        final pace = plan.paceDifference;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس الكارت
              Row(
                children: [
                  Icon(Icons.auto_stories_outlined, color: p.primary, size: 20),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    'مخطط ختمة القرآن',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: p.text,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (pace > 0)
                    _paceBadge(
                      'متقدم بـ $pace ص 🚀',
                      p.success,
                      p.success.withValues(alpha: 0.15),
                    )
                  else if (pace < -5)
                    _paceBadge(
                      'متأخر ${-pace} ص ⏳',
                      p.accent,
                      p.accentSoft,
                    )
                  else
                    _paceBadge(
                      'على المسار 🎯',
                      p.primary,
                      p.primarySoft,
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.tune, size: 18),
                    tooltip: 'تعديل الخطة',
                    color: p.textMuted,
                    onPressed: () => _showPlanDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(color: p.border, height: 1),
              const SizedBox(height: 12),

              // حالة الإنجاز الكلي
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الصفحة ${plan.currentPage} من 604',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'اليوم ${plan.currentDayNumber} من ${plan.targetDays} • متبقي ${plan.remainingDays} يوم (${plan.remainingPages} ص)',
                        style: TextStyle(fontSize: 11.5, color: p.textMuted),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: p.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // شريط التقدم الكلي
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: plan.overallProgress,
                  backgroundColor: p.border,
                  color: p.primary,
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 14),

              // ورد اليوم المطلوب
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      todayDone
                          ? Icons.check_circle
                          : Icons.bookmark_border_outlined,
                      color: todayDone ? p.success : p.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todayDone
                                ? 'أتممت ورد اليوم، تقبل الله منك ✨'
                                : 'ورد اليوم: ص ${plan.todayTargetStartPage} - ${plan.todayTargetEndPage}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: todayDone ? p.success : p.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'قرأت ${plan.pagesReadToday} من ${plan.dailyPagesTarget} صفحة مطلوبة',
                            style: TextStyle(fontSize: 11, color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, size: 22),
                      tooltip: 'تسجيل تقدم مخصص',
                      color: p.primary,
                      onPressed: () => _showPageProgressDialog(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // أزرار التفاعل السريع
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // فتح المصحف مباشرة عند صفحة بداية ورد اليوم
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MushafBookScreen(
                              initialPage: plan.todayTargetStartPage,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book, size: 16),
                      label: Text(
                        'اقرأ ص ${plan.todayTargetStartPage}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.text,
                        side: BorderSide(color: p.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!todayDone)
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        KhatmahService.completeTodayTarget();
                      },
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('إتمام الورد'),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        KhatmahService.addPagesRead(1);
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('+1 ص'),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.primary,
                        foregroundColor: p.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _paceBadge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
