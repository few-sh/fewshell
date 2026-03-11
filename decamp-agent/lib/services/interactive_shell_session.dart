import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent_core/agent_core.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

/// Manages a shared interactive shell session with sentinel-based command
/// completion detection.
///
/// This class owns the PTY session lifecycle and provides:
/// - Raw terminal key writes (for user keystrokes)
/// - Command execution with sentinel markers for exit code detection
/// - Stdout routing: to a tool call callback when one is active, otherwise
///   via [onOutput] for the client terminal screen
class InteractiveShellSession {
  static final _log = Logger('InteractiveShellSession');

  final ShellService _shellService;

  /// Called to send terminal output to the client when no tool call is active.
  final void Function(List<int> data) onOutput;

  /// Called when the interactive session ends.
  final void Function()? onSessionEnded;

  /// The shared interactive shell session (lazy, created on first use).
  late final Future<ShellSession> _session = _initSession();

  /// Pending command completers keyed by sentinel UUID.
  final Map<String, Completer<int>> _commandCompleters = {};

  /// Current stdout callback for active tool call (null when idle).
  void Function(String)? _activeToolStdoutCallback;

  /// Buffer for accumulating tool call output.
  final StringBuffer _activeToolOutputBuffer = StringBuffer();

  /// UUID of the command currently being executed (for echo filtering).
  String? _activeCommandUuid;

  /// Partial line buffer for sentinel detection across chunk boundaries.
  String _partialLineBuffer = '';

  static final RegExp sentinelPattern =
      RegExp(r'__FEWSHELL_DONE_([a-f0-9-]+)_(\d+)__');

  InteractiveShellSession({
    required ShellService shellService,
    required this.onOutput,
    this.onSessionEnded,
  }) : _shellService = shellService;

  /// Write raw bytes (terminal keys) to the interactive session.
  void writeKeys(Uint8List bytes) {
    _log.fine('Writing terminal keys: ${bytes.length} bytes');
    _session.then((session) {
      session.write(bytes);
    }).catchError((e) {
      _log.warning('Failed to write terminal keys: $e');
    });
  }

  /// Execute a command on the shared session with sentinel-based completion
  /// detection.
  ///
  /// Returns a map with stdout, stderr, exitCode, and executed fields.
  Future<Map<String, dynamic>> executeCommand({
    required String command,
    required Stream<ProcessSignal>? abortSignal,
    void Function(String)? onStdout,
    void Function(String)? onStderr,
  }) async {
    final session = await _session;
    final uuid = generateUuid();
    final completer = Completer<int>();
    _commandCompleters[uuid] = completer;

    // Set the active tool callback so stdout routes to streaming message
    _activeToolOutputBuffer.clear();
    _activeToolStdoutCallback = onStdout;
    _activeCommandUuid = uuid;

    // Flush any pending partial line (e.g. shell prompt) to terminal output
    // so it doesn't get prepended to tool output.
    if (_partialLineBuffer.isNotEmpty) {
      onOutput(utf8.encode(_partialLineBuffer));
      _partialLineBuffer = '';
    }

    StreamSubscription<ProcessSignal>? abortSubscription;
    if (abortSignal != null) {
      abortSubscription = abortSignal.listen((signal) async {
        _log.info('Aborting shared session command with signal: $signal');
        // Send Ctrl+C to the PTY to interrupt the running command
        session.write(Uint8List.fromList([3])); // ETX / Ctrl+C
      });
    }

    // Write the wrapped command to the shared session
    final wrappedCommand =
        "bash -c '${escapeForCommand(command)}'; echo \"__FEWSHELL_DONE_${uuid}_\$?__\"\n";
    session.write(Uint8List.fromList(utf8.encode(wrappedCommand)));

    try {
      final exitCode = await completer.future;
      await abortSubscription?.cancel();

      final stdout = _activeToolOutputBuffer.toString();

      return {
        'stdout': stdout,
        'stderr': '',
        'exitCode': exitCode,
        'executed': true,
      };
    } finally {
      _activeToolStdoutCallback = null;
      _activeCommandUuid = null;
      _activeToolOutputBuffer.clear();
      _commandCompleters.remove(uuid);
    }
  }

