import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/chat_session.dart';
import 'providers/theme_provider.dart';
import 'themes/neon_dark.dart';
import 'themes/terminal_theme.dart';

void main() async {
  // Ensure Flutter bindings are initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Override the sharedPreferencesProvider with the actual instance
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const DecampApp(),
    ),
  );
}

class DecampApp extends ConsumerWidget {
  const DecampApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme provider to reactively rebuild when theme changes
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
      home: const ChatSession(),
    );
  }
}
