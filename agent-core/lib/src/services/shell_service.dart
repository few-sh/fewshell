// ignore_for_file: unnecessary_string_escapes

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_userauth.dart';
import '../models/ssh_settings.dart';
import 'keychain_service.dart';

/// Callback for interactive user prompts (e.g. 2FA, password)
typedef UserPromptCallback = Future<String> Function(String prompt, bool echo);

/// Abstract interface for shell execution backend
abstract class ShellBackend {
  Future<void> connect({
    String? inlinePassword,
    String? inlinePrivateKey,
    String? inlinePassphrase,
  });
  void disconnect();
  bool get isConnected;
  Future<ShellSession> execute(String command);
  Future<ShellSession> createSession();

  /// Set callback for interactive prompts
  set onUserPrompt(UserPromptCallback? callback);
}

/// Abstract interface for a shell session
abstract class ShellSession {
  Stream<Uint8List> get stdout;
  Stream<Uint8List> get stderr;
  Future<int> get exitCode;
  Future<void> get done;
  void write(Uint8List data);
  Future<void> kill(ProcessSignal signal);
  void close();
}

/// Service for executing shell commands via SSH or Local
class ShellService {
  static final _log = Logger('ShellService');

  ShellBackend _backend;
  final SshSettings? _sshSettings;
  final KeychainService? _keychain;
  final String? _projectId;

  /// Callback for handling interactive prompts
  UserPromptCallback? _onUserPrompt;

  UserPromptCallback? get onUserPrompt => _onUserPrompt;
  set onUserPrompt(UserPromptCallback? callback) {
    _onUserPrompt = callback;
    _backend.onUserPrompt = callback;
  }

  ShellService(
    this._sshSettings,
    this._keychain,
    this._projectId, {
    ShellBackend? backend,
  }) : _backend = backend ??
            (_sshSettings != null
                ? SshShellBackend(_sshSettings, _keychain, _projectId)
                : UnconfiguredShellBackend());

  /// Connect to shell backend
  Future<void> connect(
    SshSettings sshSettings, {
    String? inlinePassword,
    String? inlinePrivateKey,
    String? inlinePassphrase,
  }) async {
    // If we are connecting with specific settings, we must use an SshShellBackend configured with them.
    // This overrides the current backend for this connection.
    _backend = SshShellBackend(sshSettings, _keychain, _projectId);
    _backend.onUserPrompt = _onUserPrompt;

    await _backend.connect(
      inlinePassword: inlinePassword,
      inlinePrivateKey: inlinePrivateKey,
      inlinePassphrase: inlinePassphrase,
    );
  }

