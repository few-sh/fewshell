import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('stripAnsi', () {
    test('removes SGR color codes', () {
      expect(stripAnsi('\x1B[31mred\x1B[0m'), 'red');
      expect(stripAnsi('\x1B[1;38;5;202mhi\x1B[0m there'), 'hi there');
      expect(
        stripAnsi('\x1B[38;2;255;100;0mtruecolor\x1B[39m'),
        'truecolor',
      );
    });

    test('removes cursor and erase sequences', () {
      expect(stripAnsi('a\x1B[2Kb\x1B[Hc'), 'abc');
      expect(stripAnsi('x\x1B[10;20Hy'), 'xy');
    });

    test('removes OSC title-set sequences', () {
      expect(stripAnsi('\x1B]0;my title\x07prompt'), 'prompt');
      expect(stripAnsi('\x1B]2;t\x1B\\done'), 'done');
    });

    test('removes two-char ESC sequences', () {
      expect(stripAnsi('\x1B=foo\x1B>bar'), 'foobar');
    });

    test('preserves text without escape codes', () {
      expect(stripAnsi('hello world\nline 2'), 'hello world\nline 2');
    });

    test('preserves carriage returns and newlines', () {
      expect(stripAnsi('\x1B[31mfoo\x1B[0m\r\nbar\n'), 'foo\r\nbar\n');
    });
  });
}
