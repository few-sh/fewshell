import 'dart:convert';
import 'dart:developer' as developer;

import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_dart/llm_dart.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

import '../services/llm_service.dart';
import '../services/shell_service.dart';
import 'project_provider.dart';

/// Provider for the SessionController bound to the current project.
///
/// Quake-style pattern: Same interface, different transport:
/// - Local project: LocalSessionController (runs agent loop in-process)
/// - Remote project: RemoteSessionController (WebSocket to decamp-agent)
///
/// The UI should use only this controller for sessions/messages operations.
/// No direct DAO calls needed anymore.
///
/// Note: NOT autoDispose - we want this to persist while the project is selected.
/// Disposing happens when project changes via ref.watch(currentProjectProvider).
final sessionControllerProvider = FutureProvider<SessionController?>((
  ref,
) async {
  final project = ref.watch(currentProjectProvider);
  if (project == null) return null;

  SessionController controller;

  if (project.serverUrl != null && project.serverUrl!.isNotEmpty) {
    // Remote project: Use RemoteSessionController
    developer.log(
      '🌐 Creating RemoteSessionController for ${project.name}',
      name: 'SessionControllerProvider',
    );

    controller = RemoteSessionController(
      serverUrl: project.serverUrl!,
      projectId: project.id,
    );
  } else {
    // Local project: Use LocalSessionController
    developer.log(
      '🏠 Creating LocalSessionController for ${project.name}',
      name: 'SessionControllerProvider',
    );

    // Get database path
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(appDir.path, 'decamp', 'local.db');
    final dbDir = Directory(path.dirname(dbPath));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }

    // Apply SQLite workaround for old Android (from sqlite3_flutter_libs)
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

    // Create store
    final store = SqliteSessionStore.open(dbPath);

    // Get LLM service and shell service for tool execution
    final llmService = ref.watch(llmServiceProvider);
    final shellService = ref.watch(shellServiceProvider(project.id));

    // Create LLM client factory
    Future<ChatCapability?> createLlmClient() async {
      return await llmService.createClient();
    }

    // Create tool executor
    Future<String> executeToolCall(ToolCall toolCall) async {
      final result = await _executeToolCallWithShellService(
        toolCall,
        shellService,
      );
      return result;
    }

    controller = LocalSessionController(
      projectId: project.id,
      store: store,
      createLlmClient: createLlmClient,
      executeToolCall: executeToolCall,
    );
  }

  // Connect
  final connected = await controller.connect();
  if (!connected) {
    developer.log(
      '❌ Failed to connect SessionController',
      name: 'SessionControllerProvider',
    );
    return null;
  }

  // Dispose on ref disposal
  ref.onDispose(() {
    developer.log(
      '🗑️ Disposing SessionController',
      name: 'SessionControllerProvider',
    );
    controller.dispose();
  });

  return controller;
});

/// Execute a tool call using the shell service.
/// Returns JSON string result.
Future<String> _executeToolCallWithShellService(
  ToolCall toolCall,
  ShellService shellService,
) async {
  final functionName = toolCall.function.name;
  // arguments is a JSON string, decode it
  final argsMap =
      jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;

  developer.log(
    '🔧 Executing tool: $functionName with args: $argsMap',
    name: 'SessionControllerProvider',
  );

  try {
    switch (functionName) {
      case 'run_command':
        final command = argsMap['command'] as String?;
        if (command == null || command.isEmpty) {
          return jsonEncode({'error': 'command is required'});
        }

        final result = await shellService.executeCommand(command);
        return jsonEncode(result);

      default:
        return jsonEncode({'error': 'Unknown tool: $functionName'});
    }
  } catch (e) {
    developer.log(
      '❌ Tool execution error: $e',
      name: 'SessionControllerProvider',
    );
    return jsonEncode({'error': e.toString()});
  }
}

/// Watch sessions for current project via SessionController.
/// This replaces the old currentProjectSessionsProvider that used direct DAO.
final controllerSessionsProvider = StreamProvider<List<Session>>((ref) async* {
  final controllerAsync = ref.watch(sessionControllerProvider);

  final controller = controllerAsync.when(
    data: (c) => c,
    loading: () => null,
    error: (_, __) => null,
  );

  if (controller == null) {
    yield [];
    return;
  }

  yield* controller.watchActiveSessions();
});

/// Watch archived sessions via SessionController.
final controllerArchivedSessionsProvider = StreamProvider<List<Session>>((
  ref,
) async* {
  final controllerAsync = ref.watch(sessionControllerProvider);

  final controller = controllerAsync.when(
    data: (c) => c,
    loading: () => null,
    error: (_, __) => null,
  );

  if (controller == null) {
    yield [];
    return;
  }

  yield* controller.watchArchivedSessions();
});

/// Watch messages for current session via SessionController.
final controllerMessagesProvider = StreamProvider.family<List<Message>, String>(
  (ref, sessionId) async* {
    final controllerAsync = ref.watch(sessionControllerProvider);

    final controller = controllerAsync.when(
      data: (c) => c,
      loading: () => null,
      error: (_, __) => null,
    );

    if (controller == null) {
      yield [];
      return;
    }

    yield* controller.watchMessages(sessionId);
  },
);
