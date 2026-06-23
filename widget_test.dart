import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/main.dart';

void main() {
  testWidgets('MoneyVore app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    
    expect(find.text('MoneyVore'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Нет записей'), findsOneWidget);
  });
}