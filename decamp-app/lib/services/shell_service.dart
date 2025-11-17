import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartssh2/dartssh2.dart';
import '../models/ssh_settings.dart';
import '../providers/secret_provider.dart';
import '../providers/ssh_settings_provider.dart';

/// Provider for the shell service
/// Now requires a project ID to access SSH settings
final shellServiceProvider = Provider.family<ShellService, String?>((
  ref,
  projectId,
) {
  if (projectId == null) {
    return ShellService(null, null);
  }

  final sshSettings = ref.watch(projectSshSettingsProvider(projectId));
  final secretsActions = ref.watch(projectSecretsProvider(projectId));
  return ShellService(sshSettings, secretsActions);
});

/// Service for executing shell commands via SSH
class ShellService {
  SSHClient? _client;
  final SshSettings? _sshSettings;
  final ProjectSecretsActions? _secretsActions;

  ShellService(this._sshSettings, this._secretsActions);

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
  /// [secrets] - Optional map of environment variable names to secret values
  ///             e.g., {'AWS_KEY': 'secret123', 'DB_PASSWORD': 'pass456'}
  /// Returns a map with 'stdout', 'stderr', and 'exitCode'
  ///
  /// Security: Uses process substitution to avoid exposing secrets in process list
  Future<Map<String, dynamic>> executeCommand(
    String command, {
    Map<String, String>? secrets,
  }) async {
    developer.log('Executing command: $command', name: 'ShellService');

    // Auto-connect if not connected
    if (_client == null) {
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
      final result = await _client!.run(finalCommand);

      final stdout = String.fromCharCodes(result);

      developer.log(
        'Command executed successfully. Output length: ${stdout.length}',
        name: 'ShellService',
      );

      return {
        'stdout': _redactSecrets(stdout, secretsToRedact),
        'stderr': '',
        'exitCode': 0,
        'executed': true,
      };
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
    // Auto-connect if not connected
    if (_client == null) {
      if (_sshSettings == null) {
        developer.log(
          'No SSH settings configured for this project',
          name: 'ShellService',
        );
        return null;
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
  }) async {
    // Auto-connect if not connected
    if (_client == null) {
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
    if (sudoPasswordSecretId != null) {
      sudoPassword = await _secretsActions?.getSecret(sudoPasswordSecretId);
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
      final result = await _client!.run(secureCommand);
      final stdout = String.fromCharCodes(result);

      developer.log(
        'Sudo command executed successfully. Output length: ${stdout.length}',
        name: 'ShellService',
      );

      return {
        'stdout': _redactSecrets(stdout, secretsToRedact),
        'stderr': '',
        'exitCode': 0,
        'executed': true,
      };
    } catch (e) {
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
