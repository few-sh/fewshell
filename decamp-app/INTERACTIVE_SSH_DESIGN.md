# Interactive SSH Design & Implementation

## Overview
This document details the implementation of interactive SSH support (keyboard-interactive authentication) in the Decamp application. This feature enables the application to handle 2FA/OTP prompts and other interactive challenges from SSH servers.

## Architecture

The implementation spans two main packages: `agent-core` (logic) and `decamp-app` (UI).

### 1. Agent Core (`agent-core`)

**File:** `lib/src/services/shell_service.dart`

The `ShellService` class was modified to support the `keyboard-interactive` authentication method provided by the `dartssh2` package.

*   **Callback Definition:** A new typedef `UserPromptCallback` was defined to abstract the UI interaction.
    ```dart
    typedef UserPromptCallback = Future<String> Function(String prompt, bool echo);
    ```
*   **Service Property:** Added `UserPromptCallback? onUserPrompt` to `ShellService`.
*   **Connection Logic:** Updated the `connect` method to pass a handler to the `SSHClient` constructor's `onUserInfoRequest` parameter.
    *   **Handler Logic:**
        1.  Checks if `onUserPrompt` is set.
        2.  If NOT set (headless mode), it attempts a fallback: if the prompt looks like a password request, it sends the stored password.
        3.  If set (interactive mode), it iterates through the prompts received from the server.
        4.  For each prompt, it awaits the `onUserPrompt` callback, passing the `promptText` and `echo` flag.
        5.  Collects and returns the user's responses to the SSH client.

### 2. Decamp App (`decamp-app`)

**File:** `lib/pages/chat_session.dart`

The UI layer was updated to provide the concrete implementation of the user prompt callback.

*   **Callback Implementation:** Added `_handleSshPrompt` method to `ChatSession`.
    *   **UI:** Uses `showDialog` to present an `AlertDialog`.
    *   **Input:** Contains a `TextField` that respects the `echo` flag (obscures text if `echo` is false).
    *   **Flow:** Pauses execution until the user submits the dialog. Returns the entered text.
*   **Dependency Injection:** In the `build` method, the `ShellService` is watched via Riverpod. The `onUserPrompt` property is assigned to `_handleSshPrompt`.
    ```dart
    if (currentProject != null) {
      final shellService = ref.watch(shellServiceProvider(currentProject.id));
      shellService.onUserPrompt = _handleSshPrompt;
    }
    ```

## Authentication Flow

1.  **Initiation:** The app attempts to execute a command or connect via `ShellService`.
2.  **Handshake:** `dartssh2` performs the SSH handshake.
3.  **Auth Request:** The server requests `keyboard-interactive` authentication (e.g., for 2FA).
4.  **Client Handler:** `dartssh2` calls the `onUserInfoRequest` handler defined in `ShellService`.
5.  **UI Callback:** `ShellService` calls `onUserPrompt`.
6.  **User Interaction:**
    *   `ChatSession` shows a dialog with the server's prompt (e.g., "Verification code:").
    *   User enters the code and presses "Submit".
7.  **Response:** The code is returned to `ShellService`, then to `dartssh2`, and finally sent to the server.
8.  **Completion:** If valid, the connection is established.

## Key Decisions

*   **Callback Injection:** We inject the UI callback into the service rather than coupling the service to the UI library. This keeps `agent-core` pure Dart and testable.
*   **Fallback Logic:** We retained a fallback for headless environments where a simple password prompt might be sent via keyboard-interactive mode, ensuring backward compatibility.
*   **Riverpod Integration:** We leverage Riverpod's `ref.watch` to keep the service and UI in sync, ensuring the callback is always attached to the active service instance.
