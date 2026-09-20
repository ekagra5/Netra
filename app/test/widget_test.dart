// Smoke test: the app boots to the onboarding screen without throwing,
// even with no model asset present (CI/test environments won't have the
// real .tflite bundled) and shows the "Get Started" action.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:netra/main.dart';

void main() {
  setUpAll(() async {
    // Tests run on the host machine, which has no sqflite platform plugin, so
    // back the app's database with the FFI implementation in a temp directory.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('netra_test_').path,
    );
  });

  testWidgets('boots to onboarding screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NetraRoot());
    await tester.pump();

    expect(find.text('Netra'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'Get Started'), findsOneWidget);
  });
}
