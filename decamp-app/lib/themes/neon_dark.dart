import 'package:flutter/material.dart';
import 'terminal_theme.dart';

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
  extensions: const <ThemeExtension<dynamic>>[TerminalTheme.dark],
);
