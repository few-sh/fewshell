import 'dart:convert';
import 'package:llm_dart/llm_dart.dart';
import '../services/shell_tools_provider.dart'
    show kExecuteShellCommand, kFetch;

/// Formats tool execution results with pretty markdown templates
///
/// Supports different formatting strategies for different tool types.
/// Each tool can have its own markdown template that structures the
/// output in a user-friendly way.
///
/// Currently supported tools:
/// - `execute_shell_command`: Formats command, exit code, stdout, stderr
///
/// Example usage:
/// ```dart
/// final formatted = ToolResultFormatter.format(
///   toolName: 'execute_shell_command',
///   result: jsonEncode({
///     'command': 'ls -la',
///     'exitCode': 0,
///     'stdout': 'total 24\ndrwxr-xr-x  5 user  staff  160 Nov 18 10:00 .\n...',
///     'stderr': '',
///     'success': true,
///   }),
/// );
/// ```
class ToolResultFormatter {
  /// Format tool use message (tool calls)
  static String formatToolUse({
    required List<ToolCall> toolCalls,
    String? textContent,
  }) {
    final buffer = StringBuffer();

    // Add any text content if present
    if (textContent != null && textContent.isNotEmpty) {
      buffer.writeln(textContent);
      buffer.writeln();
    }

    for (final toolCall in toolCalls) {
      // Special handling for execute_shell_command
      if (toolCall.function.name == kExecuteShellCommand) {
        try {
          final args =
              jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
          final explanation = args['explanation'] as String? ?? '';
          final command = args['command'] as String? ?? 'unknown';
          final sudoRequired = args['sudo_required'] as bool? ?? false;

          // Show explanation if present
          if (explanation.isNotEmpty) {
            buffer.writeln('*$explanation*\n');
          }

          // Command with sudo warning if required
          if (sudoRequired) {
            buffer.writeln('> ⚠️ **This command requires sudo privileges**\n');
            buffer.writeln('```bash');
            buffer.writeln('sudo \$ $command');
            buffer.writeln('```');
          } else {
            buffer.writeln('```bash');
            buffer.writeln('\$ $command');
            buffer.writeln('```');
          }
          buffer.writeln();
          continue;
        } catch (e) {
          // Fall through to generic handling
        }
      }

      // Special handling for fetch
      if (toolCall.function.name == kFetch) {
        try {
          final args =
              jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
          final explanation = args['explanation'] as String? ?? '';
          final url = args['url'] as String? ?? 'unknown';
          final method = (args['method'] as String?)?.toUpperCase() ?? 'GET';
          final headers = args['headers'] as Map<String, dynamic>?;
          final body = args['body'] as String?;

          // Show explanation if present
          if (explanation.isNotEmpty) {
            buffer.writeln('*$explanation*\n');
          }

          buffer.writeln('🌐 **$method** `$url`');

          if (headers != null && headers.isNotEmpty) {
            buffer.writeln('\n**Headers:**');
            for (final entry in headers.entries) {
              buffer.writeln('- `${entry.key}`: ${entry.value}');
            }
          }

          if (body != null && body.isNotEmpty) {
            buffer.writeln('\n**Request Body:**');
            buffer.writeln('```');
            // Truncate long bodies
            if (body.length > 500) {
              buffer.writeln('${body.substring(0, 500)}...');
            } else {
              buffer.writeln(body);
            }
            buffer.writeln('```');
          }

          buffer.writeln();
          continue;
        } catch (e) {
          // Fall through to generic handling
        }
      }

      // Generic tool call formatting
      buffer.writeln('🔧 **${toolCall.function.name}**');

      // Try to parse arguments as JSON for pretty display
      try {
        final args =
            jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
        if (args.isNotEmpty) {
          buffer.writeln('```json');
          buffer.writeln(JsonEncoder.withIndent('  ').convert(args));
          buffer.writeln('```');
        }
      } catch (e) {
        // If not JSON, display as-is
        if (toolCall.function.arguments.isNotEmpty) {
          buffer.writeln('```');
          buffer.writeln(toolCall.function.arguments);
          buffer.writeln('```');
        }
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Format a tool result based on the tool name
  static String format({
    required String toolName,
    required String result,
    ToolCall? originalToolCall,
    String? toolCallId,
  }) {
    // Parse the result JSON
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(result) as Map<String, dynamic>;
    } catch (e) {
      // If result is not JSON, return it as-is with basic formatting
      return _formatUnknownTool(toolName, result);
    }

    // Route to specific formatter based on tool name
    return switch (toolName) {
      kExecuteShellCommand =>
        _formatShellCommand(data, originalToolCall, toolCallId),
      kFetch => _formatFetchResult(data),
      _ => _formatUnknownTool(toolName, result),
    };
  }

  /// Format shell command execution results
  ///
  /// Displays:
  /// - Success/failure status with emoji
  /// - Command that was executed
  /// - Exit code (if non-zero or failed)
  /// - Standard output (if available)
  /// - Standard error (if available, labeled as warnings or errors based on success)
  static String _formatShellCommand(
    Map<String, dynamic> data,
    ToolCall? originalToolCall,
    String? toolCallId,
  ) {
    final buffer = StringBuffer();

    final exitCode = data['exitCode'] as int? ?? -1;
    final stdout = (data['stdout']?.toString() ?? '').trim();
    final stderr = (data['stderr']?.toString() ?? '').trim();
    final success = data['success'] as bool? ?? (exitCode == 0);
    final isStreaming = data['isStreaming'] as bool? ?? false;

    String? originalCommand;
    if (originalToolCall != null) {
      try {
        final args = jsonDecode(originalToolCall.function.arguments)
            as Map<String, dynamic>;
        originalCommand = args['command'] as String? ?? '';
      } catch (e) {
        // Ignore parsing errors, use empty command
      }
    }

    // Stdout section (if available)
    if (stdout.isNotEmpty) {
      // Try to detect if output looks like it should have syntax highlighting
      final language = _detectLanguage(stdout);
      buffer.writeln('```$language');
      buffer.writeln(stdout);
      buffer.writeln('```');
    }

    // Stderr section (if available)
    if (stderr.isNotEmpty) {
      if (success) {
        buffer.writeln('**Warnings:**');
      } else {
        buffer.writeln('**Error Output:**');
      }
      buffer.writeln('```');
      buffer.writeln(stderr);
      buffer.writeln('```');
    }

    if (isStreaming) {
      buffer.write('⏳ In progress: ');
    } else if (success) {
      buffer.write('✅ Done: ');
    } else {
      buffer.write('❌ FAIL: ');
    }

    if (originalCommand != null && originalCommand.isNotEmpty) {
      buffer.write('`${originalCommand.trim()}`');
    }
    if (exitCode != 0) {
      buffer.write(' (exit code: **$exitCode**)');
    }

    buffer.writeln();

    // If no output at all
    if (stdout.isEmpty && stderr.isEmpty) {
      buffer.writeln('*No output*\n');
    }

    return buffer.toString().trim();
  }

  /// Format HTTP fetch results
  ///
  /// Displays:
  /// - Success/failure status
  /// - HTTP method and URL
  /// - Status code
  /// - Response headers (key headers only)
  /// - Response body with syntax highlighting
  static String _formatFetchResult(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    final statusCode = data['statusCode'] as int? ?? 0;
    final method = data['method'] as String? ?? 'GET';
    final url = data['url'] as String? ?? '';
    final headers = data['headers'] as Map<String, dynamic>? ?? {};
    final body = (data['body']?.toString() ?? '').trim();
    final success =
        data['success'] as bool? ?? (statusCode >= 200 && statusCode < 300);

    // Header with status
    if (success) {
      buffer.writeln('✅ **HTTP $statusCode** - Request Successful\n');
    } else {
      buffer.writeln('❌ **HTTP $statusCode** - Request Failed\n');
    }

    // Request details
    buffer.writeln('**$method** `$url`\n');

    // Show key response headers
    final keyHeaders = ['content-type', 'content-length', 'server'];
    final foundHeaders = <String, String>{};
    for (final key in keyHeaders) {
      final value = headers[key];
      if (value != null) {
        foundHeaders[key] = value.toString();
      }
    }

    if (foundHeaders.isNotEmpty) {
      buffer.writeln('**Headers:**');
      for (final entry in foundHeaders.entries) {
        buffer.writeln('- `${entry.key}`: ${entry.value}');
      }
      buffer.writeln();
    }

    // Response body
    if (body.isNotEmpty) {
      buffer.writeln('**Response Body:**');
      final language = _detectLanguage(body);
      buffer.writeln('```$language');
      // Truncate very long responses
      if (body.length > 10000) {
        buffer.writeln('${body.substring(0, 10000)}...');
        buffer.writeln(
          '\n[Response truncated - ${body.length} total characters]',
        );
      } else {
        buffer.writeln(body);
      }
      buffer.writeln('```\n');
    } else {
      buffer.writeln('*No response body*\n');
    }

    return buffer.toString().trim();
  }

  /// Detect programming language for syntax highlighting
  static String _detectLanguage(String content) {
    // Simple heuristics for common output types
    if (content.contains('<?xml') || content.contains('</')) {
      return 'xml';
    }
    if (content.startsWith('{') || content.startsWith('[')) {
      return 'json';
    }
    if (content.contains('import ') || content.contains('function ')) {
      return 'javascript';
    }
    if (content.contains('def ') || content.contains('import ')) {
      return 'python';
    }
    return ''; // No highlighting
  }

  /// Format results for unknown/unsupported tools
  static String _formatUnknownTool(String toolName, String result) {
    final buffer = StringBuffer();

    buffer.writeln('## 🔧 Tool: $toolName\n');
    buffer.writeln('**Result:**');
    buffer.writeln('```');
    buffer.writeln(result);
    buffer.writeln('```');

    return buffer.toString().trim();
  }
}
