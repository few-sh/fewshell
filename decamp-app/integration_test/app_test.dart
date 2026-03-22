import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  initIntegrationTests();

  late TestServer server;

  setUpAll(() async {
    server = TestServer();
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
  });

  testWidgets('create project, create session, send chat message', (
    tester,
  ) async {
    final h = IntegrationTestHarness(server);
    await h.setUp(tester);

    // ---- Step 1: Verify we start on the ProjectsPage (empty) ----
    expect(find.text('No projects'), findsOneWidget);

    // ---- Step 2: Create a project and select it ----
    await h.createAndSelectProject('Test Project');

    // ---- Step 3: Verify ChatSession is displayed ----
    expect(find.text('No projects'), findsNothing);
    expect(find.byType(EditableText), findsWidgets);

    // ---- Step 4: Send a chat message ----
    const testMessage = 'Hello from integration test!';
    await h.sendMessage(testMessage);

    // ---- Step 5: Verify message was persisted ----
    final sessionId = h.currentSessionId;
    expect(sessionId, isNotNull);

    final messages = await h.sessionMessages(sessionId!);
    expect(messages, isNotEmpty);
    expect(
      messages.any((m) => m.content.contains(testMessage)),
      isTrue,
      reason: 'User message should be persisted in the database',
    );

    // ---- Step 6: Verify sync connection to in-process server ----
    await h.connectToServer();

    await h.tearDown();
  });
}
