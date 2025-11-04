import 'package:flutter/material.dart';
import 'package:hello_world/pages/chat_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DecampApp());
}

class DecampApp extends StatefulWidget {
  const DecampApp({super.key});

  @override
  State<DecampApp> createState() => _DecampAppState();
}

class _DecampAppState extends State<DecampApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString('themeMode');

    setState(() {
      if (themeModeString != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == themeModeString,
          orElse: () => ThemeMode.system,
        );
      }
      _isLoading = false;
    });
  }

  Future<void> changeTheme(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });

    // Save to persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString());
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while loading theme preference
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Decamp AI Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: neonDarkTheme,
      themeMode: _themeMode,
      home: ChatSession(onThemeChanged: changeTheme),
    );
  }
}

final ThemeData neonDarkTheme = ThemeData(
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: Colors.cyan,
        brightness: Brightness.dark,
      ).copyWith(
        primary: Colors.cyan,
        secondary: Colors.purple,
        surface: const Color(0xFF0D1117),
        surfaceContainerHighest: const Color(0xFF161B22),
        primaryContainer: const Color(0xFF1F6FEB),
        onPrimaryContainer: Colors.white,
      ),
  useMaterial3: true,
);