  /// Execute a shell command
  Future<Map<String, dynamic>> executeCommand(
    String command, {
    List<String>? secrets,
    Stream<ProcessSignal>? abortSignal,
    bool isRetry = false,
    void Function(String)? onStdout,
    void Function(String)? onStderr,
  }) async {
    _log.info('Executing command (secrets:$secrets): $command');

    // Auto-connect if not connected
    if (!isConnected) {
      if (_sshSettings == null && _backend is SshShellBackend) {
        _log.warning('No SSH settings configured for this project');
        throw Exception('SSH settings not configured for this project');
      }

      _log.info('Auto-connecting...');
      await _backend.connect();
    }

    try {
      String commandToExecute;
      String? scriptToPipe;
      final secretsToRedact = <String>[];

      final resolvedSecrets = await _resolveSecrets(secrets);

      // If secrets are provided, wrap command with secret injection
      if (resolvedSecrets.isNotEmpty) {
        final envExports = StringBuffer();

        for (var entry in resolvedSecrets.entries) {
          if (entry.value.isNotEmpty) {
            if (!_isValidEnvVarName(entry.key)) {
              _log.warning('Invalid environment variable name: ${entry.key}');
              continue;
            }

            final encodedValue = base64.encode(utf8.encode(entry.value));
            envExports.writeln(
              "export ${entry.key}=\"\$(echo '$encodedValue' | base64 -d)\"",
            );
            secretsToRedact.add(entry.value);
          }
        }

        scriptToPipe = '''
$envExports
$command
''';
        commandToExecute = scriptToPipe;
      } else {
        commandToExecute = command;
      }

      _log.info('Executing command: $commandToExecute');

      final session = await _backend.execute(commandToExecute);

      StreamSubscription<ProcessSignal>? abortSubscription;
      if (abortSignal != null) {
        abortSubscription = abortSignal.listen((signal) {
          _log.info('Aborting command with signal: $signal');
          session.kill(signal);
        });
      }

      final stdoutBuffer = BytesBuilder(copy: false);
      final stderrBuffer = BytesBuilder(copy: false);
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      // Ensure stream completers complete when session ends (handles abrupt termination)
      session.done.then((_) {
        if (!stdoutDone.isCompleted) stdoutDone.complete();
        if (!stderrDone.isCompleted) stderrDone.complete();
      });

      // Use chunked decoders to handle split UTF-8 characters properly
      ByteConversionSink? stdoutDecoder;
      if (onStdout != null) {
        stdoutDecoder = utf8.decoder.startChunkedConversion(
          _StreamingStringSink(onStdout),
        );
      }

      ByteConversionSink? stderrDecoder;
      if (onStderr != null) {
        stderrDecoder = utf8.decoder.startChunkedConversion(
          _StreamingStringSink(onStderr),
        );
      }

      session.stdout.listen(
        (data) {
          stdoutBuffer.add(data);
          stdoutDecoder?.add(data);
        },
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onError: (e, s) {
          if (!stdoutDone.isCompleted) stdoutDone.completeError(e, s);
        },
      );

      session.stderr.listen(
        (data) {
          stderrBuffer.add(data);
          stderrDecoder?.add(data);
        },
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onError: (e, s) {
          if (!stderrDone.isCompleted) stderrDone.completeError(e, s);
        },
      );

      _log.fine('Waiting for command output to complete...');
      await stdoutDone.future;
      _log.fine('Waiting for stderr to complete...');
      await stderrDone.future;
      _log.fine('Waiting for session to complete...');
      await session.done;
      _log.fine('Waiting for abort subscription to complete...');
      await abortSubscription?.cancel();

      stdoutDecoder?.close();
      stderrDecoder?.close();

      final stdout =
          utf8.decode(stdoutBuffer.takeBytes(), allowMalformed: true);
      final stderr =
          utf8.decode(stderrBuffer.takeBytes(), allowMalformed: true);
      final exitCode = await session.exitCode;

      _log.info(
        'Command executed. Exit code: $exitCode, stdout: $stdout, stderr: $stderr',
      );

      return {
        'stdout': _redactSecrets(stdout, secretsToRedact),
        'stderr': _redactSecrets(stderr, secretsToRedact),
        'exitCode': exitCode,
        'executed': true,
      };
    } catch (e) {
      if (!isRetry && _backend is SshShellBackend && _sshSettings != null) {
        if (_isConnectionError(e)) {
          _log.warning(
              'Command failed due to connection error: $e. Attempting reconnect...');
          _backend.disconnect();
          await _backend.connect();
          return executeCommand(
            command,
            secrets: secrets,
            abortSignal: abortSignal,
            isRetry: true,
            onStdout: onStdout,
            onStderr: onStderr,
          );
        }
      }
      _log.warning('Command execution failed: $e');
      rethrow;
    }
  }

  Future<ShellSession> createSession() async {
    if (!isConnected) {
      await _backend.connect();
    }
    return _backend.createSession();
  }

  void disconnect() {
    _backend.disconnect();
  }

  bool get isConnected => _backend.isConnected;

  bool _isConnectionError(Object e) {
    if (e is SSHStateError) return true;
    if (e is SSHSocketError) return true;
    if (e is SSHChannelOpenError) return true;
    return false;
  }

  String? validateCommand(String command) {
    if (command.trim().isEmpty) {
      return 'Command cannot be empty';
    }
    return null;
  }

