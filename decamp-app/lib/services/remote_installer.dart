import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart' show SemanticVersion;
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

/// Relative path (from $HOME) to the domain socket the server creates.
const _serverSocketPath = '.fewshell/agent.sock';

/// Maximum time to wait for the domain socket to appear after starting.
const _socketTimeout = Duration(seconds: 60);

/// Polling interval when waiting for the domain socket.
const _socketPollInterval = Duration(seconds: 1);

/// Regex to extract the version from `fewshell-server --version` output.
/// Matches lines like "Fewshell Server v0.1.28".
final _versionRegex = RegExp(r'v(\d+\.\d+\.\d+)');

/// Ensures the fewshell server is installed and running on a remote system
/// via an authenticated SSH connection.
///
/// Idempotent: skips installation if the binary exists, skips starting if
/// the process is already running.
///
/// Subscribe to [output] to receive streaming text from the install process.
class RemoteInstaller {
  final SSHClient client;
  final SemanticVersion appVersion;

  final _outputController = StreamController<String>.broadcast();

  /// Streaming output from the install / start lifecycle.
  Stream<String> get output => _outputController.stream;

  RemoteInstaller(this.client, {required this.appVersion});

  /// Ensures the fewshell server is installed and running.
  ///
  /// Returns normally when the server is confirmed running.
  /// Throws on installation or startup failure.
  Future<void> ensureServerRunning() async {
    // --- running check ---
    final running = await _isRunning();
    if (!running) {
      _emit('Starting server…\n');
      await _startServer();
    } else {
      _log.fine('Server process already running.');
      _emit('Server already running.\n');
      // The process may be running but the socket may not be ready yet
      // (e.g. server is still initializing). Wait for it.
      final socketReady = await _isSocketReady();
      if (!socketReady) {
        _log.info('Server running but socket not ready, waiting…');
        _emit('Waiting for server socket…\n');
        await _waitForSocket();
        _emit('Server is ready.\n');
      }
      return;
    }
  }

  /// `true` when the server binary exists with a matching major version.
  Future<bool> _isInstalled() async {
    _log.fine('Checking if fewshell-server is installed…');
    final output = await _execStdout('\$HOME/$_serverBinaryPath --version');
    _log.fine('_isInstalled: output = $output');

    final match = _versionRegex.firstMatch(output);
    if (match == null) {
      _log.fine('Could not parse server version from output.');
      return false;
    }

    final serverVersion = SemanticVersion.tryParse(match.group(1)!);
    if (serverVersion == null) {
      _log.fine('Invalid semver in server output: ${match.group(1)}');
      return false;
    }

    _log.fine('Server version: $serverVersion, app version: $appVersion');
    if (appVersion.major > serverVersion.major ||
        (appVersion.major == serverVersion.major &&
            appVersion.minor > serverVersion.minor)) {
      _log.info(
        'Server version ${serverVersion.major}.${serverVersion.minor} is older than '
        'app version ${appVersion.major}.${appVersion.minor}, needs update.',
      );
      return false;
    }
    return true;
  }

  /// `true` when the fewshell-server process is running.
  Future<bool> _isRunning() async {
    _log.fine('Checking if fewshell-server is running…');
    // Use -f to match the full command line (the comm name may differ from
    // the binary name). The [f] bracket trick prevents pgrep from matching
    // its own command line.
    final result = await _execStdout(
      '(pgrep -f -u \$(whoami) "[f]ewshell-server" > /dev/null 2>&1 || pgrep -f -u \$(whoami) "[d]ecamp-agent/bin/server.dart" > /dev/null 2>&1) && echo YES || echo NO',
    );
    _log.fine('_isRunning: result = $result');
    return result == 'YES';
  }

  /// Runs the installer script, streaming output to [output].
  Future<void> _install() async {
    _log.info('Installing fewshell-server…');

    final session = await client.execute(
      'curl -LsSf $_installerScriptUrl | bash -s -- --skip-pairing',
    );

    final outputBuffer = StringBuffer();
    final stdoutSub = session.stdout.listen((data) {
      final text = utf8.decode(data);
      outputBuffer.write(text);
      _emit(text);
    });
    final stderrSub = session.stderr.listen((data) {
      final text = utf8.decode(data);
      outputBuffer.write(text);
      _emit(text);
    });

    await session.done;
    await stdoutSub.cancel();
    await stderrSub.cancel();

    final code = session.exitCode;
    if (code != null && code != 0) {
      // The script may exit non-zero due to a non-critical step (e.g.
      // copying the shared library). Verify the binary actually landed.
      final installed = await _isInstalled();
      if (installed) {
        _log.warning(
          'Install script exited with code $code but binary is present, '
          'continuing. Output:\n$outputBuffer',
        );
      } else {
        _log.warning(
          'Installation failed (exit code $code). Output:\n$outputBuffer',
        );
        throw Exception('Installation failed with exit code $code');
      }
    } else {
      _log.info('Installation completed.');
    }
  }

  /// Starts the server in the background and waits for the domain socket.
  Future<void> _startServer() async {
    _log.info('Starting fewshell-server…');

    // --- install check ---
    final installed = await _isInstalled();
    if (!installed) {
      _emit('Server not found, installing…\n');
      await _install();
    } else {
      _log.fine('Server binary already present.');
      _emit('Server already installed.\n');
    }

    // Remove stale socket from a previous run so _waitForSocket polls
    // until the new server creates a fresh one.
    await _execStdout('rm -f \$HOME/$_serverSocketPath');

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

  /// One-shot check whether the domain socket exists right now.
  Future<bool> _isSocketReady() async {
    _log.info('Checking if server socket is ready…');
    final result = await _execStdout(
      'test -S \$HOME/$_serverSocketPath && echo YES || echo NO',
    );
    _log.info('_isSocketReady: result = $result');
    return result == 'YES';
  }

  /// Polls until `~/.fewshell/agent.sock` exists, or times out.
  Future<void> _waitForSocket() async {
    _log.fine('Waiting for domain socket…');
    final deadline = DateTime.now().add(_socketTimeout);

    while (DateTime.now().isBefore(deadline)) {
      final result = await _execStdout(
        'test -S \$HOME/$_serverSocketPath && echo YES || echo NO',
      );
      if (result == 'YES') {
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

  /// Executes [command] and returns the trimmed stdout.
  Future<String> _execStdout(String command) async {
    _log.info("Executing command: $command");
    final session = await client.execute(command);
    final bytes = await session.stdout.fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    await session.stderr.drain<void>();
    await session.done;
    final result = utf8.decode(bytes).trim();
    _log.info("Command result: $result");
    return result;
  }

  void _emit(String message) {
    _outputController.add(message);
  }

  void dispose() {
    _outputController.close();
  }
}
