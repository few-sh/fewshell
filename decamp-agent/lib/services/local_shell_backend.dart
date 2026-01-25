import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:agent_core/agent_core.dart';
import 'package:native_pty/native_pty.dart';

final _log = Logger('LocalShellBackend');

/// Local shell backend implementation for executing commands on the local machine
class LocalShellBackend implements ShellBackend {
  @override
  UserPromptCallback? onUserPrompt;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect({
    String? inlinePassword,
    String? inlinePrivateKey,
    String? inlinePassphrase,
  }) async {
    // No-op
  }

  @override
  void disconnect() {
    // No-op
  }

  @override
  Future<ShellSession> execute(String command) async {
    _log.info('Executing local command via PTY: $command');

    // Use /bin/bash to ensure we have a standard shell environment
    // Force bash instead of user's shell to ensure consistent behavior/syntax
    final shell = Platform.isWindows ? 'bash' : '/bin/bash';

    // Inherit environment variables but override TERM and ensure UTF-8 locale
    final environment = Map<String, String>.from(Platform.environment);
    environment['TERM'] = 'dumb';
    environment['LANG'] = 'en_US.UTF-8';
    environment['LC_ALL'] = 'en_US.UTF-8';

    // TERM=dumb disables terminal features (bracketed paste, colors, title)
    // that produce escape sequences in the output
    final pty = NativePty.spawn(
      shell,
      [shell, '-i'],
      environment: environment,
      autoDecodeUtf8: false,
    );

    // Write command and exit on separate calls
    // This ensures exit is queued but can still be interrupted cleanly
    pty.write('$command\n');
    pty.write('exit\n');

    return LocalShellSession(pty, shouldExit: true);
  }

  @override
  Future<ShellSession> createSession() async {
    final shell = Platform.isWindows ? 'bash' : '/bin/bash';
    final environment = Map<String, String>.from(Platform.environment);
    environment['TERM'] = 'dumb';
    environment['LANG'] = 'en_US.UTF-8';
    environment['LC_ALL'] = 'en_US.UTF-8';
    final pty = NativePty.spawn(
      shell,
      [shell, '-i'],
      environment: environment,
      autoDecodeUtf8: false,
    );
    return LocalShellSession(pty, shouldExit: false);
  }
}

/// Local shell session implementation wrapping a NativePty
class LocalShellSession implements ShellSession {
  final NativePty _pty;
  final bool _shouldExit;
  LocalShellSession(this._pty, {required bool shouldExit})
      : _shouldExit = shouldExit;
  static final _log = Logger('LocalShellSession');

  @override
  Stream<Uint8List> get stdout => _pty.data;

  @override
  Stream<Uint8List> get stderr => const Stream.empty();

  @override
  Future<int> get exitCode => _pty.exitCode;

  @override
  Future<void> get done => _pty.exitCode.then((_) {});

  @override
  void write(Uint8List data) => _pty.writeBytes(data);

  @override
  Future<void> kill(ProcessSignal signal) async {
    _log.info('Killing local PTY process with signal $signal');

    // In a PTY, SIGTERM doesn't interrupt foreground jobs effectively
    // Translate SIGTERM to SIGINT for better interactive shell handling
    final effectiveSignal =
        (signal == ProcessSignal.sigterm) ? ProcessSignal.sigint : signal;

    // Send the signal (NativePty.kill automatically translates to control codes in canonical mode)
    _pty.kill(effectiveSignal.signalNumber);

    if (signal == ProcessSignal.sigint || signal == ProcessSignal.sigterm) {
      // For SIGINT/SIGTERM, wait briefly for the interrupt to take effect
      await Future.delayed(const Duration(milliseconds: 100));

      // The interrupt flushes the input buffer, so the queued 'exit' command is lost
      // Write a new exit command if this is an execute() session
      if (_shouldExit) {
        _pty.write('exit\n');
      }

      // Wait for shell to exit after interrupt + exit
      if (await _waitForExit(const Duration(seconds: 2))) return;
    }

    // For non-terminating signals, don't escalate
    if (signal != ProcessSignal.sigint &&
        signal != ProcessSignal.sigterm &&
        signal != ProcessSignal.sigquit) {
      return;
    }

    // For SIGTERM/SIGQUIT, wait a bit longer before escalating
    if (signal != ProcessSignal.sigint) {
      if (await _waitForExit(const Duration(seconds: 3))) return;
    }

    // Still not exited, escalate to SIGTERM if we haven't already
    if (signal != ProcessSignal.sigterm) {
      _log.warning(
        'Process did not exit after signal $signal, escalating to SIGTERM',
      );
      _pty.kill(ProcessSignal.sigterm.signalNumber);
      await Future.delayed(const Duration(milliseconds: 100));
      if (_shouldExit) {
        _pty.write('exit\n');
      }
      if (await _waitForExit(const Duration(seconds: 3))) return;
    }

    _log.warning('Process did not exit, escalating to SIGKILL');
    _pty.kill(ProcessSignal.sigkill.signalNumber);
  }

  Future<bool> _waitForExit(Duration duration) async {
    _log.info(
      'Waiting up to ${duration.inSeconds} seconds for process to exit',
    );
    try {
      await _pty.exitCode.timeout(duration);
      _log.info('Process exited successfully');
      return true;
    } on TimeoutException {
      _log.warning(
        'Process did not exit within ${duration.inSeconds} seconds',
      );
      return false;
    }
  }

  @override
  void close() => _pty.close();
}
