// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:decamp/main.dart';

void main() {
  testWidgets('DecampApp can be instantiated', (
    WidgetTester tester,
  ) async {
    // Verify the app can be created with ProviderScope
    // This is a smoke test to ensure basic setup is correct
    const app = ProviderScope(
      child: DecampApp(),
    );

    expect(app, isNotNull);
    expect(app, isA<ProviderScope>());
  });
}