  bool requiresSudo(String command) {
    final trimmed = command.trim();
    return trimmed.startsWith('sudo ') ||
        trimmed.contains('rm -rf') ||
        trimmed.contains('mkfs');
  }

  Future<Map<String, dynamic>> executeWithSudo({
    required String command,
    String? sudoPasswordSecretId,
    List<String>? secrets,
    Stream<ProcessSignal>? abortSignal,
    bool isRetry = false,
    void Function(String)? onStdout,
    void Function(String)? onStderr,
  }) async {
    if (!isConnected) {
      await _backend.connect();
    }

    String? sudoPassword;
    if (sudoPasswordSecretId != null &&
        _keychain != null &&
        _projectId != null) {
      sudoPassword = await _keychain.getProjectSecret(
        _projectId,
        sudoPasswordSecretId,
      );
      if (sudoPassword == null || sudoPassword.isEmpty) {
        throw Exception('Sudo password not found in secrets');
      }
    }

    final envExports = StringBuffer();
    final secretsToRedact = <String>[];
    if (sudoPassword != null) {
      secretsToRedact.add(sudoPassword);
    }

    final resolvedSecrets = await _resolveSecrets(secrets);

    if (resolvedSecrets.isNotEmpty) {
      for (var entry in resolvedSecrets.entries) {
        if (entry.value.isNotEmpty) {
          if (!_isValidEnvVarName(entry.key)) {
            continue;
          }
          final encodedValue = base64.encode(utf8.encode(entry.value));
          envExports.writeln(
            "export ${entry.key}=\"\$(echo '$encodedValue' | base64 -d)\"",
          );
          secretsToRedact.add(entry.value);
        }
      }
    }

    String secureScript;

    if (sudoPassword != null) {
      final askpassPath = '/tmp/decamp_askpass_\$\$';
      final encodedSudoPassword = base64.encode(utf8.encode(sudoPassword));

      secureScript = '''
(umask 077 && cat > $askpassPath <<'ASKPASS_EOF'
#!/bin/sh
echo "\$SUDO_PASSWORD"
ASKPASS_EOF
)
chmod 700 $askpassPath

$envExports
export SUDO_PASSWORD="\$(echo '$encodedSudoPassword' | base64 -d)"
SUDO_ASKPASS=$askpassPath sudo -A bash -c '${_escapeForCommand(command)}'

rm -f $askpassPath
''';
    } else {
      secureScript = '''
$envExports
sudo bash -c '${_escapeForCommand(command)}'
''';
    }

    _log.info('Executing sudo command: sudo $command (secrets redacted)');

    try {
      final session = await _backend.execute(secureScript);
      session.close();

      StreamSubscription<ProcessSignal>? abortSubscription;
      if (abortSignal != null) {
        abortSubscription = abortSignal.listen((signal) {
          _log.info('Aborting sudo command with signal: $signal');
          session.kill(signal);
        });
      }

      final stdoutBuffer = BytesBuilder(copy: false);
      final stderrBuffer = BytesBuilder(copy: false);
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      // Ensure stream completers complete when session ends (handles abrupt termination)
      session.done.then((_) {
        if (!stdoutDone.isCompleted) stdoutDone.complete();
        if (!stderrDone.isCompleted) stderrDone.complete();
      });

      // Use chunked decoders to handle split UTF-8 characters properly
      ByteConversionSink? stdoutDecoder;
      if (onStdout != null) {
        stdoutDecoder = utf8.decoder.startChunkedConversion(
          _StreamingStringSink(onStdout),
        );
      }

      ByteConversionSink? stderrDecoder;
      if (onStderr != null) {
        stderrDecoder = utf8.decoder.startChunkedConversion(
          _StreamingStringSink(onStderr),
        );
      }

      session.stdout.listen(
        (data) {
          stdoutBuffer.add(data);
          stdoutDecoder?.add(data);
        },
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onError: (e, s) {
          if (!stdoutDone.isCompleted) stdoutDone.completeError(e, s);
        },
      );

      session.stderr.listen(
        (data) {
          stderrBuffer.add(data);
          stderrDecoder?.add(data);
        },
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onError: (e, s) {
          if (!stderrDone.isCompleted) stderrDone.completeError(e, s);
        },
      );

      await stdoutDone.future;
      await stderrDone.future;
      await session.done;
      await abortSubscription?.cancel();

      stdoutDecoder?.close();
      stderrDecoder?.close();

      final stdout =
          utf8.decode(stdoutBuffer.takeBytes(), allowMalformed: true);
      final stderr =
          utf8.decode(stderrBuffer.takeBytes(), allowMalformed: true);
      final exitCode = await session.exitCode;

      return {
        'stdout': _redactSecrets(stdout, secretsToRedact),
        'stderr': _redactSecrets(stderr, secretsToRedact),
        'exitCode': exitCode,
        'executed': true,
      };
    } catch (e) {
      if (!isRetry && _backend is SshShellBackend && _sshSettings != null) {
        if (_isConnectionError(e)) {
          _log.warning(
              'Sudo command failed due to connection error: $e. Attempting reconnect...');
          _backend.disconnect();
          await _backend.connect();
          return executeWithSudo(
            command: command,
            sudoPasswordSecretId: sudoPasswordSecretId,
            secrets: secrets,
            abortSignal: abortSignal,
            isRetry: true,
            onStdout: onStdout,
            onStderr: onStderr,
          );
        }
      }
      _log.warning('Sudo command execution failed: $e');
      rethrow;
    }
  }

