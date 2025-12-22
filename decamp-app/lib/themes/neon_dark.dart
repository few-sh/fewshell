import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'terminal_theme.dart';
import 'shad_layout_theme.dart';

const neonShadColorScheme = ShadColorScheme(
  background: Color(0xFF0B0C2A),
  foreground: Color(0xFFEAEAEA),
  card: Color(0xFF14143A),
  cardForeground: Color(0xFFEAEAEA),
  popover: Color(0xFF14143A),
  popoverForeground: Color(0xFFEAEAEA),
  primary: Color(0xFF8A2EFF),
  primaryForeground: Colors.white,
  secondary: Color(0xFF00E5FF),
  secondaryForeground: Colors.black,
  muted: Color(0xFF1E1E4E),
  mutedForeground: Color(0xFFA1A3C1),
  accent: Color(0xFFFF4DFF),
  accentForeground: Colors.white,
  destructive: Color(0xFFFF453A),
  destructiveForeground: Colors.white,
  border: Color(0xFF2A2D5C),
  input: Color(0xFF2A2D5C),
  ring: Color(0xFF8A2EFF),
  selection: Color(0xFF8A2EFF),
);

final neonDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0B0C2A),
  cardColor: const Color(0xFF14143A),
  primaryColor: const Color(0xFF8A2EFF),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF8A2EFF),
    secondary: Color(0xFF00E5FF),
    tertiary: Color(0xFFFF4DFF),
    surface: Color(0xFF14143A),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFFEAEAEA)),
    bodyMedium: TextStyle(color: Color(0xFFA1A3C1)),
    titleLarge: TextStyle(
      color: Color(0xFF8A2EFF),
      fontWeight: FontWeight.bold,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0B0C2A),
    foregroundColor: Color(0xFFEAEAEA),
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
    TerminalTheme.dark,
    ShadLayoutTheme(pagePadding: EdgeInsets.all(16)),
  ],
);
