import 'package:flutter/material.dart';
import 'package:hello_world/pages/chat_session.dart';

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

  void changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
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
