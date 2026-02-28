/// A string buffer that handles basic terminal control characters.
///
/// Uses a cursor model so that control characters reposition the cursor
/// and subsequent writes overwrite in-place, just like a real terminal.
///
/// Currently supports:
/// - `\r` (carriage return): moves the cursor to the beginning of the
///   current line. Subsequent writes overwrite existing characters.
/// - `\r\n`: treated as a single newline.
/// - `\b` (backspace): moves the cursor back one character
///   (does not cross newline boundaries).
class TerminalBuffer {
  final List<String> _chars = [];
  int _cursor = 0;

  /// Writes [data] to the buffer, processing terminal control characters.
  void write(String data) {
    for (var i = 0; i < data.length; i++) {
      final char = data[i];
      if (char == '\r') {
        // \r\n is a Windows-style newline — treat as a plain newline.
        if (i + 1 < data.length && data[i + 1] == '\n') {
          _writeNewline();
          i++; // skip the \n
          continue;
        }
        // Standalone \r: move cursor to start of current line.
        _cursor = _lineStart();
      } else if (char == '\n') {
        _writeNewline();
      } else if (char == '\b') {
        // Backspace: move cursor back one, but don't cross a newline.
        if (_cursor > 0 && _chars[_cursor - 1] != '\n') {
          _cursor--;
        }
      } else {
        // Regular character: overwrite at cursor or append.
        if (_cursor < _chars.length) {
          _chars[_cursor] = char;
        } else {
          _chars.add(char);
        }
        _cursor++;
      }
    }
  }

  /// Advances the cursor past the remaining content on the current line,
  /// then adds a newline (or passes through an existing one).
  void _writeNewline() {
    // Skip to end of current line content.
    while (_cursor < _chars.length && _chars[_cursor] != '\n') {
      _cursor++;
    }
    if (_cursor < _chars.length && _chars[_cursor] == '\n') {
      // Already a \n here — just move past it.
      _cursor++;
    } else {
      _chars.add('\n');
      _cursor++;
    }
  }

  /// Returns the index of the start of the current line (right after the
  /// last `\n` before [_cursor], or 0).
  int _lineStart() {
    var pos = _cursor - 1;
    while (pos >= 0 && _chars[pos] != '\n') {
      pos--;
    }
    return pos + 1;
  }

  @override
  String toString() => _chars.join();
}
