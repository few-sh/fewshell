import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the shell service
final shellServiceProvider = Provider<ShellService>((ref) {
  return ShellService();
});

/// Service for executing shell commands
/// Currently a stub that logs commands for testing
class ShellService {
  /// Execute a shell command
  ///
  /// [command] - The shell command to execute
  /// Returns a map with 'stdout', 'stderr', and 'exitCode'
  ///
  /// TODO: Implement actual shell execution using process or ssh
  Future<Map<String, dynamic>> executeCommand(String command) async {
    // Log the command for debugging
    developer.log('Shell command received: $command', name: 'ShellService');

    // Simulate command execution delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Return mock result
    return {
      'stdout': '[STUB] Command would execute: $command',
      'stderr': '',
      'exitCode': 0,
      'executed': false, // Flag to indicate this is a stub
    };
  }

  /// Validate a shell command before execution
  /// Returns null if valid, error message if invalid
  String? validateCommand(String command) {
    if (command.trim().isEmpty) {
      return 'Command cannot be empty';
    }

    // Add more validation as needed
    // e.g., check for dangerous commands, syntax validation, etc.

    return null; // Valid
  }

  /// Check if a command requires elevated privileges
  bool requiresSudo(String command) {
    final trimmed = command.trim();
    return trimmed.startsWith('sudo ') ||
        trimmed.contains('rm -rf') ||
        trimmed.contains('mkfs');
  }
}
