import 'dart:convert';
import 'package:llm_dart/llm_dart.dart';
import '../../../utils/id_generator.dart';
import '../../tools/system_tools.dart';

/// Exception thrown when bash block parsing fails
class BashBlockFormatException implements Exception {
  final String message;
  BashBlockFormatException(this.message);
  @override
  String toString() => message;
}

/// Utility to parse bash code blocks from text and convert them to ToolCalls
class BashBlockParser {
  /// Regex to find bash code blocks
  /// Matches ```bash ... ``` or ```sh ... ```
  /// Captures the content inside the block
  static final _bashBlockRegex = RegExp(
    r'```(?:bash|sh)\s*\n(.*?)\n```',
    multiLine: true,
    dotAll: true,
  );

  /// Parse text for bash blocks and return a list of ToolCalls
  /// Throws [BashBlockFormatException] if multiple blocks are found
  static List<ToolCall> parse(String text) {
    final matches = _bashBlockRegex.allMatches(text);

    if (matches.length > 1) {
      throw BashBlockFormatException(
        'Error: You provided multiple code blocks. Please provide EXACTLY ONE bash block per turn.',
      );
    }

    final toolCalls = <ToolCall>[];

    for (final match in matches) {
      final command = match.group(1)?.trim();
      if (command != null && command.isNotEmpty) {
        // Create a synthetic tool call for execute_shell_command
        toolCalls.add(
          ToolCall(
            id: IdGenerator.toolCallId(),
            callType: 'function',
            function: FunctionCall(
              name: kExecuteShellCommand,
              arguments: jsonEncode({'command': command}),
            ),
          ),
        );
      } else {
        // Empty block found
        throw BashBlockFormatException(
          'Error: You provided an empty bash block. Please provide a valid command.',
        );
      }
    }

    return toolCalls;
  }
}
