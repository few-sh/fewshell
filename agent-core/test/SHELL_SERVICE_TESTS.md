# ShellService Test Suite Documentation

## Overview

This test suite provides comprehensive component testing for the `ShellService` in local shell mode. The suite consists of **49 tests** covering all major capabilities of the `LocalShellBackend` implementation.

## Testing Philosophy

- **Minimal Mocking**: Tests use real shell commands and actual process execution rather than mocks
- **Mock Scripts**: Custom bash scripts simulate specific behaviors (streaming, long-running tasks, etc.)
- **Real Environment**: Tests run in the actual execution environment with real PTY behavior
- **PTY Aware**: Tests account for the fact that `LocalShellBackend` uses the `script` command which allocates a PTY (merging stderr into stdout)

## Test Statistics

- **Total Tests**: 49 new tests (plus 10 pre-existing tests = 59 total)
- **Lines of Test Code**: 704 lines in shell_service_test.dart
- **Mock Scripts**: 6 bash scripts totaling 63 lines
- **Test Success Rate**: 100% (59/59 passing)
- **Linter Status**: ✅ No issues

## Test Coverage by Category

### 1. Basic Execution (9 tests)
Tests fundamental command execution capabilities:
- Simple echo commands
- Stdout capture
- Stderr capture (accounting for PTY behavior)
- Mixed stdout/stderr output
- Exit code handling
- Command not found scenarios
- Multi-line commands
- Pipes and redirections
- Command chaining

**Key Learnings**: PTY used by `script` command merges stderr into stdout, which is documented in test comments.

### 2. Streaming (5 tests)
Tests real-time output streaming:
- Stdout streaming with delays
- Stderr streaming (merged into stdout via PTY)
- Simultaneous stdout/stderr streaming
- Fast/high-throughput output
- UTF-8 character handling (emoji, international characters)

**Key Features Tested**: Chunked UTF-8 decoding, real-time callbacks, buffer handling

### 3. Signal Handling (4 tests)
Tests process control and abortion:
- SIGINT handling
- SIGTERM handling
- Multiple signals to same process
- Aborting already-completed commands
- Signal escalation (SIGINT → SIGTERM → SIGKILL)

**Key Features Tested**: StreamController integration, graceful process termination, timeout handling

### 4. Secrets (8 tests)
Tests secure environment variable injection:
- Secret injection as environment variables
- Missing secret handling
- Secret redaction in stdout
- Secret redaction in stderr
- Multiple secrets in same output
- Base64 encoding for special characters
- Invalid environment variable name validation
- Empty secret values

**Key Security Features**: Secrets are base64-encoded during injection and redacted from output using `***REDACTED***`

### 5. Error Handling (6 tests)
Tests error scenarios and validation:
- Bash syntax errors
- Command not found
- File not found
- Permission denied
- Empty command validation
- Whitespace-only command validation

**Key Features**: Robust error detection and reporting

### 6. Session Management (3 tests)
Tests connection and session lifecycle:
- Backend connection state (always connected for local)
- Disconnect/connect operations (no-ops for local)
- Interactive shell session creation

**Key Features**: LocalShellBackend is always connected, operations are no-ops

### 7. Concurrent Execution (3 tests)
Tests parallel command execution:
- Multiple commands simultaneously
- Concurrent commands with different outcomes
- Concurrent abort signals

**Key Features**: Proper isolation between concurrent executions

### 8. Edge Cases (9 tests)
Tests unusual but valid scenarios:
- Very long output (1000+ lines)
- Commands with no output
- Binary output handling
- Shell built-ins (cd, pwd, etc.)
- Environment variable expansion
- Glob patterns
- Sudo command detection
- Quotes and special characters

**Key Features**: Robustness across diverse scenarios

### 9. Platform Specific (2 tests)
Tests cross-platform compatibility:
- Platform detection (uname)
- Platform-specific line endings

**Key Features**: Works on Linux, macOS, and other Unix-like systems

## Mock Scripts

### stream_output.sh
Generates configurable streaming output with delays between lines.
```bash
stream_output.sh 5 100  # 5 lines with 100ms delay
```

### mixed_output.sh
Outputs to both stdout and stderr interleaved.
```bash
mixed_output.sh  # Produces 3 stdout + 2 stderr lines
```

### long_running.sh
Simulates long task with signal handling.
```bash
long_running.sh 30  # Runs for 30 seconds with progress output
```

### exit_with_code.sh
Exits with specified code.
```bash
exit_with_code.sh 42  # Exits with code 42
```

### print_secrets.sh
Prints specified environment variables.
```bash
print_secrets.sh API_KEY DB_PASSWORD  # Prints those env vars
```

### fast_output.sh
Generates many lines quickly.
```bash
fast_output.sh 1000  # Outputs 1000 lines rapidly
```

## PTY Behavior Documentation

The `LocalShellBackend` uses the `script` command to allocate a PTY for unbuffered streaming. This has several implications:

1. **Stderr Merging**: PTYs merge stderr into stdout, so stderr output appears in stdout
2. **Exit Code Limitations**: The interactive shell prompt between commands can reset `$?` to 0
3. **Extra Output**: The `script` command may add terminal control sequences (mitigated with `TERM=dumb`)

These behaviors are **documented in test comments** and tests are adapted accordingly.

## Running the Tests

```bash
# Run all agent-core tests
cd agent-core
dart test

# Run only ShellService tests
dart test test/shell_service_test.dart

# Run with specific test name pattern
dart test test/shell_service_test.dart -n "streaming"

# Run with verbose output
dart test test/shell_service_test.dart --reporter=expanded
```

## Test Maintenance

When adding new ShellService features:

1. Add corresponding test(s) in appropriate group
2. Create mock scripts if needed for complex scenarios
3. Document any PTY-related behavior in test comments
4. Run `dart analyze` to check for linter issues
5. Ensure all tests pass before committing

## Integration with CI/CD

The test suite is designed to run in CI/CD environments:
- No external dependencies beyond bash and standard Unix tools
- Deterministic behavior
- Reasonable timeouts (most tests complete in <1 second)
- Clean up temporary resources automatically

## Known Limitations

1. **Exit Code Handling**: Due to PTY behavior, some exit codes from simple commands may not be preserved
   - Workaround: Use subshells (`bash -c`) for critical exit code tests
   
2. **Stderr Separation**: Stderr is merged into stdout in PTY mode
   - Expected behavior, not a bug
   - Tests verify content appears in stdout instead
   
3. **Platform Differences**: Some tests may behave differently on Windows
   - Scripts use Unix-style paths and commands
   - Windows support requires WSL or Git Bash

## Future Enhancements

Potential areas for expansion:

- [ ] SSH backend testing (requires SSH server setup)
- [ ] Interactive session testing (stdin interaction)
- [ ] sudo command execution testing
- [ ] Performance benchmarking tests
- [ ] Windows-specific test variations
- [ ] Network failure simulation for SSH backend
