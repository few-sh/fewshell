import 'package:flutter/material.dart';

/// Terminal color scheme for code/command display areas.
/// Inspired by common terminal themes like VS Code's integrated terminal.
@immutable
class TerminalTheme extends ThemeExtension<TerminalTheme> {
  /// Background color for terminal-like areas
  final Color backgroundColor;

  /// Text color for terminal content
  final Color textColor;

  /// Border color for terminal containers
  final Color borderColor;

  /// Hint/placeholder text color
  final Color hintColor;

  /// Font family for monospace/code text
  final String monospaceFontFamily;

  const TerminalTheme({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.hintColor,
    this.monospaceFontFamily = 'RobotoMono',
  });

  /// Dark terminal theme (similar to VS Code dark terminal)
  static const dark = TerminalTheme(
    backgroundColor: Color(0xFF1E1E1E), // Dark grey, close to black
    textColor: Color(0xFF4ADE80), // Green accent (similar to terminal success)
    borderColor: Color(0xFF3E3E3E), // Medium grey border
    hintColor: Color(0xFF6E6E6E), // Muted grey for hints
  );

  /// Light terminal theme (inverted colors for light mode)
  static const light = TerminalTheme(
    backgroundColor: Color(0xFF2D2D2D), // Slightly lighter dark grey
    textColor: Color(0xFF22C55E), // Darker green for contrast
    borderColor: Color(0xFF1A1A1A), // Darker border
    hintColor: Color(0xFF808080), // Medium grey for hints
  );

  @override
  TerminalTheme copyWith({
    Color? backgroundColor,
    Color? textColor,
    Color? borderColor,
    Color? hintColor,
    String? monospaceFontFamily,
  }) {
    return TerminalTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      borderColor: borderColor ?? this.borderColor,
      hintColor: hintColor ?? this.hintColor,
      monospaceFontFamily: monospaceFontFamily ?? this.monospaceFontFamily,
    );
  }

  @override
  TerminalTheme lerp(ThemeExtension<TerminalTheme>? other, double t) {
    if (other is! TerminalTheme) {
      return this;
    }
    return TerminalTheme(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      hintColor: Color.lerp(hintColor, other.hintColor, t)!,
      monospaceFontFamily: t < 0.5
          ? monospaceFontFamily
          : other.monospaceFontFamily,
    );
  }
}
