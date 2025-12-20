import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:agent_core/agent_core.dart';
import 'pages/chat_session.dart';
import 'pages/projects_page.dart';
import 'providers/theme_provider.dart';
import 'providers/project_provider.dart';
import 'services/sync_service.dart';
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

  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    final packageInfo = await PackageInfo.fromPlatform();

    // Initialize SqliteLogger
    final sqliteLogger = SqliteLogger(
      dbPath: '${appDocDir.path}/logs.db',
      tableName: 'logs',
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      processId: pid.toString(),
    );
    globalSqliteLogger = sqliteLogger;
    _log.info('SqliteLogger initialized at ${appDocDir.path}/');
  } catch (e) {
    _log.severe('Failed to initialize SqliteLogger', e);
  }

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[TerminalTheme.light],
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        extensions: const <ThemeExtension<dynamic>>[TerminalTheme.dark],
      ),
      themeMode: themeMode,
      builder: (context, child) {
        final theme = Theme.of(context);
        return shadcn.Theme(
          data: shadcn.ThemeData(
            colorScheme: theme.brightness == Brightness.dark
                ? shadcn.LegacyColorSchemes.darkZinc()
                : shadcn.LegacyColorSchemes.lightZinc(),
            radius: 0.5,
          ),
          child: shadcn.ShadcnUI(child: child!),
        );
      },
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