  String _escapeForCommand(String input) {
    return input.replaceAll("'", "'\\''");
  }

  bool _isValidEnvVarName(String name) {
    return RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name);
  }

  String _redactSecrets(String text, List<String> secrets) {
    var redacted = text;
    for (var secret in secrets) {
      if (secret.isNotEmpty) {
        redacted = redacted.replaceAll(secret, '***REDACTED***');
      }
    }
    return redacted;
  }

  Future<Map<String, String>> _resolveSecrets(List<String>? secretKeys) async {
    final resolved = <String, String>{};
    if (secretKeys == null ||
        secretKeys.isEmpty ||
        _keychain == null ||
        _projectId == null) {
      return resolved;
    }

    for (final key in secretKeys) {
      if (!_isValidEnvVarName(key)) {
        _log.warning(
            'Skipping secret with invalid environment variable name: $key');
        continue;
      }

      final value = await _keychain.getProjectSecret(_projectId, key);
      if (value != null) {
        resolved[key] = value;
      } else {
        _log.warning(
            'Secret not found: $key for project: $_projectId. Keychain has secrets: ${(await _keychain.listProjectSecrets(_projectId)).keys.toList()}');
      }
    }
    return resolved;
  }
}

class SshShellBackend implements ShellBackend {
  static final _log = Logger('SshShellBackend');

  SSHClient? _client;
  final SshSettings _settings;
  final KeychainService? _keychain;
  final String? _projectId;
  bool _isConnectionCancelled = false;

  @override
  UserPromptCallback? onUserPrompt;

  SshShellBackend(this._settings, this._keychain, this._projectId);

  @override
  bool get isConnected => _client != null && !_client!.isClosed;

