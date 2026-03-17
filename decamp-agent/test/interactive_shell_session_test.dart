import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:agent_core/agent_core.dart';
import 'package:fewshell_agent/services/interactive_shell_session.dart';
import 'package:fewshell_agent/services/local_shell_backend.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  group('InteractiveShellSession.sentinelPattern', () {
    test('matches valid sentinel with exit code 0', () {
      final match = InteractiveShellSession.sentinelPattern
          .firstMatch('__FEWSHELL_DONE_abc123-def4_0__');
      expect(match, isNotNull);
      expect(match!.group(1), equals('abc123-def4'));
      expect(match.group(2), equals('0'));
    });

    test('matches valid sentinel with non-zero exit code', () {
      final match = InteractiveShellSession.sentinelPattern
          .firstMatch('__FEWSHELL_DONE_abc123-def4_127__');
      expect(match, isNotNull);
      expect(match!.group(1), equals('abc123-def4'));
      expect(match.group(2), equals('127'));
    });

    test('does not match regular output', () {
      final p = InteractiveShellSession.sentinelPattern;
      expect(p.firstMatch('hello world'), isNull);
      expect(p.firstMatch('exit code: 0'), isNull);
      expect(p.firstMatch('__FEWSHELL_DONE_'), isNull);
    });

    test('matches sentinel embedded in a line', () {
      final match = InteractiveShellSession.sentinelPattern
          .firstMatch('some prefix __FEWSHELL_DONE_aaa-bbb_42__ suffix');
      expect(match, isNotNull);
      expect(match!.group(1), equals('aaa-bbb'));
      expect(match.group(2), equals('42'));
    });
  });

  group('InteractiveShellSession.escapeForCommand', () {
    test('escapes single quotes', () {
      expect(
        InteractiveShellSession.escapeForCommand("echo 'hello'"),
        equals("echo '\"'\"'hello'\"'\"'"),
      );
    });

    test('escapes backslashes', () {
      expect(
        InteractiveShellSession.escapeForCommand(r'echo \n'),
        equals(r'echo \\n'),
      );
    });

    test('leaves plain text unchanged', () {
      expect(
        InteractiveShellSession.escapeForCommand('echo hello'),
        equals('echo hello'),
      );
    });
  });

  group('InteractiveShellSession.shellQuote', () {
    test('wraps plain value in single quotes', () {
      expect(
        InteractiveShellSession.shellQuote('hello'),
        equals("'hello'"),
      );
    });

    test('escapes embedded single quotes', () {
      expect(
        InteractiveShellSession.shellQuote("it's"),
        equals("'it'\"'\"'s'"),
      );
    });

    test('handles empty string', () {
      expect(
        InteractiveShellSession.shellQuote(''),
        equals("''"),
      );
    });
  });

  group('InteractiveShellSession - writeKeys', () {
    late InteractiveShellSession session;
    late List<List<int>> receivedOutput;

    setUp(() {
      receivedOutput = [];
      session = InteractiveShellSession(
        shellService: ShellService(
          null,
          null,
          'test-project',
          backend: LocalShellBackend(),
        ),
        onOutput: (data) {
          receivedOutput.add(data);
        },
      );
    });

    tearDown(() {
      session.close();
    });

    test('writes bytes to interactive session and receives output', () async {
      // Trigger lazy session creation and wait for it to be ready
      session.writeKeys(Uint8List.fromList(utf8.encode('')));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final outputCompleter = Completer<String>();
      final buffer = StringBuffer();

      // Start accumulating output
      // We need to poll receivedOutput since onOutput is called by the session
      Timer.periodic(const Duration(milliseconds: 50), (timer) {
        for (final chunk in receivedOutput) {
          buffer.write(utf8.decode(chunk, allowMalformed: true));
        }
        receivedOutput.clear();
        if (buffer.toString().contains('hello_keys')) {
          timer.cancel();
          if (!outputCompleter.isCompleted) {
            outputCompleter.complete(buffer.toString());
          }
        }
      });

      // Write a command
      session.writeKeys(
        Uint8List.fromList(utf8.encode('echo hello_keys\n')),
      );

      final output =
          await outputCompleter.future.timeout(const Duration(seconds: 5));
      expect(output, contains('hello_keys'));
    });

    test('handles multiple sequential key writes', () async {
      session.writeKeys(Uint8List.fromList(utf8.encode('')));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final outputCompleter = Completer<String>();
      final buffer = StringBuffer();

      Timer.periodic(const Duration(milliseconds: 50), (timer) {
        for (final chunk in receivedOutput) {
          buffer.write(utf8.decode(chunk, allowMalformed: true));
        }
        receivedOutput.clear();
        if (buffer.toString().contains('multi_done')) {
          timer.cancel();
          if (!outputCompleter.isCompleted) {
            outputCompleter.complete(buffer.toString());
          }
        }
      });

      // Write bytes one at a time (character by character)
      for (final char in 'echo multi_done\n'.codeUnits) {
        session.writeKeys(Uint8List.fromList([char]));
      }

      final output =
          await outputCompleter.future.timeout(const Duration(seconds: 5));
      expect(output, contains('multi_done'));
    });
  });

  group('InteractiveShellSession - executeCommand', () {
    late InteractiveShellSession session;
    late List<List<int>> receivedOutput;

    setUp(() {
      receivedOutput = [];
      session = InteractiveShellSession(
        shellService: ShellService(
          null,
          null,
          'test-project',
          backend: LocalShellBackend(),
        ),
        onOutput: (data) {
          receivedOutput.add(data);
        },
      );
    });

    tearDown(() {
      session.close();
    });

    test('executes command and returns exit code 0', () async {
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: 'echo sentinel_test',
        abortSignal: null,
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      expect(result['executed'], isTrue);
      expect(result['stdout'], contains('sentinel_test'));
    });

    test('captures non-zero exit code', () async {
      final result = await session.executeCommand(
        command: 'exit 1',
        abortSignal: null,
      );

      expect(result['exitCode'], equals(1));
      expect(result['executed'], isTrue);
    });

    test('runs sequential commands on same session', () async {
      final stdout1 = <String>[];
      final result1 = await session.executeCommand(
        command: 'echo cmd1_output',
        abortSignal: null,
        onStdout: (data) => stdout1.add(data),
      );
      final stdout2 = <String>[];
      final result2 = await session.executeCommand(
        command: 'echo cmd2_output',
        abortSignal: null,
        onStdout: (data) => stdout2.add(data),
      );

      expect(result1['exitCode'], equals(0));
      expect(result1['stdout'], contains('cmd1_output'));
      expect(result2['exitCode'], equals(0));
      expect(result2['stdout'], contains('cmd2_output'));
    });

    test('handles multi-line output', () async {
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: 'echo line1; echo line2; echo line3',
        abortSignal: null,
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      expect(result['stdout'], contains('line1'));
      expect(result['stdout'], contains('line2'));
      expect(result['stdout'], contains('line3'));
    });

    test('abort sends Ctrl+C and yields non-zero exit code', () async {
      final abortController = StreamController<ProcessSignal>.broadcast();

      // Start a long-running command
      final resultFuture = session.executeCommand(
        command: 'sleep 30',
        abortSignal: abortController.stream,
      );

      // Wait briefly, then abort
      await Future<void>.delayed(const Duration(milliseconds: 500));
      abortController.add(ProcessSignal.sigint);

      final result = await resultFuture.timeout(const Duration(seconds: 5));
      expect(result['exitCode'], isNot(equals(0)));

      await abortController.close();
    });

    test('sigint interrupts command and captures partial output', () async {
      final abortController = StreamController<ProcessSignal>.broadcast();
      final stdoutChunks = <String>[];

      // Start a command that produces output before blocking
      final resultFuture = session.executeCommand(
        command: 'echo before_interrupt; sleep 30; echo after_interrupt',
        abortSignal: abortController.stream,
        onStdout: (data) => stdoutChunks.add(data),
      );

      // Wait for the first echo to appear, then send SIGINT
      await Future<void>.delayed(const Duration(milliseconds: 500));
      abortController.add(ProcessSignal.sigint);

      final result = await resultFuture.timeout(const Duration(seconds: 5));
      expect(result['exitCode'], isNot(equals(0)));
      expect(result['stdout'], contains('before_interrupt'));
      expect(result['stdout'], isNot(contains('after_interrupt')));

      await abortController.close();
    });

    test('session remains usable after sigint abort', () async {
      final abortController = StreamController<ProcessSignal>.broadcast();

      // Start a long-running command and abort it
      final resultFuture = session.executeCommand(
        command: 'sleep 30',
        abortSignal: abortController.stream,
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));
      abortController.add(ProcessSignal.sigint);

      final abortedResult =
          await resultFuture.timeout(const Duration(seconds: 5));
      expect(abortedResult['exitCode'], isNot(equals(0)));
      await abortController.close();

      // Run another command on the same session — should succeed
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: 'echo after_abort_ok',
        abortSignal: null,
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      expect(result['stdout'], contains('after_abort_ok'));
    });

    test('routes output to onOutput when no tool call active', () async {
      // Write keys (not a tool call) — output should go to onOutput
      session.writeKeys(Uint8List.fromList(utf8.encode('echo idle_output\n')));

      // Wait for output to arrive
      await Future<void>.delayed(const Duration(seconds: 2));

      final allOutput = receivedOutput
          .map((chunk) => utf8.decode(chunk, allowMalformed: true))
          .join();
      expect(allOutput, contains('idle_output'));
    });

    test('routes output to onStdout during tool call', () async {
      // During executeCommand, output should go to onStdout, not onOutput
      receivedOutput.clear();
      final stdoutChunks = <String>[];

      final result = await session.executeCommand(
        command: 'echo tool_output',
        abortSignal: null,
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      expect(stdoutChunks.join(), contains('tool_output'));
      // onOutput should NOT have received the tool output
      // (it may have received the command echo from the PTY, but not the
      // actual command output since that was during the tool call)
    });

    test('filters command echo from tool output', () async {
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: 'echo clean_output',
        abortSignal: null,
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      final stdout = result['stdout'] as String;
      // The actual command output should be present
      expect(stdout, contains('clean_output'));
      // The sentinel marker text (echoed by PTY with unresolved $?) should
      // NOT appear in the tool output
      expect(stdout, isNot(contains('__FEWSHELL_DONE_')));
      // The bash -c wrapper should NOT appear in the tool output
      expect(stdout, isNot(contains("bash -c")));
    });

    test('streams output progressively from slow command', () async {
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: 'for i in 1 2 3; do echo "num_\$i"; sleep 0.1; done',
        abortSignal: null,
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      final stdout = result['stdout'] as String;
      expect(stdout, contains('num_1'));
      expect(stdout, contains('num_2'));
      expect(stdout, contains('num_3'));
      // Should have received multiple streaming chunks (not all at once)
      expect(stdoutChunks.length, greaterThan(1));
      // No sentinel marker in output
      expect(stdout, isNot(contains('__FEWSHELL_DONE_')));
    });

    test('sigkill terminates command and returns exit code 137', () async {
      final abortController = StreamController<ProcessSignal>.broadcast();
      final stdoutChunks = <String>[];

      // Start a command that produces output before blocking
      final resultFuture = session.executeCommand(
        command: 'echo before_kill; sleep 30; echo after_kill',
        abortSignal: abortController.stream,
        onStdout: (data) => stdoutChunks.add(data),
      );

      // Wait for the first echo to appear, then send SIGKILL
      await Future<void>.delayed(const Duration(milliseconds: 500));
      abortController.add(ProcessSignal.sigkill);

      final result = await resultFuture.timeout(const Duration(seconds: 5));
      expect(result['exitCode'], equals(137));
      expect(result['stdout'], contains('before_kill'));
      expect(result['stdout'], isNot(contains('after_kill')));

      await abortController.close();
    });

    test('session remains usable after sigkill abort', () async {
      final abortController = StreamController<ProcessSignal>.broadcast();

      // Start a long-running command and kill it
      final resultFuture = session.executeCommand(
        command: 'sleep 30',
        abortSignal: abortController.stream,
      );

      await Future<void>.delayed(const Duration(milliseconds: 500));
      abortController.add(ProcessSignal.sigkill);

      final killedResult =
          await resultFuture.timeout(const Duration(seconds: 5));
      expect(killedResult['exitCode'], equals(137));
      await abortController.close();

      // Run another command on the same session — should succeed
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: 'echo after_kill_ok',
        abortSignal: null,
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      expect(result['stdout'], contains('after_kill_ok'));
    });

    test('passes environment variables to command', () async {
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: r'echo "$MY_VAR:$OTHER_VAR"',
        abortSignal: null,
        environmentVars: {
          'MY_VAR': 'secret_value',
          'OTHER_VAR': 'second_value',
        },
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      expect(result['stdout'], contains('secret_value:second_value'));
    });

    test('environment variables are scoped to the command', () async {
      // Set an env var in the first command
      await session.executeCommand(
        command: 'echo first',
        abortSignal: null,
        environmentVars: {'SCOPED_SECRET': 'should_not_leak'},
        onStdout: (_) {},
      );

      // Second command without env vars should NOT see it
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: r'echo "val=${SCOPED_SECRET:-unset}"',
        abortSignal: null,
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      expect(result['stdout'], contains('val=unset'));
    });

    test('environment variables with special characters', () async {
      final stdoutChunks = <String>[];
      final result = await session.executeCommand(
        command: r'echo "$SPECIAL"',
        abortSignal: null,
        environmentVars: {
          'SPECIAL': "has 'quotes' and \$dollars",
        },
        onStdout: (data) => stdoutChunks.add(data),
      );

      expect(result['exitCode'], equals(0));
      expect(result['stdout'], contains("has 'quotes' and \$dollars"));
    });

    test('streams prompt from read -p (no trailing newline)', () async {
      final stdoutChunks = <String>[];
      final promptSeen = Completer<void>();

      // Start the command in a future (it will block on read)
      final resultFuture = session.executeCommand(
        command: r'read -p "Enter your name: " name && echo "Hello, $name!"',
        abortSignal: null,
        onStdout: (data) {
          stdoutChunks.add(data);
          if (stdoutChunks.join().contains('Enter your name')) {
            if (!promptSeen.isCompleted) promptSeen.complete();
          }
        },
      );

      // Wait for the prompt to be flushed (partial line without \n)
      await promptSeen.future.timeout(const Duration(seconds: 5));
      expect(stdoutChunks.join(), contains('Enter your name'));

      // Provide input so the command can complete
      session.writeKeys(Uint8List.fromList(utf8.encode('World\n')));

      final result = await resultFuture.timeout(const Duration(seconds: 5));
      expect(result['exitCode'], equals(0));
      expect(result['stdout'], contains('Hello, World!'));
    });
  });

  group('InteractiveShellSession - close behavior', () {
    test('close() returns immediately without blocking the event loop',
        () async {
      // This reproduces the server hang scenario:
      // 1. An InteractiveShellSession spawns bash -i via LocalShellBackend
      // 2. A client disconnects, triggering session cleanup
      // 3. session.close() calls NativePty.close() which calls pty_close()
      // Previously, pty_close() would block the Dart worker thread waiting
      // for bash to exit (pthread_join), which froze the entire server.

      final session = InteractiveShellSession(
        shellService: ShellService(
          null,
          null,
          'test-project',
          backend: LocalShellBackend(),
        ),
        onOutput: (data) {},
      );

      // Run a command to force the lazy bash -i session to be created
      final result = await session
          .executeCommand(
            command: 'echo hello',
            abortSignal: null,
          )
          .timeout(const Duration(seconds: 5));
      expect(result['exitCode'], equals(0));

      // Now close — this must return instantly, not block.
      // If pty_close is blocking, this Future.delayed won't run until
      // the bash process exits, and the test will time out.
      final stopwatch = Stopwatch()..start();
      session.close();
      // Yield to the event loop to verify it's not blocked
      await Future<void>.delayed(const Duration(milliseconds: 50));
      stopwatch.stop();

      // close() + a 50ms delay should complete in well under 1 second.
      // If pty_close were blocking (waiting for bash -i to exit), this
      // would take seconds or hang indefinitely.
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason:
            'close() blocked the event loop — pty_close is not non-blocking',
      );
    });

    test('close() while command is running does not block', () async {
      // Scenario: a long-running command is active when close() is called.
      // This happens when a client disconnects mid-command.

      final session = InteractiveShellSession(
        shellService: ShellService(
          null,
          null,
          'test-project',
          backend: LocalShellBackend(),
        ),
        onOutput: (data) {},
      );

      // Start a long-running command (sleep)
      unawaited(
        session
            .executeCommand(
              command: 'sleep 30',
              abortSignal: null,
            )
            .catchError((_) => <String, dynamic>{}),
      );

      // Wait for the command to start
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Close while sleep is still running — must not block
      final stopwatch = Stopwatch()..start();
      session.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'close() blocked the event loop while command was running',
      );
    });
  });
}
