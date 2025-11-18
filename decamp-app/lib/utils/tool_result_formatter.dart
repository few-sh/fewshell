import 'dart:convert';

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
  /// Format a tool result based on the tool name
  static String format({required String toolName, required String result}) {
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
      'execute_shell_command' => _formatShellCommand(data),
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
  static String _formatShellCommand(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    final command = data['command'] as String? ?? 'unknown';
    final exitCode = data['exitCode'] as int? ?? -1;
    final stdout = (data['stdout']?.toString() ?? '').trim();
    final stderr = (data['stderr']?.toString() ?? '').trim();
    final success = data['success'] as bool? ?? (exitCode == 0);

    // Header with status
    if (success) {
      buffer.writeln('## ✅ Command Executed Successfully\n');
    } else {
      buffer.writeln('## ❌ Command Failed\n');
    }

    // Command section
    buffer.writeln('**Command:**');
    buffer.writeln('```bash');
    buffer.writeln(command);
    buffer.writeln('```\n');

    // Exit code (show if not 0 or if command failed)
    if (!success || exitCode != 0) {
      buffer.writeln('**Exit Code:** `$exitCode`\n');
    }

    // Stdout section (if available)
    if (stdout.isNotEmpty) {
      buffer.writeln('**Output:**');

      // Try to detect if output looks like it should have syntax highlighting
      final language = _detectLanguage(stdout);
      buffer.writeln('```$language');
      buffer.writeln(stdout);
      buffer.writeln('```\n');
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
      buffer.writeln('```\n');
    }

    // If no output at all
    if (stdout.isEmpty && stderr.isEmpty) {
      buffer.writeln('*No output*\n');
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
