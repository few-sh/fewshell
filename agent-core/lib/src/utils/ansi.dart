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
