import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartssh2/dartssh2.dart';
import '../models/ssh_settings.dart';
import '../providers/secret_provider.dart';

/// Provider for the shell service
/// Now requires a project ID to access SSH settings
final shellServiceProvider = Provider.family<ShellService, String?>((
  ref,
  projectId,
) {
  if (projectId == null) {
    return ShellService(null, null);
  }

  final secretsActions = ref.watch(projectSecretsProvider(projectId));
  return ShellService(null, secretsActions);
});

/// Service for executing shell commands via SSH
class ShellService {
  SSHClient? _client;
  final ProjectSecretsActions? _secretsActions;

  ShellService(SshSettings? sshSettings, this._secretsActions);

  /// Connect to SSH server using the provided settings
  /// Returns true if connection successful, false otherwise
  Future<bool> connect(SshSettings sshSettings) async {
    try {
      developer.log(
        'Connecting to SSH: ${sshSettings.username}@${sshSettings.host}:${sshSettings.port}',
        name: 'ShellService',
      );

      // Get credentials from secrets
      String? password;
      String? privateKey;
      String? passphrase;

      if (_secretsActions != null) {
        if (sshSettings.passwordSecretId != null) {
          password = await _secretsActions.getSecret(
            sshSettings.passwordSecretId!,
          );
        }
        if (sshSettings.privateKeySecretId != null) {
          privateKey = await _secretsActions.getSecret(
            sshSettings.privateKeySecretId!,
          );
        }
        if (sshSettings.passphraseSecretId != null) {
          passphrase = await _secretsActions.getSecret(
            sshSettings.passphraseSecretId!,
          );
        }
      }

      // Create SSH socket
      final socket = await SSHSocket.connect(
        sshSettings.host,
        sshSettings.port,
        timeout: const Duration(seconds: 30),
      );

      // Create SSH client with authentication
      if (sshSettings.authMethod == SshAuthMethod.password) {
        if (password == null || password.isEmpty) {
          throw Exception('Password not found in secrets');
        }

        _client = SSHClient(
          socket,
          username: sshSettings.username,
          onPasswordRequest: () => password,
        );
      } else {
        // Private key authentication
        if (privateKey == null || privateKey.isEmpty) {
          throw Exception('Private key not found in secrets');
        }

        _client = SSHClient(
          socket,
          username: sshSettings.username,
          identities: [...SSHKeyPair.fromPem(privateKey, passphrase)],
        );
      }

      developer.log('SSH connection established', name: 'ShellService');
      return true;
    } catch (e) {
      developer.log('SSH connection failed: $e', name: 'ShellService');
      _client?.close();
      _client = null;
      return false;
    }
  }

  /// Execute a shell command on the remote server
  ///
  /// [command] - The shell command to execute
  /// Returns a map with 'stdout', 'stderr', and 'exitCode'
  Future<Map<String, dynamic>> executeCommand(String command) async {
    developer.log('Executing command: $command', name: 'ShellService');

    if (_client == null) {
      developer.log('No active SSH connection', name: 'ShellService');
      return {
        'stdout': '',
        'stderr': 'Error: Not connected to SSH server',
        'exitCode': -1,
        'executed': false,
      };
    }

    try {
      // Execute command and capture output
      final result = await _client!.run(command);

      final stdout = String.fromCharCodes(result);

      developer.log(
        'Command executed successfully. Output length: ${stdout.length}',
        name: 'ShellService',
      );

      return {'stdout': stdout, 'stderr': '', 'exitCode': 0, 'executed': true};
    } catch (e) {
      developer.log('Command execution failed: $e', name: 'ShellService');
      return {
        'stdout': '',
        'stderr': 'Error executing command: $e',
        'exitCode': -1,
        'executed': false,
      };
    }
  }

  /// Execute a shell command with full control over stdin/stdout/stderr
  /// Returns a session that can be used for interactive commands
  Future<SSHSession?> createSession() async {
    if (_client == null) {
      developer.log('No active SSH connection', name: 'ShellService');
      return null;
    }

    try {
      final session = await _client!.shell();
      developer.log('Interactive session created', name: 'ShellService');
      return session;
    } catch (e) {
      developer.log('Failed to create session: $e', name: 'ShellService');
      return null;
    }
  }

  /// Disconnect from SSH server
  void disconnect() {
    if (_client != null) {
      developer.log('Disconnecting from SSH', name: 'ShellService');
      _client!.close();
      _client = null;
    }
  }

  /// Check if currently connected to SSH server
  bool get isConnected => _client != null;

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
