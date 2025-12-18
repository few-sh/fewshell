import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'pages/chat_session.dart';
import 'pages/projects_page.dart';
import 'providers/theme_provider.dart';
import 'providers/project_provider.dart';
import 'services/sync_service.dart';
import 'themes/neon_dark.dart';
import 'themes/terminal_theme.dart';
import 'utils/globals.dart';

final _log = Logger('DecampApp');

void main() async {
  // Configure logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '${record.time.toIso8601String()} [${record.loggerName}] ${record.level.name}: ${record.message}',
    );
    if (record.error != null) {
      debugPrint('Error: ${record.error}');
      if (record.stackTrace != null) {
        debugPrint('Stack trace:\n${record.stackTrace}');
      }
    }
  });

  _log.info('main() started');
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();
  _log.info('WidgetsFlutterBinding initialized');

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  _log.info('SharedPreferences initialized');

  runApp(
    ProviderScope(
      overrides: [
        // Override the sharedPreferencesProvider with the actual instance
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const DecampApp(),
    ),
  );
  _log.info('runApp called');
}

class DecampApp extends ConsumerWidget {
  const DecampApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _log.info('build called');
    try {
      // Initialize SyncService
      ref.watch(syncServiceProvider);
      _log.info('SyncService initialized');
    } catch (e, st) {
      _log.severe('Error initializing SyncService', e, st);
    }

    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
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
