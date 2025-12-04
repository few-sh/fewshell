// ignore_for_file: unnecessary_string_escapes

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_userauth.dart';
import '../models/ssh_settings.dart';
import 'keychain_service.dart';

/// Callback for interactive user prompts (e.g. 2FA, password)
typedef UserPromptCallback = Future<String> Function(String prompt, bool echo);

/// Service for executing shell commands via SSH
class ShellService {
  SSHClient? _client;
  final SshSettings? _sshSettings;
  final KeychainService? _keychain;
  final String? _projectId;

  /// Callback for handling interactive prompts from the SSH server
  UserPromptCallback? onUserPrompt;

  ShellService(this._sshSettings, this._keychain, this._projectId);

  /// Connect to SSH server using the provided settings
  /// Throws an exception if connection fails
  ///
  /// Optional inline credentials can be provided for testing purposes.
  /// If provided, they override credentials from the keychain.
  Future<void> connect(
    SshSettings sshSettings, {
    String? inlinePassword,
    String? inlinePrivateKey,
    String? inlinePassphrase,
  }) async {
    try {
      developer.log(
        'Connecting to SSH: ${sshSettings.username}@${sshSettings.host}:${sshSettings.port}',
        name: 'ShellService',
      );

      // Get credentials from inline or keychain
      final password =
          await _getCredential(inlinePassword, sshSettings.passwordSecretId);
      final privateKey = await _getCredential(
          inlinePrivateKey, sshSettings.privateKeySecretId);
      final passphrase = await _getCredential(
          inlinePassphrase, sshSettings.passphraseSecretId);

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
          onUserInfoRequest: (request) =>
              _handleUserInfoRequest(request, passwordFallback: password),
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
          onUserInfoRequest: (request) => _handleUserInfoRequest(request),
        );
      }

      // Wait for authentication to complete
      await _client!.authenticated;

      developer.log('SSH connection established', name: 'ShellService');
    } catch (e) {
      developer.log('SSH connection failed: $e', name: 'ShellService');
      _client?.close();
      _client = null;
      rethrow;
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
    void Function(String)? onStdout,
    void Function(String)? onStderr,
  }) async {
    developer.log('Executing command: $command', name: 'ShellService');

    // Auto-connect if not connected or connection is stale
    if (!isConnected) {
      if (_sshSettings == null) {
        developer.log(
          'No SSH settings configured for this project',
          name: 'ShellService',
        );
        throw Exception('SSH settings not configured for this project');
      }

      // Clean up stale client if it exists
      if (_client != null) {
        developer.log('Cleaning up stale connection...', name: 'ShellService');
        _client = null;
      }

      developer.log('Auto-connecting to SSH server...', name: 'ShellService');
      await connect(_sshSettings);
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
        finalCommand = '''
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
        (data) {
          stdoutBuffer.add(data);
          onStdout?.call(String.fromCharCodes(data));
        },
        onDone: stdoutDone.complete,
        onError: stdoutDone.completeError,
      );

      session.stderr.listen(
        (data) {
          stderrBuffer.add(data);
          onStderr?.call(String.fromCharCodes(data));
        },
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
      final exitCode = session.exitCode ?? 0;

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
        await connect(_sshSettings);

        developer.log(
          'Reconnected, retrying command...',
          name: 'ShellService',
        );
        // Retry the command once
        return executeCommand(
          command,
          secrets: secrets,
          isRetry: true,
          onStdout: onStdout,
          onStderr: onStderr,
        );
      }

      developer.log('Command execution failed: $e', name: 'ShellService');
      rethrow;
    }
  }

  /// Execute a shell command with full control over stdin/stdout/stderr
  /// Returns a session that can be used for interactive commands
  Future<SSHSession> createSession() async {
    // Auto-connect if not connected or connection is stale
    if (!isConnected) {
      if (_sshSettings == null) {
        developer.log(
          'No SSH settings configured for this project',
          name: 'ShellService',
        );
        throw Exception('SSH settings not configured for this project');
      }

      // Clean up stale client if it exists
      if (_client != null) {
        developer.log('Cleaning up stale connection...', name: 'ShellService');
        _client = null;
      }

      developer.log('Auto-connecting to SSH server...', name: 'ShellService');
      await connect(_sshSettings);
    }

    try {
      final session = await _client!.shell();
      developer.log('Interactive session created', name: 'ShellService');
      return session;
    } catch (e) {
      developer.log('Failed to create session: $e', name: 'ShellService');
      rethrow;
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
    void Function(String)? onStdout,
    void Function(String)? onStderr,
  }) async {
    // Auto-connect if not connected or connection is stale
    if (!isConnected) {
      if (_sshSettings == null) {
        developer.log(
          'No SSH settings configured for this project',
          name: 'ShellService',
        );
        throw Exception('SSH settings not configured for this project');
      }

      // Clean up stale client if it exists
      if (_client != null) {
        developer.log('Cleaning up stale connection...', name: 'ShellService');
        _client = null;
      }

      developer.log('Auto-connecting to SSH server...', name: 'ShellService');
      await connect(_sshSettings);
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
        throw Exception('Sudo password not found in secrets');
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

      secureCommand = '''
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
      secureCommand = '''
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
        (data) {
          stdoutBuffer.add(data);
          onStdout?.call(String.fromCharCodes(data));
        },
        onDone: stdoutDone.complete,
        onError: stdoutDone.completeError,
      );

      session.stderr.listen(
        (data) {
          stderrBuffer.add(data);
          onStderr?.call(String.fromCharCodes(data));
        },
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
        await connect(_sshSettings);

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
          onStdout: onStdout,
          onStderr: onStderr,
        );
      }

      developer.log('Sudo command execution failed: $e', name: 'ShellService');
      rethrow;
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

  /// Handle SSH keyboard-interactive requests
  Future<List<String>> _handleUserInfoRequest(
    SSHUserInfoRequest request, {
    String? passwordFallback,
  }) async {
    final prompts = request.prompts;
    if (onUserPrompt == null) {
      // If no callback provided, try to use the stored password for the first prompt
      // This is a fallback for servers that use keyboard-interactive for simple password auth
      if (passwordFallback != null && prompts.isNotEmpty) {
        final promptText = prompts.first.promptText;
        if (promptText.toLowerCase().contains('password') ||
            promptText.trim().endsWith(':')) {
          return [passwordFallback];
        }
      }
      return [];
    }

    final answers = <String>[];
    for (var prompt in prompts) {
      final answer = await onUserPrompt!(prompt.promptText, prompt.echo);
      answers.add(answer);
    }
    return answers;
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

  /// Get credential from inline value or keychain
  /// Returns inline value if provided, otherwise fetches from keychain
  Future<String?> _getCredential(String? inlineValue, String? secretId) async {
    if (inlineValue != null) return inlineValue;
    if (_keychain == null || _projectId == null || secretId == null) {
      return null;
    }
    return await _keychain.getProjectSecret(_projectId, secretId);
  }
}
