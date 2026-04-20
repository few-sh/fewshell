import 'package:flutter/material.dart';
import 'package:decamp/themes/ansi_palette.dart';
import 'package:decamp/utils/highlight_injector.dart';

/// Mutable SGR (Select Graphic Rendition) state used while parsing
/// terminal output.
class _SgrState {
  Color? fg;
  Color? bg;
  bool bold = false;
  bool dim = false;
  bool italic = false;
  bool underline = false;
  bool reverse = false;
  bool strikethrough = false;

  void reset() {
    fg = null;
    bg = null;
    bold = false;
    dim = false;
    italic = false;
    underline = false;
    reverse = false;
    strikethrough = false;
  }

  TextStyle apply(TextStyle base, AnsiPalette palette, Color defaultFg) {
    var effectiveFg = fg ?? defaultFg;
    Color? effectiveBg = bg;
    if (reverse) {
      final swap = effectiveFg;
      effectiveFg = effectiveBg ?? base.backgroundColor ?? defaultFg;
      effectiveBg = swap;
    }
    var style = base.copyWith(
      color: dim ? effectiveFg.withValues(alpha: 0.6) : effectiveFg,
      backgroundColor: effectiveBg,
      fontWeight: bold ? FontWeight.bold : base.fontWeight,
      fontStyle: italic ? FontStyle.italic : base.fontStyle,
    );
    if (underline || strikethrough) {
      final decorations = <TextDecoration>[
        if (underline) TextDecoration.underline,
        if (strikethrough) TextDecoration.lineThrough,
      ];
      style = style.copyWith(
        decoration: TextDecoration.combine(decorations),
        decorationColor: effectiveFg,
      );
    }
    return style;
  }
}

/// xterm 256-color palette resolver. Returns the color for index 0..255.
Color _xterm256(int index, AnsiPalette palette) {
  if (index < 16) return palette.color(index);
  if (index < 232) {
    // 6x6x6 color cube. xterm levels: 0, 95, 135, 175, 215, 255.
    const levels = [0, 95, 135, 175, 215, 255];
    final n = index - 16;
    final r = levels[(n ~/ 36) % 6];
    final g = levels[(n ~/ 6) % 6];
    final b = levels[n % 6];
    return Color.fromARGB(255, r, g, b);
  }
  // Grayscale ramp 232..255 -> 8..238 in steps of 10.
  final v = 8 + (index - 232) * 10;
  return Color.fromARGB(255, v, v, v);
}

/// Parses [text] containing ANSI SGR codes (and stripping other CSI/OSC
/// sequences) and returns a `TextSpan` with appropriate styling.
///
/// Highlight overlays use offsets in the raw [text] (matching the
/// positions produced by `HighlightInjector.extractFromCode`).
TextSpan buildAnsiTextSpan({
  required String text,
  required TextStyle baseStyle,
  required AnsiPalette palette,
  required Color defaultForeground,
  List<CodeHighlight> highlights = const [],
  Color? activeHighlightColor,
  Color? inactiveHighlightColor,
}) {
  final state = _SgrState();
  final spans = <TextSpan>[];

  // Sort highlights by offset for efficient lookup.
  final sortedHighlights = highlights.toList()
    ..sort((a, b) => a.offset.compareTo(b.offset));

  // Buffer the run of visible characters that share the same style.
  final runBuffer = StringBuffer();
  TextStyle? runStyle;
  Color? runHighlightColor;

  void flushRun() {
    if (runBuffer.isEmpty) return;
    spans.add(
      TextSpan(
        text: runBuffer.toString(),
        style: runStyle?.copyWith(backgroundColor: runHighlightColor),
      ),
    );
    runBuffer.clear();
  }

  Color? highlightColorAt(int rawIndex) {
    for (final h in sortedHighlights) {
      if (rawIndex < h.offset) return null;
      if (rawIndex < h.offset + h.length) {
        return h.isActive ? activeHighlightColor : inactiveHighlightColor;
      }
    }
    return null;
  }

  var i = 0;
  while (i < text.length) {
    final ch = text.codeUnitAt(i);
    if (ch == 0x1B) {
      // Escape sequence: try to consume it, otherwise skip the ESC.
      final consumed = _consumeEscape(text, i, state, palette);
      if (consumed > 0) {
        i += consumed;
        continue;
      }
      // Unrecognized — drop the ESC and continue.
      i++;
      continue;
    }

    final style = state.apply(baseStyle, palette, defaultForeground);
    final hl = highlightColorAt(i);
    if (runStyle == null || style != runStyle || hl != runHighlightColor) {
      flushRun();
      runStyle = style;
      runHighlightColor = hl;
    }
    runBuffer.writeCharCode(ch);
    i++;
  }
  flushRun();

  return TextSpan(style: baseStyle, children: spans);
}

