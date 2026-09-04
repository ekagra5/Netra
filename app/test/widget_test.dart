// Smoke test: the app boots to the onboarding screen without throwing,
// even with no model asset present (CI/test environments won't have the
// real .tflite bundled) and shows the "Get Started" action.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:netra/main.dart';

void main() {
  testWidgets('boots to onboarding screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NetraRoot());
    await tester.pump();

    expect(find.text('Netra'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'Get Started'), findsOneWidget);
  });
}
