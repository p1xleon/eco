// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eco/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Use ProviderScope since the app uses Riverpod
    await tester.pumpWidget(const ProviderScope(child: Eco()));

    // Wait for the app to settle
    await tester.pump();

    // Verify that the app renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
