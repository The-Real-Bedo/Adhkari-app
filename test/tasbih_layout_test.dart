import 'package:adhkari/screens/tasbih_screen.dart';
import 'package:adhkari/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبار تخطيط شاشة التسبيح.
///
/// كان فيها `SizedBox` بطول الشاشة كلها ناقص الحواف الآمنة بس. الشاشة
/// الحقيقية ساكنة جوّه `Expanded` جنب المشغل المصغّر وتحتها شريط التبويبات،
/// فالطول المطلوب كان أكبر من المتاح بستين نقطة على الأقل. الفراغات المرنة
/// كانت بتبلع الفرق ده في السكوت، لحد ما ييجي ذكر طويل يلف على أربع سطور
/// فتقع الشاشة في "BOTTOM OVERFLOWED BY 45 PIXELS".
///
/// عشان كده الاختبارات دي بتبني الشاشة بنفس هيكل [MainNavigation] بالظبط —
/// من غير المشغل وشريط التبويبات مافيش bug من الأصل.
void main() {
  /// أطول ذكر في القايمة الافتراضية — هو اللي بيكشف المشكلة
  const int longZikrIndex = 8;

  /// نفس تركيب الشاشة الحقيقي: الشاشة في `Expanded`، المشغل المصغّر تحتها،
  /// وشريط التبويبات تحتهم. الأرقام تقريبية لكن قريبة من الحقيقة.
  Widget hostedLikeMainNavigation() => MaterialApp(
    theme: AppThemeData.light,
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(child: TasbihHome()),
            SizedBox(height: 64), // المشغل المصغّر
          ],
        ),
        bottomNavigationBar: SizedBox(height: 62),
      ),
    ),
  );

  /// مقاس موبايل حقيقي — المقاس الافتراضي في الاختبارات (800×600) عريض
  /// وقصير، والذكر مابيلفّش فيه زي ما بيلف على تليفون.
  void usePhoneViewport(WidgetTester tester, {double height = 700}) {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('الذكر الطويل مابيطلّعش overflow', (tester) async {
    SharedPreferences.setMockInitialValues({'index': longZikrIndex});
    usePhoneViewport(tester);

    await tester.pumpWidget(hostedLikeMainNavigation());
    await tester.pumpAndSettle();

    // الـ overflow بيترمي وقت الرسم، فبيوصل هنا كـ exception
    expect(tester.takeException(), isNull);
  });

  testWidgets('الذكر القصير كمان مابيطلّعش overflow', (tester) async {
    SharedPreferences.setMockInitialValues({'index': 0});
    usePhoneViewport(tester);

    await tester.pumpWidget(hostedLikeMainNavigation());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('الذكر مابيلزقش في كارت هدف اليوم', (tester) async {
    SharedPreferences.setMockInitialValues({'index': longZikrIndex});
    usePhoneViewport(tester);

    await tester.pumpWidget(hostedLikeMainNavigation());
    await tester.pumpAndSettle();

    // كارت هدف اليوم: أقرب Container حاوي لنص الهدف
    final Finder goalCard = find
        .ancestor(
          of: find.textContaining('هدف اليوم'),
          matching: find.byType(Container),
        )
        .first;

    // الذكر نفسه جوّه AnimatedSwitcher، وهو واحد بس في الشاشة
    final Finder zikr = find.byType(AnimatedSwitcher);

    final double gap =
        tester.getRect(zikr).top - tester.getRect(goalCard).bottom;

    // مافيش overflow مش معناه إن التخطيط سليم: الفراغ المرن ممكن يتصفّر
    // فالعنصرين يبقوا ملزوقين والشاشة تفضل ساكتة. الحد الأدنى المكتوب
    // AppSpace.xl، فأي حاجة أقل منه معناها إن الفراغ اتأكل تاني.
    expect(
      gap,
      greaterThanOrEqualTo(AppSpace.xl),
      reason: 'الفراغ بين كارت هدف اليوم والذكر بقى $gap',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('لافتة التلميح مابتركبش على زرار إعادة الضبط', (tester) async {
    // مافيش 'tasbih_tip_shown' يعني أول تشغيل، واللافتة بتظهر. وهي متعلّقة
    // ٤٢ نقطة تحت العداد بـ Positioned، يعني مش محسوبة في القياس.
    SharedPreferences.setMockInitialValues({'index': longZikrIndex});
    usePhoneViewport(tester);

    await tester.pumpWidget(hostedLikeMainNavigation());
    await tester.pumpAndSettle();

    final Finder tip = find.text('اضغط على العداد لبدء العد');
    expect(tip, findsOneWidget, reason: 'اللافتة المفروض تظهر في أول تشغيل');

    final Finder resetButton = find.text('إعادة ضبط الإحصائيات');
    await tester.scrollUntilVisible(resetButton, 120);

    expect(
      tester.getRect(tip).bottom,
      lessThanOrEqualTo(tester.getRect(resetButton).top),
      reason: 'اللافتة نازلة على الزرار',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('مقاس جهاز الاختبار الحقيقي: 720×1570', (tester) async {
    // الأرقام من لوج الجهاز اللي بيتجرّب عليه. العرض ٣٦٠ نقطة منطقية أضيق من
    // الـ٤٠٠ اللي فوق، فالذكر الطويل بيلف أكتر — وده أسوأ حالة للطول.
    SharedPreferences.setMockInitialValues({'index': longZikrIndex});
    tester.view.physicalSize = const Size(720, 1570);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(hostedLikeMainNavigation());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final double gap =
        tester.getRect(find.byType(AnimatedSwitcher)).top -
        tester
            .getRect(
              find
                  .ancestor(
                    of: find.textContaining('هدف اليوم'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .bottom;

    expect(gap, greaterThanOrEqualTo(AppSpace.xl), reason: 'الفراغ بقى $gap');
  });

  testWidgets('على شاشة قصيرة المحتوى بيتمرّر بدل ما يقع', (tester) async {
    SharedPreferences.setMockInitialValues({'index': longZikrIndex});
    usePhoneViewport(tester, height: 480);

    await tester.pumpWidget(hostedLikeMainNavigation());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // زرار إعادة الضبط آخر حاجة في العمود. على شاشة بالطول ده مفيش مكان
    // يبان فيه، فلازم التمرير يوصلنا له — وده الفرق بين "بيتمرّر" و"بيقع".
    final Finder resetButton = find.text('إعادة ضبط الإحصائيات');
    await tester.scrollUntilVisible(resetButton, 120);
    expect(resetButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
