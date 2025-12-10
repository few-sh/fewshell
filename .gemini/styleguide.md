# Decamp Project Style Guide

# Introduction
This style guide outlines the coding conventions and philosophy for the Decamp project.
The core philosophy is **"Act like John Carmack"**: Be pragmatic, keep code simple, clean, and maintainable.
Avoid over-engineering, unnecessary abstraction layers, and identifying as a "pure" architect. Code should be written for production utility.

# Key Principles
* **Pragmatism:** Code must work reliably and solve the actual problem.
* **Simplicity (KISS):** Avoid complex solutions when simple ones suffice.
* **YAGNI:** Do not implement features "just in case".
* **DRY:** Aggressively refactor to remove duplication, especially in `agent-core`.
* **Clean Up:** Always offer to clean up unused code after implementing features.

# Language Specific Guidelines

## Dart & Flutter
* **Linter:** Follow `package:flutter_lints`. Fix all linter warnings in new code.
* **Formatting:**
    *   Use `dart format` (80 chars line length is standard, but focus on readability).
    *   **Trailing Commas:** Always use trailing commas in widget trees / parameter lists to ensure clean formatting.
    *   **Const:** Use `const` constructors for widgets whenever possible to optimize performance.
* **State Management:**
    *   Use **Riverpod** for state management.
    *   Avoid duplicating state. Derive state where possible.
    *   Place data integration and state code in `models/`, `providers/`, `database/`.
* **Widgets:**
    *   Keep `build` methods clean. Extract complex widget sub-trees into separate methods (e.g., `_buildUserSnippets`) or separate `StatelessWidget` classes if reusable.
    *   Never hard-code colors. Use `Theme.of(context)` and extensions (like `TerminalTheme`).
* **Asynchrony:**
    *   Do not swallow exceptions. Handle them at the API level (server) or GUI level (client).
    *   Use `AsyncValue` pattern with Riverpod for robust loading/error states.
* **Naming:**
    *   Classes: `UpperCamelCase`
    *   Variables/Functions: `lowerCamelCase`
    *   Private members: `_startWithUnderscore`
    *   Files: `snake_case.dart`

## Shell Scripts
*   Use standard `#!/bin/bash`.
*   Quote variables to handle spaces safely (`"$DEVICE_ID"`).
*   Handle arguments robustly.
*   Provide usage instructions for scripts.

# Architecture & Structure

## Component Boundaries
The project is strictly structured:
*   **`decamp-app/`**: Flutter frontend (Mobile/Desktop).
    *   `pages/`: Full-screen pages.
    *   `components/`: Reusable UI widgets.
*   **`decamp-agent/`**: Dart server-side backend.
*   **`agent-core/`**: Shared code (Models, API logic, Utilities).

**Rule:** Always verify if code can be shared. if logic is needed in both `app` and `agent`, move it to `agent-core`.

## Data Strategy
*   Reflect the future need for **Real-time collaboration (CRDT)** and **Replicated storage**.
*   Design models to be serializable and synchronization-friendly.

# Process
*   **Commits:** Clear, functional descriptions of *what* and *why*.
*   **Refactoring:** Continuous improvement. If you see messy code while working on a feature, clean it up (Boy Scout Rule).
*   **Safety:** Do not bypass safety checks.
*   **Documentation:** Comments should explain *why*, not *what*. Code should be self-documenting.