  /// Close the interactive session if it has been initialized.
  void close() {
    unawaited(
      _session.then((session) {
        session.close();
      }).catchError((e) {
        _log.warning('Error closing interactive session: $e');
      }),
    );
  }

  /// Initialize the shared interactive shell session.
  Future<ShellSession> _initSession() async {
    if (!_shellService.isConnected) {
      await _shellService
          .connect(
            const SshSettings(host: '', port: 22, username: ''),
          )
          .catchError((_) {});
    }
    final session = await _shellService.createSession();
    _log.info('Interactive shell session created');

    // Listen to stdout and route output
    session.stdout.listen(
      (data) {
        _processStdoutChunk(data);
      },
      onError: (e) {
        _log.warning('Interactive session stdout error: $e');
      },
      onDone: () {
        _log.info('Interactive session stdout stream ended');
      },
    );

    unawaited(
      session.done.then((_) {
        _log.info('Interactive session ended');
        onSessionEnded?.call();
      }),
    );

    return session;
  }

  /// Process a chunk of stdout from the interactive session.
  void _processStdoutChunk(Uint8List data) {
    final text = utf8.decode(data, allowMalformed: true);
    final combined = '$_partialLineBuffer$text';

    // Split into lines, keeping the last (possibly partial) line in the buffer
    final lines = combined.split('\n');
    _partialLineBuffer = lines.removeLast();

    final cleanedLines = <String>[];
    for (final line in lines) {
      // Check for resolved sentinel marker (with numeric exit code)
      final match = sentinelPattern.firstMatch(line);
      if (match != null) {
        final uuid = match.group(1)!;
        final exitCode = int.parse(match.group(2)!);
        final completer = _commandCompleters.remove(uuid);
        if (completer != null && !completer.isCompleted) {
          completer.complete(exitCode);
        }
        // Don't forward marker lines
        continue;
      }
      // Filter the PTY command echo: it contains the sentinel marker text
      // with unresolved $? (not matched by the regex above). Terminal control
      // characters (\r, \b) from line wrapping fracture the UUID, but the
      // __FEWSHELL_DONE_ prefix always appears intact in the raw line.
      if (_activeCommandUuid != null && line.contains('__FEWSHELL_DONE_')) {
        continue;
      }
      cleanedLines.add(line);
    }

    // Check partial buffer for complete sentinel
    final partialMatch = sentinelPattern.firstMatch(_partialLineBuffer);
    if (partialMatch != null) {
      final uuid = partialMatch.group(1)!;
      final exitCode = int.parse(partialMatch.group(2)!);
      final completer = _commandCompleters.remove(uuid);
      if (completer != null && !completer.isCompleted) {
        completer.complete(exitCode);
      }
      _partialLineBuffer = '';
    }

    // If all lines were filtered (echo/sentinel), nothing to forward.
    if (cleanedLines.isEmpty) return;

    // Reconstruct cleaned text. Each entry in cleanedLines was a complete
    // \n-terminated line (the \n was consumed by split), so restore it.
    final outputText = cleanedLines.map((l) => '$l\n').join();

    if (outputText.isEmpty) return;

    if (_activeToolStdoutCallback != null) {
      // Route to tool call streaming output
      _activeToolOutputBuffer.write(outputText);
      _activeToolStdoutCallback!(outputText);
    } else {
      // Route to terminal_output for the client terminal screen
      final outputBytes = utf8.encode(outputText);
      onOutput(outputBytes);
    }
  }

  /// Escape single quotes for bash -c wrapping.
  static String escapeForCommand(String command) {
    return command.replaceAll("'", "'\"'\"'").replaceAll('\\', '\\\\');
  }

  static const _uuid = Uuid();

  /// Generate a UUID v4 for sentinel markers.
  static String generateUuid() => _uuid.v4();
}
