import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';

final _log = Logger('RemoteInstaller');

///
/// Installing the latest: https://release.few.sh/releases/latest/fewshell-agent-linux-amd64.tar.gz
/// or arm64: https://release.few.sh/releases/latest/fewshell-agent-linux-arm64.tar.gz

/// URL for the installer script.
const _installerScriptUrl = 'https://get.fewshell.com';

/// Relative path (from $HOME) to the server binary.
const _serverBinaryPath = '.fewshell/fewshell-server';

/// Process name used with pgrep.
const _serverProcessName = 'fewshell-server';

/// Relative path (from $HOME) to the domain socket the server creates.
const _serverSocketPath = '.fewshell/agent.sock';

/// Maximum time to wait for the domain socket to appear after starting.
const _socketTimeout = Duration(seconds: 10);

/// Polling interval when waiting for the domain socket.
const _socketPollInterval = Duration(milliseconds: 500);

/// Ensures the fewshell server is installed and running on a remote system
/// via an authenticated SSH connection.
///
/// Idempotent: skips installation if the binary exists, skips starting if
/// the process is already running.
///
/// Subscribe to [output] to receive streaming text from the install process.
class RemoteInstaller {
  final SSHClient client;

  final _outputController = StreamController<String>.broadcast();

  /// Streaming output from the install / start lifecycle.
  Stream<String> get output => _outputController.stream;

  RemoteInstaller(this.client);

  /// Ensures the fewshell server is installed and running.
  ///
  /// Returns normally when the server is confirmed running.
  /// Throws on installation or startup failure.
  Future<void> ensureServerRunning() async {
    // --- install check ---
    final installed = await _isInstalled();
    if (!installed) {
      _emit('Server not found, installing…\n');
      await _install();
    } else {
      _log.fine('Server binary already present.');
      _emit('Server already installed.\n');
    }

    // --- running check ---
    final running = await _isRunning();
    if (!running) {
      _emit('Starting server…\n');
      await _startServer();
    } else {
      _log.fine('Server process already running.');
      _emit('Server already running.\n');
    }

    _emit('Server is ready.\n');
  }

  /// `true` when the server binary exists and is executable.
  Future<bool> _isInstalled() async {
    _log.fine('Checking if fewshell-server is installed…');
    final exitCode = await _execSilent('test -x ~/$_serverBinaryPath');
    return exitCode == 0;
  }

  /// `true` when a fewshell-server process is found via pgrep.
  Future<bool> _isRunning() async {
    _log.fine('Checking if fewshell-server is running…');
    final exitCode = await _execSilent(
      'pgrep -f -u \$(whoami) $_serverProcessName',
    );
    return exitCode == 0;
  }

  /// Runs the installer script, streaming output to [output].
  Future<void> _install() async {
    _log.info('Installing fewshell-server…');

    final session = await client.execute(
      'curl -LsSf $_installerScriptUrl | bash',
    );

    final stdoutSub = session.stdout.listen((data) {
      _emit(utf8.decode(data));
    });
    final stderrSub = session.stderr.listen((data) {
      _emit(utf8.decode(data));
    });

    await session.done;
    await stdoutSub.cancel();
    await stderrSub.cancel();

    final code = session.exitCode;
    if (code != null && code != 0) {
      throw Exception('Installation failed with exit code $code');
    }

    _log.info('Installation completed.');
  }

  /// Starts the server in the background and waits for the domain socket.
  Future<void> _startServer() async {
    _log.info('Starting fewshell-server…');

    // Remove stale socket from a previous run so _waitForSocket polls
    // until the new server creates a fresh one.
    await _execSilent('rm -f ~/$_serverSocketPath');

    // Fire-and-forget: launch the server and don't await session.done,
    // because the SSH channel won't close while the backgrounded process
    // is alive. We verify success by waiting for the domain socket instead.
    final session = await client.execute(
      'cd ~/.fewshell && nohup ./fewshell-server < /dev/null > /dev/null 2>&1 &',
    );
    // Close the session immediately — the server is backgrounded and doesn't
    // need the channel. This frees the SSH channel resource.
    session.close();

    await _waitForSocket();

    _log.info('Server started.');
  }

  /// Polls until `~/.fewshell/agent.sock` exists, or times out.
  Future<void> _waitForSocket() async {
    _log.fine('Waiting for domain socket…');
    final deadline = DateTime.now().add(_socketTimeout);

    while (DateTime.now().isBefore(deadline)) {
      final exists = await _execSilent('test -S ~/$_serverSocketPath');
      if (exists == 0) {
        _log.fine('Domain socket detected.');
        return;
      }
      await Future<void>.delayed(_socketPollInterval);
    }

    throw Exception(
      'Server started but domain socket (~/$_serverSocketPath) '
      'not found after $_socketTimeout',
    );
  }

  /// Executes [command] silently (output discarded) and returns the exit code.
  Future<int> _execSilent(String command) async {
    final session = await client.execute(command);
    await session.stdout.drain<void>();
    await session.stderr.drain<void>();
    await session.done;
    return session.exitCode ?? -1;
  }

  void _emit(String message) {
    _outputController.add(message);
  }

  void dispose() {
    _outputController.close();
  }
}