  @override
  Future<void> connect({
    String? inlinePassword,
    String? inlinePrivateKey,
    String? inlinePassphrase,
  }) async {
    _isConnectionCancelled = false;
    try {
      _log.info(
        'Connecting to SSH: ${_settings.username}@${_settings.host}:${_settings.port}',
      );

      final password =
          await _getCredential(inlinePassword, _settings.passwordSecretId);
      final privateKey =
          await _getCredential(inlinePrivateKey, _settings.privateKeySecretId);
      final passphrase =
          await _getCredential(inlinePassphrase, _settings.passphraseSecretId);

      if (_isConnectionCancelled) return;

      final socket = await SSHSocket.connect(
        _settings.host,
        _settings.port,
        timeout: const Duration(seconds: 30),
      );

      if (_isConnectionCancelled) {
        socket.destroy();
        return;
      }

      if (_settings.authMethod == SshAuthMethod.password) {
        if (password == null || password.isEmpty) {
          throw Exception('Password not found in secrets');
        }

        _client = SSHClient(
          socket,
          username: _settings.username,
          onPasswordRequest: () => password,
          onUserInfoRequest: (request) =>
              _handleUserInfoRequest(request, passwordFallback: password),
        );
      } else {
        if (privateKey == null || privateKey.isEmpty) {
          throw Exception('Private key not found in secrets');
        }

        _client = SSHClient(
          socket,
          username: _settings.username,
          identities: [...SSHKeyPair.fromPem(privateKey, passphrase)],
          onUserInfoRequest: (request) => _handleUserInfoRequest(request),
        );
      }

      await _client!.authenticated;
      _log.info('SSH connection established');
    } catch (e) {
      _log.warning('SSH connection failed: $e');
      _client?.close();
      _client = null;
      rethrow;
    }
  }

  @override
  void disconnect() {
    _isConnectionCancelled = true;
    if (_client != null) {
      _log.info('Disconnecting from SSH');
      _client!.close();
      _client = null;
    }
  }

  @override
  Future<ShellSession> execute(String command) async {
    if (!isConnected) throw Exception('Not connected');
    final session = await _client!.execute(command);
    return SshShellSession(session);
  }

  @override
  Future<ShellSession> createSession() async {
    if (!isConnected) throw Exception('Not connected');
    final session = await _client!.shell();
    return SshShellSession(session);
  }

  Future<List<String>> _handleUserInfoRequest(
    SSHUserInfoRequest request, {
    String? passwordFallback,
  }) async {
    final prompts = request.prompts;
    if (onUserPrompt == null) {
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

  Future<String?> _getCredential(String? inlineValue, String? secretId) async {
    if (inlineValue != null) return inlineValue;
    if (_keychain == null || _projectId == null || secretId == null) {
      return null;
    }
    return await _keychain.getProjectSecret(_projectId, secretId);
  }
}

class SshShellSession implements ShellSession {
  final SSHSession _session;
  SshShellSession(this._session);

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  Future<int> get exitCode => _session.done.then((_) => _session.exitCode ?? 0);

  @override
  Future<void> get done => _session.done;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  Future<void> kill(ProcessSignal signal) async {
    final sshSignal = switch (signal) {
      ProcessSignal.sigint => SSHSignal.INT,
      ProcessSignal.sigterm => SSHSignal.TERM,
      ProcessSignal.sigkill => SSHSignal.KILL,
      ProcessSignal.sigquit => SSHSignal.QUIT,
      ProcessSignal.sighup => SSHSignal.HUP,
      ProcessSignal.sigusr1 => SSHSignal.USR1,
      ProcessSignal.sigusr2 => SSHSignal.USR2,
      _ => null,
    };

    if (sshSignal != null) {
      _session.kill(sshSignal);
    }
  }

  @override
  void close() => _session.close();
}

class UnconfiguredShellBackend implements ShellBackend {
  @override
  UserPromptCallback? onUserPrompt;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect({
    String? inlinePassword,
    String? inlinePrivateKey,
    String? inlinePassphrase,
  }) async {
    throw Exception('SSH settings not configured for this project');
  }

  @override
  void disconnect() {}

  @override
  Future<ShellSession> execute(String command) async {
    throw Exception('SSH settings not configured for this project');
  }

  @override
  Future<ShellSession> createSession() async {
    throw Exception('SSH settings not configured for this project');
  }
}

class _StreamingStringSink implements Sink<String> {
  final void Function(String) _callback;

  _StreamingStringSink(this._callback);

  @override
  void add(String data) {
    if (data.isNotEmpty) {
      _callback(data);
    }
  }

  @override
  void close() {}
}
