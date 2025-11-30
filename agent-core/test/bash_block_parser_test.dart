import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/utils/bash_block_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BashBlockParser', () {
    test('parses single bash block', () {
      const text = '''
Here is a command:
```bash
ls -la
```
''';
      final toolCalls = BashBlockParser.parse(text);
      expect(toolCalls.length, 1);
      expect(toolCalls.first.function.name, 'execute_shell_command');
      
      final args = jsonDecode(toolCalls.first.function.arguments);
      expect(args['command'], 'ls -la');
    });

    test('throws exception for multiple bash blocks', () {
      const text = '''
First command:
```bash
echo "hello"
```
Second command:
```sh
ls
```
''';
      expect(
        () => BashBlockParser.parse(text),
        throwsA(isA<BashBlockFormatException>()),
      );
    });

    test('throws exception for empty block', () {
      const text = '''
Empty block:
```bash

```
''';
      expect(
        () => BashBlockParser.parse(text),
        throwsA(isA<BashBlockFormatException>()),
      );
    });

    test('handles multiline commands', () {
      const text = '''
```bash
echo "line 1"
echo "line 2"
```
''';
      final toolCalls = BashBlockParser.parse(text);
      expect(toolCalls.length, 1);
      
      final args = jsonDecode(toolCalls.first.function.arguments);
      expect(args['command'], 'echo "line 1"\necho "line 2"');
    });
  });
}
