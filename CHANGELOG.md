# App 1.0.1+22

- Add streaming animation indicator to RichMessageContent
- Consolidate provider declarations into providers.dart
- Fix stale data when resuming app after a long pause

# App 1.0.1+21

- Fix full screen code selection area

# Server 0.1.18

- Fix interrupt not working for local shell sessions for inline bash scripts in foreground mode
- Fix crash due to race condition in native_pty

# Server 0.1.17

- Switch to native pty
- Add session mutex cleanup on SyncController initialization
- Move LocalShellBackend from agent-core to decamp-agent

# Server 0.1.16

- Fix long-running processes failing to exit
- Disable advanced (ansi) terminal features

# Server 0.1.15

- Hotfix: Fix short-lived terminal commands not producing any output.

# App 1.0.1+20

- Clean up / centralize session lock handling
- Fix secrets not propagating from the client side after a reconnect

# Server 0.1.14

- Ensure secrets CRDT is ready before starting to use it
- Fix "Bad state: Future already completed" crash

# App 1.0.1+19

- Add ability to duplicate snippet via context menu
- Fix snippet issue with snippet description getting cleared when duplicating a snippet
- Flutter bug workaround for selection issues (Partial)
- Add app icons for MacOS version
- Add MacOS AppStore/TestFlight deploy script

# Server 0.1.13

- Fix stuck session when a command is interrupted
- Add warning when pending message processing fails in multiplexer
- Fix candidate for process abort/interrupt

# App 1.0.1+18

- Implement session export to markdown
- Add missing entitlements for file save dialog
- Add file selector component
- Add ability to export session messages (WIP)

# Server 0.1.12

- Fix logic error when client connection gets interrupted in agent loop

# App 1.0.1+17

- Update the default system prompt
- Add convenience buttons for opening documents/project directory
- Add small session id label to the sessions card
- Fix context menu actions in desktop mode
- Fix copy button in context menu not tearing down

# Server 0.1.11

- Add more logging to shell service
- Add debug info jsons
- Fix project secrets not always propagating
- Potential fix for sudden server exit
- Refactor: Add session cleanup function

# App 1.0.1+16

- Fix infinite send/receive of secrets due to node being ignored

# Server 0.1.10

- Fix infinite send/receive of secrets due to node being ignored

# App 1.0.1+15

- Ensure client only sends project secrets
- Support shift-enter multi-line input on desktop mode
- Integrate full streaming for remote agent shell
- Fix unicode and terminal character display
- Fix ability to interrupt/terminate the shell

# Server 0.1.9

- Fix local port forwarding conflict when using remote vscode
- Integrate full streaming for remote agent shell

# App 1.0.1+14

- Ability to modify commands before approving them
- Add a control to reveal the hidden top bar
- Fix keyboard auto-hide for agent instructions page
- Ensure keyboard auto-hides in ai model and ssh settings dialogs
- Properly hide keyboard in main settings
- Display the current active model in the chat input
- Adjust the muted foreground color to be slightly darker
- Improve agent instructions page UI
- Fix text inputs to allow copy-paste context menu

# Server 0.1.7

- Make secrets work with shell commands as environment variables
- Fix uncaught exceptions on the server side when sending errors to a disconnected client

# App 1.0.1+12

- Hide secret option
- Add multi-command save support
- Fix scrolling in multi-command approval overlay
- Add loading indicator when connecting to a new project
- Make the project secrets page real-time
- Add "Add to Snippets" menu item and dialog
- Migrate UI to shadcn
- Implement feedback form
- Zip the feedback contents and upload to R2
- Integrate SQLite logger with iOS app
- Update default system prompt to better handle multi-line snippets
- Fix app name warning
- Allow dart analyze command without approve

# Server 0.1.6

- Add usage logging
- Implement abort command
- Reusable ssh service
- Tool execution result store
- Add automatic log truncation
- Settings CRDT
- Sync without project
- Log to sqlite
- Add log for onDisconnect

# App 1.0.1+11

- Fix tool requests not always displaying
- Fix project setting checkbox for including user agent instruction
- Refactor: Simplify the ssh settings dialog
- Refactor: Simplify the ai model dialog
- Implement message delete button in context menu

# Server 0.1.5

- Make migrations idempotent and independent of schema version

# App 1.0.1+9

- Shared loading indicator
- Fix settings and QR tests

# Server 0.1.4

- Add CrdtFlowAdapter and ensure message order is guaranteed

# App 1.0.1+8

- Fix message editing race condition
- Enable Anthropic prompt caching (5 min)
- Update MacOS deployment target
- Fix message serialization for tool calls
- Refactor: Unified Project/Session list architecture
- Fix fall-back to local mode logic when on remote project

# Server 0.1.3

- Enforce only one active session at a time
- Reduce replication noise with touchSession

# App 1.0.1+7

- Add versioning display to app
- Fix app compilation issues

# Server 0.1.2

- Rename server binary to fewshell-server
- Add Dockerfile for agent build
- Add bug report section
- Support for hiding secrets from LLM (Server side)

# App 1.0.1+6

- Fix tool result not returning result when executing via remote agent
- Implement fetch tool on the server side

# App 1.0.1+5

- Implementation of mutual TLS
- Disable auto-correct and auto-suggest
- Proper logging project-wide

# App 1.0.1+4

- Fix SQL duplicate column error when creating new project
- Add macOS target to quick launch

# App 1.0.1+2

- Implement auto-reconnection
- Initial implementation of connection activity monitoring
- Ability to hide secrets from the agent
- Update app icons
- Ability to run the agent loop on the server side

# App 1.0.0+2

- Initial Release 
