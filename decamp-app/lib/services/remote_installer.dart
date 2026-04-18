import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart' show SemanticVersion;
import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';

final _log = Logger('RemoteInstaller');

/// URL of the installer script.
///
/// It downloads release tarballs from e.g.
/// https://release.few.sh/releases/latest/fewshell-agent-linux-amd64.tar.gz
const _installerScriptUrl = 'https://get.fewshell.com';

/// Path (relative to `$HOME`) of the server binary.
const _serverBinaryPath = '.fewshell/fewshell-server';

/// Path (relative to `$HOME`) of the domain socket the server creates.
const _serverSocketPath = '.fewshell/agent.sock';

/// Maximum time to wait for the domain socket to appear after starting.
const _socketTimeout = Duration(seconds: 60);

/// Polling interval when waiting for the domain socket.
const _socketPollInterval = Duration(seconds: 1);

/// Matches the version in `fewshell-server --version` output, e.g.
/// "Fewshell Server v0.1.28".
final _versionRegex = RegExp(r'v(\d+\.\d+\.\d+)');

/// Ensures the fewshell server is installed and running on a remote system
/// via an authenticated SSH connection.
///
/// Idempotent: skips installation if a compatible binary is already present,
/// skips launching if the process is already running.
///
/// Subscribe to [output] to receive streaming text from the install process.
class RemoteInstaller {
  final SSHClient client;
  final SemanticVersion clientVersion;

  final _outputController = StreamController<String>.broadcast();

  /// Streaming output from the install / start lifecycle.
  Stream<String> get output => _outputController.stream;

  RemoteInstaller(this.client, {required this.clientVersion});

  /// Returns `true` when [clientVersion] is older (in major or minor) than
  /// [serverVersion]. Either argument may include a `+build` suffix; build
  /// metadata is ignored per the semver spec.
  ///
  /// Returns `false` (i.e. "no update required") if either version string
  /// cannot be parsed as semver.
  static bool isClientOutdated({
    required String serverVersion,
    required String clientVersion,
  }) => _isMajorMinorNewer(newer: serverVersion, than: clientVersion);

  /// `true` when [newer] has a strictly higher major or minor than [than].
  /// Build metadata is ignored. Returns `false` if either is unparseable.
  static bool _isMajorMinorNewer({
    required String newer,
    required String than,
  }) {
    final n = SemanticVersion.tryParse(newer.split('+').first);
    final t = SemanticVersion.tryParse(than.split('+').first);
    if (n == null || t == null) {
      _log.warning('Could not parse versions: newer="$newer", than="$than"');
      return false;
    }
    return n.major > t.major || (n.major == t.major && n.minor > t.minor);
  }

  /// Ensures the fewshell server is installed at a compatible version and
  /// running with its socket ready.
  ///
  /// Idempotent: each step is a no-op when already satisfied. Throws on
  /// installation or startup failure.
  Future<void> ensure() async {
    await _ensureBinaryInstalled();
    await _ensureRunning();
  }

  void dispose() {
    _outputController.close();
  }

  // --- installation ---------------------------------------------------------

  /// Ensures the installed binary is at a version compatible with [clientVersion].
  ///
  /// If the binary is missing or out of date, installs the latest version.
  /// When an upgrade happens while the old server is still running, the old
  /// process is stopped so [_ensureRunning] will launch the new one.
  Future<void> _ensureBinaryInstalled() async {
    if (await _hasCompatibleBinary()) {
      _emit('Server already installed.\n');
      return;
    }

    _emit('Server not found or out of date, installing…\n');
    await _install();

    if (await _isRunning()) {
      _emit('Stopping old server…\n');
      await _stopServer();
    }
  }

  /// `true` when the server binary exists with a major/minor version at
  /// least as new as [clientVersion].
  Future<bool> _hasCompatibleBinary() async {
    final output = await _execStdout('\$HOME/$_serverBinaryPath --version');
    final match = _versionRegex.firstMatch(output);
    if (match == null) {
      _log.fine('Could not parse server version from: $output');
      return false;
    }

    final serverVersionStr = match.group(1)!;
    final serverIsOlder = _isMajorMinorNewer(
      newer: clientVersion.toString(),
      than: serverVersionStr,
    );
    if (!serverIsOlder) return true;

    _log.info(
      'Server $serverVersionStr is older than client $clientVersion, '
      'needs update.',
    );
    return false;
  }

