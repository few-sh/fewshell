/// Utilities for handling ANSI/VT100 escape sequences.
///
/// Terminal output frequently contains escape sequences for colors,
/// cursor movement, and other control. These bytes are useful for
/// rendering in the UI but only add noise (and waste tokens) when fed
/// to an LLM. Use [stripAnsi] before sending tool results to the model.
library;

/// Matches:
///   - CSI sequences:    ESC `[` ... final-byte (`@` to `~`)
///   - OSC sequences:    ESC `]` ... terminator (BEL or ESC `\`)
///   - nF escapes:       ESC + intermediate (0x20-0x2F) + final (0x30-0x7E)
///                       (e.g. ESC `(` `B` for charset selection)
///   - Two-char ESC:     ESC + single byte (0x20-0x7E)
///                       (e.g. ESC `=`, ESC `>`, ESC `7`, ESC `M`, ...)
final RegExp _ansiPattern = RegExp(
  r'\x1B(?:'
  r'\[[0-?]*[ -/]*[@-~]'
  r'|\][^\x07\x1B]*(?:\x07|\x1B\\)'
  r'|[ -/][ -~]'
  r'|[ -~]'
  r')',
);

/// Returns [text] with all ANSI escape sequences removed.
String stripAnsi(String text) => text.replaceAll(_ansiPattern, '');

/// Result of [stripAnsiWithMap]: the visible text plus a mapping from
/// each visible code-unit index to the corresponding code-unit index in
/// the original text. The map has length `visible.length + 1`; the final
/// entry maps the end-of-text position so substring ranges round-trip
/// correctly.
class StrippedAnsi {
  final String visible;
  final List<int> visibleToRaw;
  const StrippedAnsi(this.visible, this.visibleToRaw);
}

/// Strips ANSI escapes from [text] and returns both the visible text and
/// a map from visible code-unit indices back to raw indices in [text].
/// Useful when running a regex against visible content but needing to
/// report match positions in the original (escape-containing) text.
StrippedAnsi stripAnsiWithMap(String text) {
  final buffer = StringBuffer();
  final map = <int>[];
  var raw = 0;
  for (final m in _ansiPattern.allMatches(text)) {
    while (raw < m.start) {
      map.add(raw);
      buffer.writeCharCode(text.codeUnitAt(raw));
      raw++;
    }
    raw = m.end;
  }
  while (raw < text.length) {
    map.add(raw);
    buffer.writeCharCode(text.codeUnitAt(raw));
    raw++;
  }
  map.add(text.length);
  return StrippedAnsi(buffer.toString(), map);
}
