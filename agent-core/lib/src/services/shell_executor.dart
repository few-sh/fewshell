import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// SSH connection settings
class SshConnectionSettings {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? privateKeyPassphrase;

  SshConnectionSettings({
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.privateKeyPassphrase,
  });
}

/// Executes shell commands over SSH.
///
/// Uses callback-based dependency injection for secrets to work in both
/// Flutter (keychain) and server (database) environments.
class ShellExecutor {
  /// Callback to get a single secret by ID
  final Future<String?> Function(String secretId) getSecret;

  /// Callback to get all secrets as environment variables
  final Future<Map<String, String>> Function() getAllSecrets;

  SSHClient? _client;
  SshConnectionSettings? _sshSettings;

  ShellExecutor({
    required this.getSecret,
    required this.getAllSecrets,
  });

  /// Whether currently connected to SSH server
  bool get isConnected => _client != null;

  /// Current connection settings
  SshConnectionSettings? get currentSettings => _sshSettings;

  /// Connect to an SSH server
  Future<bool> connect(SshConnectionSettings settings) async {
    try {
      developer.log(
        'Connecting to SSH server: ${settings.username}@${settings.host}:${settings.port}',
        name: 'ShellExecutor',
      );

      // Build socket
      final socket = await SSHSocket.connect(settings.host, settings.port);

      // Build authentication methods
      List<SSHKeyPair>? identities;
      if (settings.privateKey != null && settings.privateKey!.isNotEmpty) {
        try {
          identities = [
            ...SSHKeyPair.fromPem(
              settings.privateKey!,
              settings.privateKeyPassphrase,
            ),
          ];
        } catch (e) {
          developer.log('Failed to parse private key: $e',
              name: 'ShellExecutor');
          return false;
        }
      }

      // Create client with appropriate authentication
      if (identities != null && identities.isNotEmpty) {
        _client = SSHClient(
          socket,
          username: settings.username,
          identities: identities,
        );
      } else if (settings.password != null) {
        _client = SSHClient(
          socket,
          username: settings.username,
          onPasswordRequest: () => settings.password!,
        );
      } else {
        developer.log(
          'No authentication method provided',
          name: 'ShellExecutor',
        );
        return false;
      }

      // Wait for authentication
      await _client!.authenticated;
      _sshSettings = settings;

      developer.log(
        'SSH connection established',
        name: 'ShellExecutor',
      );
      return true;
    } catch (e) {
      developer.log('SSH connection failed: $e', name: 'ShellExecutor');
      _client = null;
      _sshSettings = null;
      return false;
    }
  }

  /// Disconnect from SSH server
  Future<void> disconnect() async {
    if (_client != null) {
      _client!.close();
      _client = null;
      developer.log('SSH connection closed', name: 'ShellExecutor');
    }
  }

