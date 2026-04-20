import 'package:flutter/material.dart';

/// 16-color palette for ANSI terminal output (8 normal + 8 bright).
///
/// Used to render output of shell commands that contain SGR color codes
/// like `\x1B[31m` (red) or `\x1B[1;38;5;202m` (256-color). 256-color and
/// truecolor codes are resolved against this palette for the first 16
/// indices, then computed from the standard xterm cube/grayscale ramp.
@immutable
class AnsiPalette {
  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;
  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;

  const AnsiPalette({
    required this.black,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.white,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
  });

  /// Returns the color for ANSI index 0..15.
  Color color(int index) {
    switch (index) {
      case 0:
        return black;
      case 1:
        return red;
      case 2:
        return green;
      case 3:
        return yellow;
      case 4:
        return blue;
      case 5:
        return magenta;
      case 6:
        return cyan;
      case 7:
        return white;
      case 8:
        return brightBlack;
      case 9:
        return brightRed;
      case 10:
        return brightGreen;
      case 11:
        return brightYellow;
      case 12:
        return brightBlue;
      case 13:
        return brightMagenta;
      case 14:
        return brightCyan;
      case 15:
        return brightWhite;
      default:
        return white;
    }
  }

  /// Standard xterm palette tuned for dark backgrounds.
  static const xtermDark = AnsiPalette(
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF0DBC79),
    yellow: Color(0xFFE5E510),
    blue: Color(0xFF2472C8),
    magenta: Color(0xFFBC3FBC),
    cyan: Color(0xFF11A8CD),
    white: Color(0xFFE5E5E5),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFF14C4C),
    brightGreen: Color(0xFF23D18B),
    brightYellow: Color(0xFFF5F543),
    brightBlue: Color(0xFF3B8EEA),
    brightMagenta: Color(0xFFD670D6),
    brightCyan: Color(0xFF29B8DB),
    brightWhite: Color(0xFFFFFFFF),
  );

  /// Standard xterm palette tuned for light backgrounds.
  /// (Same hues, slightly darker for contrast.)
  static const xtermLight = AnsiPalette(
    black: Color(0xFF000000),
    red: Color(0xFFC91B00),
    green: Color(0xFF00A55D),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF1F61A0),
    magenta: Color(0xFFA535A5),
    cyan: Color(0xFF008B8B),
    white: Color(0xFFCCCCCC),
    brightBlack: Color(0xFF555555),
    brightRed: Color(0xFFCD3131),
    brightGreen: Color(0xFF0DBC79),
    brightYellow: Color(0xFFE5E510),
    brightBlue: Color(0xFF2472C8),
    brightMagenta: Color(0xFFBC3FBC),
    brightCyan: Color(0xFF11A8CD),
    brightWhite: Color(0xFFE5E5E5),
  );

  AnsiPalette copyWith({
    Color? black,
    Color? red,
    Color? green,
    Color? yellow,
    Color? blue,
    Color? magenta,
    Color? cyan,
    Color? white,
    Color? brightBlack,
    Color? brightRed,
    Color? brightGreen,
    Color? brightYellow,
    Color? brightBlue,
    Color? brightMagenta,
    Color? brightCyan,
    Color? brightWhite,
  }) {
    return AnsiPalette(
      black: black ?? this.black,
      red: red ?? this.red,
      green: green ?? this.green,
      yellow: yellow ?? this.yellow,
      blue: blue ?? this.blue,
      magenta: magenta ?? this.magenta,
      cyan: cyan ?? this.cyan,
      white: white ?? this.white,
      brightBlack: brightBlack ?? this.brightBlack,
      brightRed: brightRed ?? this.brightRed,
      brightGreen: brightGreen ?? this.brightGreen,
      brightYellow: brightYellow ?? this.brightYellow,
      brightBlue: brightBlue ?? this.brightBlue,
      brightMagenta: brightMagenta ?? this.brightMagenta,
      brightCyan: brightCyan ?? this.brightCyan,
      brightWhite: brightWhite ?? this.brightWhite,
    );
  }

  static AnsiPalette lerp(AnsiPalette a, AnsiPalette b, double t) {
    return AnsiPalette(
      black: Color.lerp(a.black, b.black, t)!,
      red: Color.lerp(a.red, b.red, t)!,
      green: Color.lerp(a.green, b.green, t)!,
      yellow: Color.lerp(a.yellow, b.yellow, t)!,
      blue: Color.lerp(a.blue, b.blue, t)!,
      magenta: Color.lerp(a.magenta, b.magenta, t)!,
      cyan: Color.lerp(a.cyan, b.cyan, t)!,
      white: Color.lerp(a.white, b.white, t)!,
      brightBlack: Color.lerp(a.brightBlack, b.brightBlack, t)!,
      brightRed: Color.lerp(a.brightRed, b.brightRed, t)!,
      brightGreen: Color.lerp(a.brightGreen, b.brightGreen, t)!,
      brightYellow: Color.lerp(a.brightYellow, b.brightYellow, t)!,
      brightBlue: Color.lerp(a.brightBlue, b.brightBlue, t)!,
      brightMagenta: Color.lerp(a.brightMagenta, b.brightMagenta, t)!,
      brightCyan: Color.lerp(a.brightCyan, b.brightCyan, t)!,
      brightWhite: Color.lerp(a.brightWhite, b.brightWhite, t)!,
    );
  }
}
