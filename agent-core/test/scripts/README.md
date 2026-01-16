# Shell Service Test Scripts

This directory contains mock bash scripts used for testing the ShellService in local shell mode.

## Scripts

### stream_output.sh
Generates streaming output line by line with configurable delays.
- Usage: `stream_output.sh <count> <delay_ms>`
- Default: 5 lines with 100ms delay between lines
- Used to test: Real-time streaming capabilities

### mixed_output.sh
Outputs to both stdout and stderr interleaved.
- Usage: `mixed_output.sh`
- Outputs 3 lines to stdout and 2 lines to stderr
- Used to test: Proper separation/merging of stdout and stderr streams

### long_running.sh
Simulates a long-running task with periodic output.
- Usage: `long_running.sh <seconds>`
- Default: 10 seconds
- Catches SIGTERM and SIGINT signals
- Used to test: Signal handling and process abortion

### exit_with_code.sh
Exits with a specified exit code.
- Usage: `exit_with_code.sh <exit_code>`
- Default: 0
- Used to test: Exit code handling

### print_secrets.sh
Prints specified environment variables.
- Usage: `print_secrets.sh <var1> <var2> ...`
- Prints "VAR=value" or "VAR is not set" for each variable
- Used to test: Secret injection and redaction

### fast_output.sh
Generates many lines of output quickly.
- Usage: `fast_output.sh <lines>`
- Default: 100 lines
- Used to test: High-throughput streaming and buffering

## Test Coverage

The shell_service_test.dart file provides comprehensive coverage including:

1. **Basic Execution** - Simple commands, stdout/stderr capture, exit codes
2. **Streaming** - Real-time output streaming, UTF-8 handling
3. **Signal Handling** - SIGINT, SIGTERM, abort scenarios
4. **Secrets** - Environment variable injection, secret redaction
5. **Error Handling** - Command not found, file not found, syntax errors
6. **Session Management** - Connection state, session creation
7. **Concurrent Execution** - Multiple simultaneous commands
8. **Edge Cases** - Long output, empty output, binary data, special characters
9. **Platform Specific** - Cross-platform compatibility

## Notes

- These scripts avoid mocking where possible and use real shell commands
- All scripts are designed to work on Linux, macOS, and other Unix-like systems
- The tests account for the behavior of the `script` command which uses PTY and merges stderr into stdout