  /// Execute a shell command
  ///
  /// [command] - The command to execute
  /// [secrets] - Map of environment variable names to secret IDs
  /// [isRetry] - Internal flag for reconnection retry
  Future<Map<String, dynamic>> executeCommand({
    required String command,
    Map<String, String>? secrets,
    bool isRetry = false,
  }) async {
    // Validate command
    if (command.trim().isEmpty) {
      return {
        'stdout': '',
        'stderr': 'Error: Command cannot be empty',
        'exitCode': -1,
        'executed': false,
      };
    }

    // Auto-connect if we have settings but not connected
    if (_client == null && _sshSettings != null && !isRetry) {
      developer.log('Auto-connecting to SSH server...', name: 'ShellExecutor');
      final connected = await connect(_sshSettings!);
      if (!connected) {
        return {
          'stdout': '',
          'stderr': 'Error: Failed to connect to SSH server',
          'exitCode': -1,
          'executed': false,
        };
      }
    }

    if (_client == null) {
      return {
        'stdout': '',
        'stderr':
            'Error: Not connected to SSH server. Please configure SSH connection in project settings.',
        'exitCode': -1,
        'executed': false,
      };
    }

    // Resolve secrets (environment variable name -> secret value)
    final resolvedSecrets = <String, String>{};
    final secretsToRedact = <String>[];

    if (secrets != null && secrets.isNotEmpty) {
      for (var entry in secrets.entries) {
        final envVarName = entry.key;
        final secretId = entry.value;

        // Validate environment variable name
        if (!_isValidEnvVarName(envVarName)) {
          developer.log(
            'Invalid environment variable name: $envVarName',
            name: 'ShellExecutor',
          );
          continue;
        }

        final secretValue = await getSecret(secretId);
        if (secretValue != null && secretValue.isNotEmpty) {
          resolvedSecrets[envVarName] = secretValue;
          secretsToRedact.add(secretValue);
        }
      }
    }

    // Build secure command with secrets as environment variables
    final secureCommand = _buildSecureCommand(command, resolvedSecrets);

    developer.log(
      'Executing command: $command (secrets redacted)',
      name: 'ShellExecutor',
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

      await stdoutDone.future;
      await stderrDone.future;
      await session.done;

      final stdout = String.fromCharCodes(stdoutBuffer.takeBytes());
      final stderr = String.fromCharCodes(stderrBuffer.takeBytes());
      final exitCode = session.exitCode ?? -1;

      developer.log(
        'Command executed. Exit code: $exitCode, stdout: ${stdout.length} bytes, stderr: ${stderr.length} bytes',
        name: 'ShellExecutor',
      );

      return {
        'stdout': _redactSecrets(stdout, secretsToRedact),
        'stderr': _redactSecrets(stderr, secretsToRedact),
        'exitCode': exitCode,
        'executed': true,
      };
    } catch (e) {
      // Retry on connection error
      if (!isRetry && _isConnectionError(e) && _sshSettings != null) {
        developer.log(
          'Command failed due to connection error: $e. Reconnecting...',
          name: 'ShellExecutor',
        );

        _client = null;
        final reconnected = await connect(_sshSettings!);
        if (reconnected) {
          return executeCommand(
            command: command,
            secrets: secrets,
            isRetry: true,
          );
        }
      }

      developer.log('Command execution failed: $e', name: 'ShellExecutor');
      return {
        'stdout': '',
        'stderr':
            _redactSecrets('Error executing command: $e', secretsToRedact),
        'exitCode': -1,
        'executed': false,
      };
    }
  }

