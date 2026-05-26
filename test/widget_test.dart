import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('أذكاري'))),
    );

    expect(find.text('أذكاري'), findsOneWidget);
  });
}
