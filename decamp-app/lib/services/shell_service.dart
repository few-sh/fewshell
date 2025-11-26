import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:agent_core/agent_core.dart';
import '../providers/ssh_settings_provider.dart';
import '../providers/secret_provider.dart';

/// Provider for the shell service
/// Now requires a project ID to access SSH settings
final shellServiceProvider = Provider.family<ShellService, String?>((
  ref,
  projectId,
) {
  if (projectId == null) {
    return ShellService(null, null, null);
  }

  final sshSettings = ref.watch(projectSshSettingsProvider(projectId));
  final keychain = ref.watch(keychainServiceProvider);
  return ShellService(sshSettings, keychain, projectId);
});

/// Service for executing shell commands via SSH
class ShellService {
  SSHClient? _client;
  final SshSettings? _sshSettings;
  final KeychainService? _keychain;
  final String? _projectId;

  ShellService(this._sshSettings, this._keychain, this._projectId);

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

      if (_keychain != null && _projectId != null) {
        if (sshSettings.passwordSecretId != null) {
          password = await _keychain.getProjectSecret(
            _projectId,
            sshSettings.passwordSecretId!,
          );
        }
        if (sshSettings.privateKeySecretId != null) {
          privateKey = await _keychain.getProjectSecret(
            _projectId,
            sshSettings.privateKeySecretId!,
          );
        }
        if (sshSettings.passphraseSecretId != null) {
          passphrase = await _keychain.getProjectSecret(
            _projectId,
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
  /// [secrets] - Optional map of environment variable names to secret values
  ///             e.g., {'AWS_KEY': 'secret123', 'DB_PASSWORD': 'pass456'}
  /// Returns a map with 'stdout', 'stderr', and 'exitCode'
  ///
  /// Security: Uses process substitution to avoid exposing secrets in process list
  Future<Map<String, dynamic>> executeCommand(
    String command, {
    Map<String, String>? secrets,
    // ignore: avoid_private_typedef_parameters
    bool isRetry =
        false, // Internal: prevents infinite recursion on connection retry
  }) async {
    developer.log('Executing command: $command', name: 'ShellService');

    // Auto-connect if not connected or connection is stale
    if (!isConnected) {
      if (_sshSettings == null) {
        developer.log(
          'No SSH settings configured for this project',
          name: 'ShellService',
        );
        return {
          'stdout': '',
          'stderr': 'Error: SSH settings not configured for this project',
          'exitCode': -1,
          'executed': false,
        };
      }

      // Clean up stale client if it exists
      if (_client != null) {
        developer.log('Cleaning up stale connection...', name: 'ShellService');
        _client = null;
      }

      developer.log('Auto-connecting to SSH server...', name: 'ShellService');
      final connected = await connect(_sshSettings);
      if (!connected) {
        return {
          'stdout': '',
          'stderr': 'Error: Failed to connect to SSH server',
          'exitCode': -1,
          'executed': false,
        };
      }
    }

    try {
      String finalCommand;
      final secretsToRedact = <String>[];

      // If secrets are provided, wrap command with secret injection
      if (secrets != null && secrets.isNotEmpty) {
        final envExports = StringBuffer();

        for (var entry in secrets.entries) {
          if (entry.value.isNotEmpty) {
            // Validate environment variable name to prevent injection
            if (!_isValidEnvVarName(entry.key)) {
              developer.log(
                'Invalid environment variable name: ${entry.key}',
                name: 'ShellService',
              );
              continue;
            }

            // Base64 encode the secret to safely handle any characters
            final encodedValue = base64.encode(utf8.encode(entry.value));
            envExports.writeln(
              "export ${entry.key}=\$(echo '$encodedValue' | base64 -d)",
            );
            secretsToRedact.add(entry.value);
          }
        }

        // Build secure command using process substitution
        finalCommand =
            '''
bash -c "source <(cat <<'DECAMP_SECRETS'
${envExports}DECAMP_SECRETS
) && ${_escapeForCommand(command)}"
''';
      } else {
        // No secrets - execute command directly
        finalCommand = command;
      }

      // Execute command and capture output
      final session = await _client!.execute(finalCommand);

      // Collect stdout and stderr
      final stdoutBuffer = BytesBuilder(copy: false);
      final stderrBuffer = BytesBuilder(copy: false);
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      session.stdout.listen(
        stdoutBuffer.add,
        onDone: stdoutDone.complete,
        onError: stdoutDone.completeError,
      );

      session.stderr.listen(
        stderrBuffer.add,
        onDone: stderrDone.complete,
        onError: stderrDone.completeError,
      );

      // Wait for both streams to complete
      await stdoutDone.future;
      await stderrDone.future;

      // Wait for session to complete to get exit code
      await session.done;

      final stdout = String.fromCharCodes(stdoutBuffer.takeBytes());
      final stderr = String.fromCharCodes(stderrBuffer.takeBytes());
      final exitCode = session.exitCode ?? -1;

      developer.log(
        'Command executed. Exit code: $exitCode, stdout length: ${stdout.length}, stderr length: ${stderr.length}',
        name: 'ShellService',
      );

      return {
        'stdout': _redactSecrets(stdout, secretsToRedact),
        'stderr': _redactSecrets(stderr, secretsToRedact),
        'exitCode': exitCode,
        'executed': true,
      };
    } catch (e) {
      // Check if this is a connection-related error that we can retry
      if (!isRetry && _isConnectionError(e) && _sshSettings != null) {
        developer.log(
          'Command failed due to connection error: $e. Attempting reconnect...',
          name: 'ShellService',
        );

        // Clean up and try to reconnect
        _client = null;
        final reconnected = await connect(_sshSettings);
        if (reconnected) {
          developer.log(
            'Reconnected, retrying command...',
            name: 'ShellService',
          );
          // Retry the command once
          return executeCommand(command, secrets: secrets, isRetry: true);
        }
      }

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
    // Auto-connect if not connected or connection is stale
    if (!isConnected) {
      if (_sshSettings == null) {
        developer.log(
          'No SSH settings configured for this project',
          name: 'ShellService',
        );
        return null;
      }

      // Clean up stale client if it exists
      if (_client != null) {
        developer.log('Cleaning up stale connection...', name: 'ShellService');
        _client = null;
      }

      developer.log('Auto-connecting to SSH server...', name: 'ShellService');
      final connected = await connect(_sshSettings);
      if (!connected) {
        return null;
      }
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
  /// Note: This checks if the client exists and hasn't been closed,
  /// but the connection may still be stale. Connection errors are handled
  /// automatically with retry logic in executeCommand and executeWithSudo.
  bool get isConnected => _client != null && !_client!.isClosed;

  /// Check if an exception indicates a connection problem that may be recoverable
  /// by reconnecting
  bool _isConnectionError(Object e) {
    // SSHStateError with 'Transport is closed' indicates stale connection
    if (e is SSHStateError) return true;
    // SSHSocketError indicates network-level issues
    if (e is SSHSocketError) return true;
    // SSHChannelOpenError may indicate connection issues
    if (e is SSHChannelOpenError) return true;
    return false;
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

  /// Execute a command with sudo privileges and optional secret injection
  ///
  /// [command] - The command to execute with sudo (don't include 'sudo' prefix)
  /// [sudoPasswordSecretId] - Optional secret ID for the sudo password
  ///                          If null, assumes passwordless sudo or cached credentials
  /// [secrets] - Optional map of environment variable names to secret values
  ///             e.g., {'AWS_KEY': 'secret123', 'DB_PASSWORD': 'pass456'}
  ///
  /// Returns a map with 'stdout', 'stderr', 'exitCode', and 'executed'
  ///
  /// Security: Uses process substitution to avoid exposing secrets in process list
  Future<Map<String, dynamic>> executeWithSudo({
    required String command,
    String? sudoPasswordSecretId,
    Map<String, String>? secrets,
    // ignore: avoid_private_typedef_parameters
    bool isRetry =
        false, // Internal: prevents infinite recursion on connection retry
  }) async {
    // Auto-connect if not connected or connection is stale
    if (!isConnected) {
      if (_sshSettings == null) {
        developer.log(
          'No SSH settings configured for this project',
          name: 'ShellService',
        );
        return {
          'stdout': '',
          'stderr': 'Error: SSH settings not configured for this project',
          'exitCode': -1,
          'executed': false,
        };
      }

      // Clean up stale client if it exists
      if (_client != null) {
        developer.log('Cleaning up stale connection...', name: 'ShellService');
        _client = null;
      }

      developer.log('Auto-connecting to SSH server...', name: 'ShellService');
      final connected = await connect(_sshSettings);
      if (!connected) {
        return {
          'stdout': '',
          'stderr': 'Error: Failed to connect to SSH server',
          'exitCode': -1,
          'executed': false,
        };
      }
    }

    // Get sudo password from secrets if provided
    String? sudoPassword;
    if (sudoPasswordSecretId != null &&
        _keychain != null &&
        _projectId != null) {
      sudoPassword = await _keychain.getProjectSecret(
        _projectId,
        sudoPasswordSecretId,
      );
      if (sudoPassword == null || sudoPassword.isEmpty) {
        developer.log(
          'Sudo password not found in secrets',
          name: 'ShellService',
        );
        return {
          'stdout': '',
          'stderr': 'Error: Sudo password not found in secrets',
          'exitCode': -1,
          'executed': false,
        };
      }
    }

    // Build environment variable exports for secrets
    final envExports = StringBuffer();
    final secretsToRedact = <String>[];
    if (sudoPassword != null) {
      secretsToRedact.add(sudoPassword);
    }

    if (secrets != null && secrets.isNotEmpty) {
      for (var entry in secrets.entries) {
        if (entry.value.isNotEmpty) {
          // Validate environment variable name to prevent injection
          if (!_isValidEnvVarName(entry.key)) {
            developer.log(
              'Invalid environment variable name: ${entry.key}',
              name: 'ShellService',
            );
            continue;
          }

          // Base64 encode the secret to safely handle any characters
          final encodedValue = base64.encode(utf8.encode(entry.value));
          envExports.writeln(
            "export ${entry.key}=\$(echo '$encodedValue' | base64 -d)",
          );
          secretsToRedact.add(entry.value);
        }
      }
    }

    // Build secure command using process substitution
    // This avoids exposing secrets in the process list
    // Secrets are base64-encoded to prevent injection attacks while preserving content
    String secureCommand;

    if (sudoPassword != null) {
      // Generate unique askpass script path to prevent tampering between sessions
      final askpassPath = '/tmp/decamp_askpass_\$\$';
      final encodedSudoPassword = base64.encode(utf8.encode(sudoPassword));

      secureCommand =
          '''
bash -c "
# Create unique askpass helper for this execution with secure permissions
# Use umask to ensure file is created with 600 permissions, then add execute
(umask 077 && cat > $askpassPath <<'ASKPASS_EOF'
#!/bin/sh
echo \\\"\\\$SUDO_PASSWORD\\\"
ASKPASS_EOF
)
chmod 700 $askpassPath

# Source secrets and execute with sudo
source <(cat <<'DECAMP_SECRETS'
${envExports}export SUDO_PASSWORD=\$(echo '$encodedSudoPassword' | base64 -d)
DECAMP_SECRETS
) && SUDO_ASKPASS=$askpassPath sudo -A bash -c '${_escapeForCommand(command)}'

# Clean up askpass script
rm -f $askpassPath
"
''';
    } else {
      // No sudo password - use regular sudo (assumes passwordless or cached credentials)
      secureCommand =
          '''
bash -c "source <(cat <<'DECAMP_SECRETS'
${envExports}DECAMP_SECRETS
) && sudo bash -c '${_escapeForCommand(command)}'"
''';
    }

    // Log command with redacted secrets
    developer.log(
      'Executing sudo command: sudo $command (secrets redacted)',
      name: 'ShellService',
    );

    try {
      final session = await _client!.execute(secureCommand);

      // Collect stdout and stderr
      final stdoutBuffer = BytesBuilder(copy: false);
      final stderrBuffer = BytesBuilder(copy: false);
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      session.stdout.listen(
        stdoutBuffer.add,
        onDone: stdoutDone.complete,
        onError: stdoutDone.completeError,
      );

      session.stderr.listen(
        stderrBuffer.add,
        onDone: stderrDone.complete,
        onError: stderrDone.completeError,
      );

      // Wait for both streams to complete
      await stdoutDone.future;
      await stderrDone.future;

      // Wait for session to complete to get exit code
      await session.done;

      final stdout = String.fromCharCodes(stdoutBuffer.takeBytes());
      final stderr = String.fromCharCodes(stderrBuffer.takeBytes());
      final exitCode = session.exitCode ?? -1;

      developer.log(
        'Sudo command executed. Exit code: $exitCode, stdout length: ${stdout.length}, stderr length: ${stderr.length}',
        name: 'ShellService',
      );

      return {
        'stdout': _redactSecrets(stdout, secretsToRedact),
        'stderr': _redactSecrets(stderr, secretsToRedact),
        'exitCode': exitCode,
        'executed': true,
      };
    } catch (e) {
      // Check if this is a connection-related error that we can retry
      if (!isRetry && _isConnectionError(e) && _sshSettings != null) {
        developer.log(
          'Sudo command failed due to connection error: $e. Attempting reconnect...',
          name: 'ShellService',
        );

        // Clean up and try to reconnect
        _client = null;
        final reconnected = await connect(_sshSettings);
        if (reconnected) {
          developer.log(
            'Reconnected, retrying sudo command...',
            name: 'ShellService',
          );
          // Retry the command once
          return executeWithSudo(
            command: command,
            sudoPasswordSecretId: sudoPasswordSecretId,
            secrets: secrets,
            isRetry: true,
          );
        }
      }

      developer.log('Sudo command execution failed: $e', name: 'ShellService');
      return {
        'stdout': '',
        'stderr': _redactSecrets(
          'Error executing sudo command: $e',
          secretsToRedact,
        ),
        'exitCode': -1,
        'executed': false,
      };
    }
  }

  /// Escape command string for bash -c execution
  ///
  /// This only escapes the command itself (not secrets, which are base64-encoded)
  /// Handles single quotes by using the '\'' technique
  String _escapeForCommand(String input) {
    // For single-quoted strings in bash, only single quotes need escaping
    // We use the '\'' technique: close quote, escaped quote, open quote
    return input.replaceAll("'", "'\\''");
  }

  /// Validate environment variable name
  /// Only allow alphanumeric characters and underscores, must start with letter or underscore
  bool _isValidEnvVarName(String name) {
    return RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name);
  }

  /// Redact secrets from output text
  String _redactSecrets(String text, List<String> secrets) {
    var redacted = text;
    for (var secret in secrets) {
      if (secret.isNotEmpty) {
        redacted = redacted.replaceAll(secret, '***REDACTED***');
      }
    }
    return redacted;
  }
}