  /// Execute a command with sudo
  ///
  /// [command] - The command to execute with sudo
  /// [sudoPasswordSecretId] - Secret ID for the sudo password
  /// [secrets] - Map of environment variable names to secret IDs
  Future<Map<String, dynamic>> executeWithSudo({
    required String command,
    String? sudoPasswordSecretId,
    Map<String, String>? secrets,
    bool isRetry = false,
  }) async {
    // Validate command
    if (command.trim().isEmpty) {
      return {
        'stdout': '',
        'stderr': 'Error: Command cannot be empty',
        'exitCode': -1,
        'executed': false,
      };
    }

    // Auto-connect if needed
    if (_client == null && _sshSettings != null && !isRetry) {
      developer.log('Auto-connecting to SSH server...', name: 'ShellExecutor');
      final connected = await connect(_sshSettings!);
      if (!connected) {
        return {
          'stdout': '',
          'stderr': 'Error: Failed to connect to SSH server',
          'exitCode': -1,
          'executed': false,
        };
      }
    }

    if (_client == null) {
      return {
        'stdout': '',
        'stderr': 'Error: Not connected to SSH server',
        'exitCode': -1,
        'executed': false,
      };
    }

    // Get sudo password from secrets if provided
    String? sudoPassword;
    if (sudoPasswordSecretId != null) {
      sudoPassword = await getSecret(sudoPasswordSecretId);
      if (sudoPassword == null || sudoPassword.isEmpty) {
        developer.log('Sudo password not found in secrets',
            name: 'ShellExecutor');
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
        if (!_isValidEnvVarName(entry.key)) {
          developer.log('Invalid env var name: ${entry.key}',
              name: 'ShellExecutor');
          continue;
        }

        final secretValue = await getSecret(entry.value);
        if (secretValue != null && secretValue.isNotEmpty) {
          final encodedValue = base64.encode(utf8.encode(secretValue));
          envExports.writeln(
            "export ${entry.key}=\$(echo '$encodedValue' | base64 -d)",
          );
          secretsToRedact.add(secretValue);
        }
      }
    }

    // Build secure command with sudo
    String secureCommand;
    if (sudoPassword != null) {
      final askpassPath = '/tmp/decamp_askpass_\$\$';
      final encodedSudoPassword = base64.encode(utf8.encode(sudoPassword));

      secureCommand = '''
bash -c "
(umask 077 && cat > $askpassPath <<'ASKPASS_EOF'
#!/bin/sh
echo \\\"\\\$SUDO_PASSWORD\\\"
ASKPASS_EOF
)
chmod 700 $askpassPath
source <(cat <<'DECAMP_SECRETS'
${envExports}export SUDO_PASSWORD=\$(echo '$encodedSudoPassword' | base64 -d)
DECAMP_SECRETS
) && SUDO_ASKPASS=$askpassPath sudo -A bash -c '${_escapeForCommand(command)}'
rm -f $askpassPath
"
''';
    } else {
      secureCommand = '''
bash -c "source <(cat <<'DECAMP_SECRETS'
${envExports}DECAMP_SECRETS
) && sudo bash -c '${_escapeForCommand(command)}'"
''';
    }

    developer.log(
      'Executing sudo command: sudo $command (secrets redacted)',
      name: 'ShellExecutor',
    );

    try {
      final session = await _client!.execute(secureCommand);

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

      await stdoutDone.future;
      await stderrDone.future;
      await session.done;

      final stdout = String.fromCharCodes(stdoutBuffer.takeBytes());
      final stderr = String.fromCharCodes(stderrBuffer.takeBytes());
      final exitCode = session.exitCode ?? -1;

      developer.log(
        'Sudo command executed. Exit code: $exitCode',
        name: 'ShellExecutor',
      );

      return {
        'stdout': _redactSecrets(stdout, secretsToRedact),
        'stderr': _redactSecrets(stderr, secretsToRedact),
        'exitCode': exitCode,
        'executed': true,
      };
    } catch (e) {
      if (!isRetry && _isConnectionError(e) && _sshSettings != null) {
        developer.log(
          'Sudo command failed due to connection error: $e. Reconnecting...',
          name: 'ShellExecutor',
        );

        _client = null;
        final reconnected = await connect(_sshSettings!);
        if (reconnected) {
          return executeWithSudo(
            command: command,
            sudoPasswordSecretId: sudoPasswordSecretId,
            secrets: secrets,
            isRetry: true,
          );
        }
      }

      developer.log('Sudo command execution failed: $e', name: 'ShellExecutor');
      return {
        'stdout': '',
        'stderr':
            _redactSecrets('Error executing sudo command: $e', secretsToRedact),
        'exitCode': -1,
        'executed': false,
      };
    }
  }

  /// Build a secure command with environment variables
  String _buildSecureCommand(String command, Map<String, String> secrets) {
    if (secrets.isEmpty) {
      return command;
    }

    final envExports = StringBuffer();
    for (var entry in secrets.entries) {
      final encodedValue = base64.encode(utf8.encode(entry.value));
      envExports.writeln(
        "export ${entry.key}=\$(echo '$encodedValue' | base64 -d)",
      );
    }

    return '''
bash -c "source <(cat <<'DECAMP_SECRETS'
${envExports}DECAMP_SECRETS
) && $command"
''';
  }

  /// Escape command string for bash -c execution
  String _escapeForCommand(String input) {
    return input.replaceAll("'", "'\\''");
  }

  /// Validate environment variable name
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

  /// Check if error is a connection error that can be retried
  bool _isConnectionError(Object error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socket') ||
        errorStr.contains('connection') ||
        errorStr.contains('closed') ||
        errorStr.contains('eof') ||
        errorStr.contains('reset');
  }
}
