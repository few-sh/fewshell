# Agent Core Migration Plan

This plan outlines the steps to move shared code from `decamp-app` to `agent-core`.
**Constraint:** Between each phase, the application must be fully buildable and working.

## Phase 0: Preparation

1.  **Update `agent-core/pubspec.yaml`**
    *   Add dependencies: `drift`, `freezed_annotation`, `json_annotation`, `uuid`, `intl`.
    *   Add dev_dependencies: `build_runner`, `drift_dev`, `freezed`, `json_serializable`.
2.  **Add Dependency to App**
    *   Add `agent_core` as a dependency in `decamp-app/pubspec.yaml` (path dependency).

## Phase 1: Low Hanging Fruit (Models & Utils)

Move pure Dart files that require no code changes.

1.  **Move Models**
    *   Move the following files to `agent-core/lib/src/models/`:
        *   `decamp-app/lib/models/agent_instruction.dart` (and generated files)
        *   `decamp-app/lib/models/chat_state.dart` (and generated files)
        *   `decamp-app/lib/models/llm_api_settings.dart` (and generated files)
        *   `decamp-app/lib/models/settings.dart` (and generated files)
        *   `decamp-app/lib/models/ssh_settings.dart` (and generated files)

2.  **Move Utils**
    *   Move the following files to `agent-core/lib/src/utils/`:
        *   `decamp-app/lib/utils/constants.dart`
        *   `decamp-app/lib/utils/date_formatter.dart`
        *   `decamp-app/lib/utils/id_generator.dart`
        *   `decamp-app/lib/utils/message_formatter.dart`
        *   `decamp-app/lib/utils/search_utils.dart`
        *   `decamp-app/lib/utils/secret_redactor.dart`
        *   `decamp-app/lib/utils/template_processor.dart`
        *   `decamp-app/lib/utils/tool_result_formatter.dart`

3.  **Move Services**
    *   Move to `agent-core/lib/src/services/`:
        *   `decamp-app/lib/services/shell_tools_provider.dart`

4.  **Export & Integrate**
    *   Export all moved files in `agent-core/lib/agent_core.dart`.
    *   Update imports in `decamp-app` to point to `package:agent_core/...`.
    *   Run `dart run build_runner build` in `agent-core`.
    *   **Verify:** Build and run `decamp-app`.

## Phase 2: Database Layer (Refactor Required)

Move the database layer and decouple it from Flutter.

1.  **Move Tables & DAOs**
    *   Move to `agent-core/lib/src/database/`:
        *   `decamp-app/lib/database/tables/*`
        *   `decamp-app/lib/database/daos/*`
        *   `decamp-app/lib/database/converters/*`

2.  **Move & Refactor Database Class**
    *   Move `decamp-app/lib/database/database.dart` to `agent-core/lib/src/database/`.
    *   **Refactor:** Remove `path_provider` dependency from `database.dart`.
    *   Modify `AppDatabase` to accept a `QueryExecutor` (or file path) in the constructor, allowing the platform (Flutter vs Server) to specify the location.

3.  **Export & Integrate**
    *   Export database classes in `agent-core/lib/agent_core.dart`.
    *   Update `decamp-app` to initialize the database using `path_provider` and pass the executor/path to the `AppDatabase` constructor.
    *   Update imports in `decamp-app`.
    *   Run `dart run build_runner build` in `agent-core`.
    *   **Verify:** Build and run `decamp-app`.

## Phase 3: Extensions

Move extensions that depend on the database layer.

1.  **Move Extensions**
    *   Move to `agent-core/lib/src/extensions/`:
        *   `decamp-app/lib/extensions/chat_message_extensions.dart`

2.  **Export & Integrate**
    *   Export in `agent-core/lib/agent_core.dart`.
    *   Update imports in `decamp-app`.
    *   **Verify:** Build and run `decamp-app`.

## Phase 4: Cleanup

1.  **Final Verification**
    *   Ensure no duplicate files remain in `decamp-app`.
    *   Run full test suite for `decamp-app`.
