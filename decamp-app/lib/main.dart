import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'dart:developer' as developer;
import 'pages/chat_session.dart';
import 'pages/projects_page.dart';
import 'providers/theme_provider.dart';
import 'providers/project_provider.dart';
import 'services/sync_service.dart';
import 'themes/neon_dark.dart';
import 'themes/terminal_theme.dart';

void main() async {
  developer.log('App: main() started');
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('App: WidgetsFlutterBinding initialized');

  // Configure logging for AnthropicClient
  // Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}',
      name: record.loggerName,
      level: record.level.value,
      time: record.time,
    );
  });

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  developer.log('App: SharedPreferences initialized');

  runApp(
    ProviderScope(
      overrides: [
        // Override the sharedPreferencesProvider with the actual instance
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const DecampApp(),
    ),
  );
  developer.log('App: runApp called');
}

class DecampApp extends ConsumerWidget {
  const DecampApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    developer.log('DecampApp: build called');
    try {
      // Initialize SyncService
      ref.watch(syncServiceProvider);
      developer.log('DecampApp: SyncService initialized');
    } catch (e, st) {
      developer.log(
        'DecampApp: Error initializing SyncService',
        error: e,
        stackTrace: st,
      );
    }

    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Decamp AI Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[TerminalTheme.light],
      ),
      darkTheme: neonDarkTheme,
      themeMode: themeMode,
      home: const _HomeSelector(),
    );
  }
}

class _HomeSelector extends ConsumerWidget {
  const _HomeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    return currentProject == null ? const ProjectsPage() : const ChatSession();
  }
}
