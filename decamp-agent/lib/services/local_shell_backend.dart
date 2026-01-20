import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:agent_core/agent_core.dart';

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
    // Use `script` to allocate a PTY for unbuffered streaming.
    _log.info('Executing local command: $command');

    Process process;
    if (Platform.isMacOS) {
      // macOS: stdin piping doesn't work reliably with script, use temp file
      final tempDir = Directory.systemTemp.createTempSync('decamp_cmd_');
      final scriptFile = File('${tempDir.path}/cmd.sh');
      await scriptFile.writeAsString(command);

      process = await Process.start(
        'script',
        ['-F', '-q', '/dev/null', 'bash', scriptFile.path],
        environment: {
          // TERM=dumb disables terminal features (bracketed paste, colors, title)
          // that produce escape sequences in the output
          'TERM': 'dumb',
          'BASH_SILENCE_DEPRECATION_WARNING': '1',
        },
      );

      // Cleanup temp file when process ends
      unawaited(process.exitCode.whenComplete(() {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }));

      await process.stdin.close();
    } else if (Platform.isLinux) {
      // Linux: stdin piping works, cleaner approach
      // Must explicitly exit bash since script's PTY may not propagate EOF.
      // TERM=dumb disables terminal features (bracketed paste, colors, title)
      // that produce escape sequences in the output
      process = await Process.start(
        'script',
        ['-q', '-c', 'bash -s', '/dev/null'],
        environment: {'TERM': 'dumb'},
      );
      process.stdin.writeln(command);
      process.stdin
          .writeln('exit \$?'); // Preserve exit code and ensure bash exits
      await process.stdin.close();
    } else {
      // Fallback for Windows
      process = await Process.start('bash', ['-s']);
      process.stdin.writeln(command);
      await process.stdin.close();
    }

    _log.info('Started local process with PID: ${process.pid}');
    return LocalShellSession(process);
  }

  @override
  Future<ShellSession> createSession() async {
    final process = await Process.start('bash', []);
    return LocalShellSession(process);
  }
}

/// Local shell session implementation wrapping a Process
class LocalShellSession implements ShellSession {
  final Process _process;
  LocalShellSession(this._process);
  static final _log = Logger('LocalShellSession');

  @override
  Stream<Uint8List> get stdout =>
      _process.stdout.map((d) => Uint8List.fromList(d));

  @override
  Stream<Uint8List> get stderr =>
      _process.stderr.map((d) => Uint8List.fromList(d));

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> get done => _process.exitCode.then((_) {});

  @override
  void write(Uint8List data) => _process.stdin.add(data);

  @override
  Future<void> kill(ProcessSignal signal) async {
    _log.info('Killing local process ${_process.pid} with signal $signal');

    // Only wait and escalate if the intention was to terminate the process
    if (signal != ProcessSignal.sigint &&
        signal != ProcessSignal.sigterm &&
        signal != ProcessSignal.sigquit) {
      _process.kill(signal);
      return;
    }

    _process.kill(signal);

    if (await _waitForExit(const Duration(seconds: 5))) return;

    if (signal != ProcessSignal.sigterm) {
      _log.warning(
          'Process did not exit after signal $signal, escalating to SIGTERM');
      _process.kill(ProcessSignal.sigterm);
      if (await _waitForExit(const Duration(seconds: 5))) return;
    }

    _log.warning('Process did not exit, escalating to SIGKILL');
    _killTree();
  }

  void _killTree() {
    if (Platform.isWindows) {
      try {
        // TODO: This needs tested on windows.
        Process.runSync(
            'taskkill', ['/F', '/T', '/PID', _process.pid.toString()]);
        return;
      } catch (e) {
        _log.warning('Failed to run taskkill: $e');
      }
    }
    _process.kill(ProcessSignal.sigkill);
  }

  Future<bool> _waitForExit(Duration duration) async {
    _log.info(
        'Waiting up to ${duration.inSeconds} seconds for process ${_process.pid} to exit');
    try {
      await _process.exitCode.timeout(duration);
      _log.info('Process ${_process.pid} exited successfully');
      return true;
    } on TimeoutException {
      _log.warning(
          'Process ${_process.pid} did not exit within ${duration.inSeconds} seconds');
      return false;
    }
  }

  @override
  void close() => _process.stdin.close();
}