  /// Runs the installer script, streaming its output to [output].
  Future<void> _install() async {
    _log.info('Installing fewshell-server…');

    final session = await client.execute(
      'curl -LsSf $_installerScriptUrl '
      '| bash -s -- --skip-pairing --client-version=$clientVersion',
    );

    final buffer = StringBuffer();
    void capture(List<int> data) {
      final text = utf8.decode(data);
      buffer.write(text);
      _emit(text);
    }

    final stdoutSub = session.stdout.listen(capture);
    final stderrSub = session.stderr.listen(capture);

    await session.done;
    await stdoutSub.cancel();
    await stderrSub.cancel();

    final code = session.exitCode ?? 0;
    if (code == 0) {
      _log.info('Installation completed.');
      return;
    }

    // The script may exit non-zero on a non-critical step (e.g. copying a
    // shared library). Trust the binary check as the source of truth.
    if (await _hasCompatibleBinary()) {
      _log.warning(
        'Install script exited with code $code but binary is present, '
        'continuing. Output:\n$buffer',
      );
      return;
    }

    _log.warning('Installation failed (exit code $code). Output:\n$buffer');
    throw Exception('Installation failed with exit code $code');
  }

  // --- runtime --------------------------------------------------------------

  /// Ensures the server process is running and its socket is ready.
  Future<void> _ensureRunning() async {
    if (!await _isRunning()) {
      await _launchServer();
    } else {
      _emit('Server already running.\n');
    }

    if (!await _isSocketReady()) {
      _emit('Waiting for server socket…\n');
      await _waitForSocket();
    }
    _emit('Server is ready.\n');
  }

  /// `true` when a fewshell-server (or dev-mode dart server) process is
  /// running for the current SSH user.
  ///
  /// `pgrep -f` matches the full command line (the comm name may differ from
  /// the binary name). The `[f]` bracket trick prevents pgrep from matching
  /// its own command line.
  Future<bool> _isRunning() => _execBool(
    'pgrep -f -u \$(whoami) "[f]ewshell-server" > /dev/null 2>&1 '
    '|| pgrep -f -u \$(whoami) "[d]ecamp-agent/bin/server.dart" > /dev/null 2>&1',
  );

  /// Stops any running fewshell-server process for the current SSH user.
  Future<void> _stopServer() async {
    _log.info('Stopping fewshell-server…');
    await _execStdout(
      'pkill -f -u \$(whoami) "[f]ewshell-server" '
      '; pkill -f -u \$(whoami) "[d]ecamp-agent/bin/server.dart" '
      '; true',
    );
  }

  /// Starts the server in the background.
  Future<void> _launchServer() async {
    _log.info('Starting fewshell-server…');
    _emit('Starting server…\n');

    // Remove any stale socket from a previous run so [_waitForSocket] only
    // succeeds once the new server has created a fresh one.
    await _execStdout('rm -f \$HOME/$_serverSocketPath');

    // Fire-and-forget: don't await session.done — the SSH channel won't
    // close while the backgrounded process is alive. Success is verified by
    // [_waitForSocket].
    final session = await client.execute(
      'cd ~/.fewshell && nohup ./fewshell-server < /dev/null > /dev/null 2>&1 &',
    );
    session.close();
    _log.info('Server launched.');
  }

  /// `true` when the server's domain socket exists right now.
  Future<bool> _isSocketReady() =>
      _execBool('test -S \$HOME/$_serverSocketPath');

  /// Polls until [_isSocketReady] returns `true`, or times out.
  Future<void> _waitForSocket() async {
    final deadline = DateTime.now().add(_socketTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _isSocketReady()) return;
      await Future<void>.delayed(_socketPollInterval);
    }
    throw Exception(
      'Server started but domain socket (~/$_serverSocketPath) '
      'not found after $_socketTimeout',
    );
  }

  // --- ssh helpers ----------------------------------------------------------

  /// Runs [command] over SSH and returns `true` if it exited 0.
  Future<bool> _execBool(String command) async {
    final result = await _execStdout('($command) && echo YES || echo NO');
    return result == 'YES';
  }

  /// Executes [command] over SSH and returns its trimmed stdout.
  Future<String> _execStdout(String command) async {
    _log.fine('Executing: $command');
    final session = await client.execute(command);
    final bytes = await session.stdout.fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    await session.stderr.drain<void>();
    await session.done;
    final result = utf8.decode(bytes).trim();
    _log.fine('Result: $result');
    return result;
  }

  void _emit(String message) => _outputController.add(message);
}