/// Consumes an escape sequence starting at [start]. Returns the number of
/// code units consumed (including the leading ESC), or 0 if not recognized.
/// Updates [state] for SGR sequences; other sequences are silently dropped.
int _consumeEscape(
  String text,
  int start,
  _SgrState state,
  AnsiPalette palette,
) {
  if (start + 1 >= text.length) return 1; // lone ESC at end
  final next = text.codeUnitAt(start + 1);

  // CSI: ESC [ params... final
  if (next == 0x5B /* [ */ ) {
    var j = start + 2;
    final params = StringBuffer();
    // Parameter bytes 0x30-0x3F
    while (j < text.length) {
      final c = text.codeUnitAt(j);
      if (c >= 0x30 && c <= 0x3F) {
        params.writeCharCode(c);
        j++;
      } else {
        break;
      }
    }
    // Intermediate bytes 0x20-0x2F
    while (j < text.length) {
      final c = text.codeUnitAt(j);
      if (c >= 0x20 && c <= 0x2F) {
        j++;
      } else {
        break;
      }
    }
    // Final byte 0x40-0x7E
    if (j >= text.length) return text.length - start;
    final finalByte = text.codeUnitAt(j);
    j++;
    if (finalByte == 0x6D /* m */ ) {
      _applySgr(params.toString(), state, palette);
    }
    // Other CSI sequences (cursor moves, erase, etc.) are dropped.
    return j - start;
  }

  // OSC: ESC ] ... BEL or ESC \
  if (next == 0x5D /* ] */ ) {
    var j = start + 2;
    while (j < text.length) {
      final c = text.codeUnitAt(j);
      if (c == 0x07) {
        return j - start + 1;
      }
      if (c == 0x1B && j + 1 < text.length && text.codeUnitAt(j + 1) == 0x5C) {
        return j - start + 2;
      }
      j++;
    }
    return text.length - start;
  }

  // nF escape: ESC + intermediate (0x20-0x2F) + final (0x30-0x7E)
  if (next >= 0x20 && next <= 0x2F) {
    if (start + 2 < text.length) return 3;
    return text.length - start;
  }

  // Single-byte escape: ESC + (0x20-0x7E)
  if (next >= 0x20 && next <= 0x7E) {
    return 2;
  }

  return 1;
}

void _applySgr(String params, _SgrState state, AnsiPalette palette) {
  // Empty params == "0" (reset).
  if (params.isEmpty) {
    state.reset();
    return;
  }
  final tokens = params.split(';').map((t) => int.tryParse(t) ?? 0).toList();

  var i = 0;
  while (i < tokens.length) {
    final code = tokens[i];
    switch (code) {
      case 0:
        state.reset();
      case 1:
        state.bold = true;
      case 2:
        state.dim = true;
      case 3:
        state.italic = true;
      case 4:
        state.underline = true;
      case 7:
        state.reverse = true;
      case 9:
        state.strikethrough = true;
      case 21:
      case 22:
        state.bold = false;
        state.dim = false;
      case 23:
        state.italic = false;
      case 24:
        state.underline = false;
      case 27:
        state.reverse = false;
      case 29:
        state.strikethrough = false;
      case >= 30 && <= 37:
        state.fg = palette.color(code - 30);
      case 38:
        // Extended foreground: 38;5;N or 38;2;R;G;B
        final result = _parseExtendedColor(tokens, i + 1, palette);
        if (result != null) {
          state.fg = result.color;
          i += result.consumed;
        }
      case 39:
        state.fg = null;
      case >= 40 && <= 47:
        state.bg = palette.color(code - 40);
      case 48:
        final result = _parseExtendedColor(tokens, i + 1, palette);
        if (result != null) {
          state.bg = result.color;
          i += result.consumed;
        }
      case 49:
        state.bg = null;
      case >= 90 && <= 97:
        state.fg = palette.color(code - 90 + 8);
      case >= 100 && <= 107:
        state.bg = palette.color(code - 100 + 8);
      default:
        // Unsupported SGR code; ignore.
        break;
    }
    i++;
  }
}

class _ExtendedColor {
  final Color color;
  final int consumed; // tokens consumed *after* the 38/48 marker
  _ExtendedColor(this.color, this.consumed);
}

_ExtendedColor? _parseExtendedColor(
  List<int> tokens,
  int start,
  AnsiPalette palette,
) {
  if (start >= tokens.length) return null;
  final mode = tokens[start];
  if (mode == 5) {
    // 256-color: 38;5;N
    if (start + 1 >= tokens.length) return null;
    final idx = tokens[start + 1].clamp(0, 255);
    return _ExtendedColor(_xterm256(idx, palette), 2);
  }
  if (mode == 2) {
    // Truecolor: 38;2;R;G;B
    if (start + 3 >= tokens.length) return null;
    final r = tokens[start + 1].clamp(0, 255);
    final g = tokens[start + 2].clamp(0, 255);
    final b = tokens[start + 3].clamp(0, 255);
    return _ExtendedColor(Color.fromARGB(255, r, g, b), 4);
  }
  return null;
}
