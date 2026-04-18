import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'terminal_theme.dart';
import 'shad_layout_theme.dart';

const neonLightShadColorScheme = ShadColorScheme(
  background: Colors.white,
  foreground: Color(0xFF0B0C2A),
  card: Colors.white,
  cardForeground: Color(0xFF0B0C2A),
  popover: Colors.white,
  popoverForeground: Color(0xFF0B0C2A),
  primary: Color(0xFF8A2EFF),
  primaryForeground: Colors.white,
  secondary: Color(0xFF00E5FF),
  secondaryForeground: Colors.black,
  muted: Color(0xFFF1F5F9),
  mutedForeground: Color(0xFF64748B),
  accent: Color(0xFFFF4DFF),
  accentForeground: Colors.white,
  destructive: Color(0xFFFF453A),
  destructiveForeground: Colors.white,
  border: Color(0xFFE2E8F0),
  input: Colors.white,
  ring: Color(0xFF8A2EFF),
  selection: Color(0xFF8A2EFF),
);

final neonLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  cardColor: Colors.white,
  primaryColor: const Color(0xFF8A2EFF),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF8A2EFF),
    secondary: Color(0xFF00E5FF),
    tertiary: Color(0xFFFF4DFF),
    surface: Colors.white,
  ),
  fontFamily: 'Roboto',
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF0B0C2A)),
    bodyMedium: TextStyle(color: Color(0xFF64748B)),
    titleLarge: TextStyle(
      color: Color(0xFF8A2EFF),
      fontWeight: FontWeight.bold,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF0B0C2A),
    elevation: 0,
  ),
  buttonTheme: const ButtonThemeData(
    buttonColor: Color(0xFFFF4DFF),
    textTheme: ButtonTextTheme.primary,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF00E5FF),
    foregroundColor: Colors.black,
  ),
  extensions: const <ThemeExtension<dynamic>>[
    TerminalTheme.light,
    ShadLayoutTheme(pagePadding: EdgeInsets.all(16)),
  ],
);
