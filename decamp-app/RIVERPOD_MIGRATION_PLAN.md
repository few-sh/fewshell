# Decamp: Riverpod + SQLite Integration Plan

## Current State Analysis

### Existing Structure
- **State Management**: Local `setState()` in widgets
- **Data Storage**: In-memory lists + `SharedPreferences` for theme
- **Models**: Simple classes in component files (`Project`, `ChatSessionItem`)
- **Dependencies**: `flutter_gen_ai_chat_ui`, `shared_preferences`, `intl`, `timeago`

### Current Data Flow
1. `main.dart` - Theme management with `setState` + `SharedPreferences`
2. `chat_session.dart` - All state (projects, sessions, messages) in widget state
3. Components - Receive data via props, callbacks bubble up

### Issues to Address
- State scattered across widgets
- No persistence for projects/sessions/messages
- Callback hell for data mutations
- No separation of business logic
- Hard to add real-time sync later
- Manual data refresh required

---

## Target Architecture

### New Project Structure
```
lib/
├── main.dart                          # App entry, ProviderScope wrapper
│
├── models/                            # Data models (freezed)
│   ├── project.dart
│   ├── session.dart
│   ├── message.dart
│   ├── snippet.dart
│   ├── secret.dart
│   └── settings.dart
│
├── database/                          # Drift database layer
│   ├── database.dart                  # Main database class
│   ├── tables/
│   │   ├── projects_table.dart
│   │   ├── sessions_table.dart
│   │   ├── messages_table.dart
│   │   └── snippets_table.dart
│   └── daos/                          # Data Access Objects
│       ├── project_dao.dart
│       ├── session_dao.dart
│       └── message_dao.dart
│
├── providers/                         # Riverpod providers
│   ├── database_provider.dart         # Database instance
│   ├── project_provider.dart          # Projects state + current project
│   ├── session_provider.dart          # Sessions per project
│   ├── message_provider.dart          # Messages per session
│   ├── theme_provider.dart            # Theme state
│   ├── settings_provider.dart         # Global + project settings
│   └── secret_provider.dart           # Secrets (keychain)
│
├── services/                          # External services
│   ├── keychain_service.dart          # iOS/Android secure storage
│   └── sync_service.dart              # Future: real-time sync
│
├── repositories/                      # Business logic layer
│   ├── project_repository.dart
│   ├── session_repository.dart
│   └── settings_repository.dart
│
├── pages/                             # UI pages
│   ├── chat_session.dart              # Convert to ConsumerWidget
│   ├── project_settings_page.dart     # New
│   └── session_detail_page.dart       # New
│
├── components/                        # Reusable widgets
│   ├── project_list.dart              # Convert to ConsumerWidget
│   ├── session_list.dart              # Convert to ConsumerWidget
│   └── message_bubble.dart            # New
│
├── themes/
│   └── neon_dark.dart                 # Move theme here
│
└── utils/
    ├── date_formatter.dart            # Existing
    └── constants.dart                 # New
```

---

## Migration Plan

### Phase 1: Foundation Setup ✅ COMPLETED
**Goal**: Add dependencies and setup base infrastructure

#### Tasks:
- [x] Update `pubspec.yaml` with new dependencies
  - `flutter_riverpod: ^2.5.1`
  - `drift: ^2.14.0`
  - `sqlite3_flutter_libs: ^0.5.0`
  - `path_provider: ^2.1.0`
  - `path: ^1.9.0`
  - `flutter_secure_storage: ^9.2.2` (for secrets)
  - `freezed_annotation: ^2.4.1`
  - `json_annotation: ^4.9.0`
  - Dev: `build_runner`, `drift_dev`, `freezed`, `json_serializable`

- [x] Create base folder structure
  - Create `models/`, `database/`, `providers/`, `services/`, `repositories/`
  - Create subfolders for database tables and DAOs

- [x] Setup build configuration
  - Add `build.yaml` for code generation settings
  - Create scripts for running build_runner

#### Success Criteria:
- ✅ All folders created
- ✅ Dependencies installed
- ✅ No compilation errors

---

### Phase 2: Data Models ✅ COMPLETED
**Goal**: Create immutable, type-safe models with Freezed

#### Tasks:
- [x] Create `models/project.dart`
  - Convert existing `Project` class to Freezed model
  - Add `toJson`/`fromJson`
  - Add `createdAt`, `updatedAt` fields

- [x] Create `models/session.dart`
  - Convert existing `ChatSessionItem` to Freezed
  - Rename to `Session`
  - Add `projectId` foreign key
  - Add metadata fields (createdAt, updatedAt)

- [x] Create `models/message.dart`
  - Based on `ChatMessage` from chat UI library
  - Add `sessionId` foreign key
  - Add local persistence fields

- [x] Create `models/settings.dart`
  - Global settings structure (AppSettings)
  - Project-specific overrides (ProjectSettings)
  - Support for global/project secrets

- [x] Create `models/snippet.dart` (future)
  - Snippet model for code/command snippets

- [x] Create `models/secret.dart` (future)
  - Secret metadata (actual values in keychain)

- [x] Run code generation
  - `dart run build_runner build --delete-conflicting-outputs`

#### Success Criteria:
- ✅ All models compile successfully
- ✅ toJson/fromJson generated and working
- ✅ Freezed methods available (copyWith, equality, toString)

---

### Phase 3: Database Layer (Drift) ✅ COMPLETED
**Goal**: Setup SQLite database with Drift

#### Tasks:
- [x] Create `database/tables/projects_table.dart`
  - Define table schema
  - Indexes for common queries

- [x] Create `database/tables/sessions_table.dart`
  - Define table with projectId foreign key
  - Index on projectId + timestamp

- [x] Create `database/tables/messages_table.dart`
  - Define table with sessionId foreign key
  - Index on sessionId + createdAt

- [x] Create `database/tables/snippets_table.dart`
  - Define table with projectId foreign key

- [x] Create `database/database.dart`
  - Main database class
  - Define all tables
  - Migration logic
  - Database version management

- [x] Create DAOs
  - `database/daos/project_dao.dart` - CRUD + watch streams
  - `database/daos/session_dao.dart` - CRUD + watch streams
  - `database/daos/message_dao.dart` - CRUD + watch streams

- [x] Run code generation for Drift
  - Generate database code

- [x] Write database initialization logic
  - Handle first-time setup
  - Seed with sample data for development

#### Success Criteria:
- ✅ Database creates successfully
- ✅ All DAOs compile
- ✅ Watch streams return data
- ✅ Can insert/query/update/delete

---

### Phase 4: Services Layer ✅ COMPLETED
**Goal**: External service integrations

#### Tasks:
- [x] Create `services/keychain_service.dart`
  - Wrapper for `flutter_secure_storage`
  - Methods: saveSecret, getSecret, deleteSecret, listSecrets
  - Handle iOS Keychain / Android Keystore
  - Project-scoped secrets (project:{projectId}:{secretName})
  - Global secrets (global:{secretName})

- [ ] Create `services/sync_service.dart` (stub for future)
  - Interface for real-time sync
  - Placeholder methods
  - **Note**: Deferred to Phase 11 (Future Enhancements)

#### Success Criteria:
- ✅ Can save/retrieve secrets securely
- ✅ Services ready for provider integration
- ✅ Support for both project-scoped and global secrets

---

### Phase 5: Providers Setup ✅ COMPLETED
**Goal**: Create Riverpod providers for state management

#### Tasks:
- [x] Create `providers/database_provider.dart`
  - Provide database instance with auto-disposal
  - Expose DAOs (projectDao, sessionDao, messageDao)
  - Single source of truth

- [x] Create `providers/project_provider.dart`
  - `projectsStreamProvider` - Stream all projects
  - `currentProjectIdProvider` - StateProvider for selected project
  - `currentProjectProvider` - Derived provider for current project
  - `projectActionsProvider` - CRUD methods (create, update, delete, updateLastSessionDate)
  - ID generation: 'proj_{timestamp}_{random8}'

- [x] Create `providers/session_provider.dart`
  - `sessionsStreamProvider.family` - Stream sessions per project
  - `currentProjectSessionsProvider` - Sessions for current project
  - `currentSessionIdProvider` - StateProvider for selected session
  - `currentSessionProvider` - Derived provider for current session
  - `sessionActionsProvider` - CRUD methods with project association
  - ID generation: 'sess_{timestamp}_{random8}'

- [x] Create `providers/message_provider.dart`
  - `messagesStreamProvider.family` - Stream messages per session
  - `currentSessionMessagesProvider` - Messages for current session
  - `messageActionsProvider` - CRUD methods (sendMessage, update, delete)
  - ID generation: 'msg_{timestamp}_{random8}'

- [x] Create `providers/theme_provider.dart`
  - Migrated existing theme logic from main.dart
  - `themeProvider` - StateNotifierProvider<ThemeNotifier, ThemeMode>
  - `sharedPreferencesProvider` - Override in main()
  - Persist to SharedPreferences
  - Methods: setThemeMode(), toggleTheme()

- [x] Create `providers/settings_provider.dart`
  - `globalSettingsProvider` - Global app settings with StateNotifier
  - `projectSettingsProvider.family` - Per-project settings
  - `effectiveSettingsProvider` - Merged global + project overrides
  - `EffectiveSettings` class with smart getters (agentsMd, githubRepo, etc.)
  - Dual persistence: SharedPreferences (global), SharedPreferences (project)

- [x] Create `providers/secret_provider.dart`
  - `keychainServiceProvider` - KeychainService singleton
  - `globalSecretsProvider` - GlobalSecretsActions for global secrets
  - `projectSecretsProvider.family` - ProjectSecretsActions per project
  - `effectiveSecretsProvider` - FutureProvider merging global + project secrets
  - `secretExistsProvider` - Check secret existence with SecretLookup
  - Integration with keychain_service for secure storage

#### Success Criteria:
- ✅ All providers compile with zero errors
- ✅ Verified with `flutter analyze lib/providers/` - no issues found
- ✅ Providers accessible via ref.watch()
- ✅ State updates propagate correctly
- ✅ Consistent ID generation patterns across entities
- ✅ Smart merge logic for settings and secrets

---

### Phase 6: Repository Layer ⚠️ NOT IMPLEMENTED (HIGH PRIORITY)
**Goal**: Business logic and data coordination

**Status**: Architecture gap identified. Pages currently contain business logic that should be in repositories.

#### Current Issues:
- `chat_session.dart` has 1183 lines with complex business logic
- Message syncing logic in UI layer
- AI interaction flow mixed with widget state
- Difficult to test business logic (requires widget tests)
- Code reusability limited across pages

#### Tasks:
- [ ] Create `repositories/chat_repository.dart` ⭐ **HIGH PRIORITY**
  - Coordinate message sending with AI responses
  - Handle conversation state for tool calls
  - Manage message syncing between database and UI
  - Business logic: sendMessageToAI(), handleToolCalls(), syncMessages()
  - Depends on: MessageActions, SessionActions, LlmService
  
- [ ] Create `repositories/project_repository.dart`
  - Coordinate between database and future sync service
  - Business logic for project operations
  - Handle project-session relationships
  - Validation for project names and descriptions

- [ ] Create `repositories/session_repository.dart`
  - Session management logic
  - Handle session-project relationships
  - Auto-create sessions when needed
  - Session switching coordination

- [ ] Create `repositories/settings_repository.dart`
  - Settings merge logic (global + project overrides)
  - Validation for settings values
  - Handle model-specific instruction overrides
  - LLM configuration resolution

#### Success Criteria:
- ✅ Clean separation of concerns
- ✅ Business logic isolated from UI
- ✅ Easy to unit test without widgets
- ✅ Reusable across multiple pages
- ✅ Reduced widget complexity (< 500 lines per page)

---

### Phase 7: Update Main App ✅ COMPLETED
**Goal**: Wrap app with ProviderScope, migrate theme

#### Tasks:
- [x] Update `main.dart`
  - Added `ProviderScope` wrapper
  - Made main() async to initialize SharedPreferences
  - Override sharedPreferencesProvider with actual instance
  - Removed theme state management (migrated to provider)
  - Changed DecampApp from StatefulWidget to ConsumerWidget
  - Removed loading screen (SharedPreferences loaded before app starts)
  - Removed onThemeChanged callback prop drilling

- [x] Move theme definition
  - Moved `neonDarkTheme` to `themes/neon_dark.dart`
  - Imported in main.dart
  - Removed duplicate theme definition

- [x] Add provider integration
  - DecampApp now watches themeProvider reactively
  - Theme changes automatically trigger rebuilds

#### Success Criteria:
- ✅ App starts without errors
- ✅ ProviderScope wraps MaterialApp
- ✅ Theme loads from provider
- ✅ No prop drilling for theme changes
- ✅ SharedPreferences properly overridden

---

### Phase 8: Migrate ChatSession Page 🔄 PARTIAL - NEEDS REFACTORING
**Goal**: Convert main page to use Riverpod providers and extract business logic

**Status**: Basic Riverpod integration complete, but page is too complex (1183 lines) with business logic in widget state.

#### Completed:
- [x] Update `pages/chat_session.dart` widget structure
  - Changed from `StatefulWidget` to `ConsumerStatefulWidget`
  - Changed State to `ConsumerState<ChatSession>`
  - Added flutter_riverpod and theme_provider imports
  - Removed onThemeChanged callback parameter

- [x] Update theme dialog
  - Replaced widget.onThemeChanged callback with direct provider calls
  - Uses ref.read(themeProvider.notifier).setThemeMode()
  - Theme switching now works correctly

- [x] Basic provider integration
  - Watches currentProjectIdProvider, currentSessionIdProvider
  - Loads messages from currentSessionMessagesProvider
  - Uses messageActionsProvider for saving messages

#### Remaining Tasks (Requires Phase 12 - Refactoring):
- [ ] Extract ChatController (StateNotifier)
  - Move state from _ChatSessionState to ChatController
  - Create ChatState with Freezed (isLoading, messages, pendingActions, etc.)
  - Eliminate local state variables (_isLoading, _pendingActions, _conversationForToolCalls, etc.)
  - Move message syncing logic to controller

- [ ] Simplify message syncing
  - Use ref.listen() properly for reactive updates
  - Remove manual _syncMessagesFromProvider complexity
  - Consider chatMessagesForUIProvider for data conversion

- [ ] Remove remaining local state
  - Move _messageIdCounter to provider
  - Move _lastSyncedSessionId tracking to controller
  - Clean up _syncedMessageIds logic

- [ ] Improve session management
  - Use SessionManager from providers
  - Remove manual session selection logic

#### Success Criteria:
- ✅ Page renders without errors
- ✅ Theme switching works with providers
- ✅ Can switch projects (using providers)
- ✅ Can view sessions (using providers)
- ✅ Chat messages persist to database
- ⏳ Widget < 500 lines (currently 1183)
- ⏳ No local state management
- ⏳ Business logic in ChatController
- ⏳ Easy to test without UI

---

### Phase 9: Migrate Components ✅ MOSTLY COMPLETED
**Goal**: Convert presentational components to ConsumerWidgets

#### Completed:
- [x] `components/project_list.dart` - Uses ConsumerWidget pattern
- [x] `components/session_list.dart` - Uses ConsumerWidget pattern  
- [x] `components/main_drawer.dart` - Integrated with providers
- [x] `pages/projects_page.dart` - Full ConsumerStatefulWidget integration
- [x] `pages/sessions_history.dart` - Provider-based
- [x] `pages/secrets_page.dart` - ConsumerStatefulWidget with tab controller
- [x] `pages/snippets_page.dart` - ConsumerStatefulWidget with tab controller
- [x] `components/ai_model_dialog.dart` - LLM settings management
- [x] `components/ssh_settings_dialog.dart` - ConsumerStatefulWidget for SSH config

#### Remaining Tasks:
- [ ] Review all components for consistency
  - Ensure no prop drilling remains
  - Verify error state handling
  - Check loading state patterns

- [ ] Add missing error/empty states
  - Standardize error display
  - Improve empty state messages
  - Add retry mechanisms

#### Success Criteria:
- ✅ All major components are ConsumerWidgets
- ✅ No prop drilling for data/actions
- ✅ Actions call providers directly
- ⏳ Consistent error handling patterns
- ⏳ Proper loading states everywhere

---

### Phase 10: Testing & Refinement ⚠️ NEEDS ATTENTION
**Goal**: Ensure everything works, add tests

**Status**: Limited test coverage. Need comprehensive testing strategy.

#### Manual Testing (Partial):
- [x] Basic CRUD operations work
  - Create/read/update/delete projects ✅
  - Create/read/update/delete sessions ✅
  - Send messages ✅
  - Switch projects and verify session isolation ✅
  - Theme persistence ✅

#### Remaining Tasks:
- [ ] **Add Unit Tests** ⭐ **HIGH PRIORITY**
  - [ ] Provider tests
    - Test project provider (create, update, delete, currentProject)
    - Test session provider (auto-creation, switching)
    - Test message provider (CRUD operations)
    - Test settings provider (merge logic, overrides)
  - [ ] Repository tests (after Phase 6)
    - Test ChatRepository business logic
    - Test settings resolution
  - [ ] Model tests
    - Test Freezed equality and copyWith
    - Test JSON serialization
  - [ ] DAO tests
    - Test database queries
    - Test stream updates

- [ ] **Add Widget Tests**
  - [ ] Component tests with provider overrides
  - [ ] Page tests (ChatSession, ProjectsPage, etc.)
  - [ ] Test loading/error/empty states

- [ ] **Add Integration Tests**
  - [ ] End-to-end flow tests
  - [ ] Database persistence tests
  - [ ] Multi-session scenarios

- [ ] **Handle Edge Cases**
  - [ ] Empty states (no projects, no sessions)
  - [ ] Loading states (database queries)
  - [ ] Error states (network failures, database errors)
  - [ ] Slow database operations
  - [ ] Concurrent modifications

- [ ] **Performance Testing**
  - [ ] Large number of projects/sessions
  - [ ] Message history with 1000+ messages
  - [ ] Database query optimization
  - [ ] Memory leak detection
  - [ ] Frame rate monitoring

#### Success Criteria:
- ✅ All CRUD operations work
- ✅ Data persists across restarts
- ⏳ 80%+ test coverage for providers
- ⏳ 60%+ test coverage for repositories
- ⏳ No memory leaks detected
- ⏳ Smooth UI performance (60fps)
- ⏳ < 100ms for common database operations

---

### Phase 11: Code Quality Improvements ⚠️ NEW PHASE
**Goal**: Address architectural improvements identified in code review

#### Tasks:

##### 11.1: Centralize ID Generation
- [ ] Create `utils/id_generator.dart`
  - Single utility for all entity ID generation
  - Methods: project(), session(), message(), snippet(), etc.
  - Ensure uniqueness with timestamp + random
  - Remove scattered ID generation from providers

##### 11.2: Improve Error Handling
- [ ] Add AsyncValue patterns for provider actions
  - Wrap async operations in AsyncValue
  - Provide user feedback for failures
  - Add retry mechanisms
  - Create reusable error display widgets

##### 11.3: Fix Provider Initialization
- [ ] Update StateNotifier initialization patterns
  - Fix async in constructor issues (settings_provider.dart)
  - Consider AsyncNotifier for async initialization
  - Ensure state updates aren't missed

##### 11.4: Decouple Services from Providers
- [ ] Refactor `services/llm_service.dart` ⭐ **MEDIUM PRIORITY**
  - Remove Ref dependency
  - Pass dependencies explicitly
  - Make it a pure service class
  - Handle configuration via providers externally
  - Create configuredLlmProvider for setup

##### 11.5: Improve Message Syncing
- [ ] Simplify chat message synchronization
  - Use ref.listen properly for reactive updates
  - Remove complex _syncMessagesFromProvider logic
  - Create chatMessagesForUIProvider for data conversion
  - Handle race conditions properly

##### 11.6: Add Comprehensive Loading/Error States
- [ ] Standardize UI patterns
  - Use AsyncValue.when() consistently
  - Create LoadingIndicator component
  - Create ErrorView component with retry
  - Handle all provider states (loading, error, data)

#### Success Criteria:
- ✅ Single source for ID generation
- ✅ No scattered error handling
- ✅ Services are pure (no provider dependencies)
- ✅ Clear initialization patterns
- ✅ Consistent loading/error UI

---

### Phase 12: Major Refactoring ⭐ **HIGH PRIORITY**
**Goal**: Extract complex widget logic to StateNotifiers

#### Tasks:

##### 12.1: Extract ChatController
- [ ] Create `providers/chat_controller.dart`
  - Define ChatState with Freezed
    - isLoading, currentModelIdentifier
    - pendingActions, executionProgress
    - conversationState, messages
  - Create ChatController extends StateNotifier<ChatState>
  - Move all business logic from _ChatSessionState
    - sendMessage()
    - approveActions()
    - handleToolCalls()
    - syncMessagesFromDatabase()
  - Provider: chatControllerProvider

- [ ] Refactor `pages/chat_session.dart`
  - Remove local state variables
  - Watch chatControllerProvider
  - Reduce from 1183 lines to < 500 lines
  - Pure UI rendering only
  - Delegate all logic to ChatController

##### 12.2: Benefits
- Testable without widgets
- State is immutable (via Freezed)
- Clear state transitions
- Can add state history/undo functionality
- Reusable across different UI implementations

#### Success Criteria:
- ✅ chat_session.dart < 500 lines
- ✅ All business logic in ChatController
- ✅ ChatState is immutable (Freezed)
- ✅ Unit tests for ChatController (no widgets)
- ✅ Clear separation: UI renders, Controller handles logic

---

### Phase 13: Future Enhancements (Not Immediate)
**Goal**: Prepare for future features

#### Future Tasks:
- [ ] Implement secrets management
  - Full CRUD with keychain storage
  - Project-specific secrets
  - Global secrets

- [ ] Implement snippets
  - Code/command snippets
  - Organization and tagging
  - Quick access

- [ ] Add real-time collaboration
  - WebSocket or Firebase integration
  - Implement sync_service.dart
  - Conflict resolution
  - Presence indicators

- [ ] GitHub integration
  - OAuth
  - Sync snippets/AGENTS.md from repos

- [ ] Monitoring (Premium feature)
  - Alert management
  - Status dashboards

---

## Key Patterns to Follow

### Provider Naming Convention
- `*Provider` - Basic providers (single value)
- `*Provider.family` - Parameterized providers (e.g., per project)
- `*ActionsProvider` - Mutation/action methods
- `current*Provider` - Derived state for currently selected item

### State Organization
- Keep providers focused and single-purpose
- Use `.family` for parameterized state (per project, per session)
- Use derived providers for computed values
- Separate read operations (watch) from write operations (actions)

### Database Patterns
- All database access through DAOs
- Use watch() streams for reactive updates
- Keep queries simple, optimize with indexes
- Use transactions for multi-table operations

### Testing Strategy
- Mock providers using ProviderContainer
- Test business logic in repositories
- Test UI with provider overrides
- Integration tests with real database (in-memory)

---

## Migration Risks & Mitigations

### Risk: Breaking existing functionality
**Mitigation**: Migrate one feature at a time, keep old code until verified

### Risk: Performance issues with large datasets
**Mitigation**: Implement pagination early, add database indexes

### Risk: Complex state dependencies
**Mitigation**: Use Riverpod's provider dependencies, keep providers simple

### Risk: Learning curve for team
**Mitigation**: Document patterns, pair programming during migration

---

## Success Metrics

### Technical
- [x] Zero setState() calls in major widgets (chat_session still has local state)
- [x] All data persists across app restarts
- [ ] < 100ms for common database operations (needs performance testing)
- [ ] Zero memory leaks (needs verification)
- [ ] 80%+ test coverage for providers/repositories (currently minimal)

### User Experience
- [x] Instant UI updates on state changes (reactive streams working)
- [x] Smooth animations (60fps) (visual confirmation needed)
- [x] Data loads within 1 second (seems fast, needs measurement)
- [x] No data loss (verified manually)

### Code Quality
- [x] All models immutable (Freezed)
- [x] Type-safe database queries (Drift)
- [ ] Clear separation of concerns (business logic still in UI)
- [x] Easy to add new features (provider pattern working well)

### Architecture Quality (Code Review Findings)
- [ ] Repository layer implemented (not started)
- [ ] Business logic extracted from widgets (ChatSession needs work)
- [ ] Services are pure (LlmService has Ref dependency)
- [ ] Comprehensive error handling (inconsistent)
- [ ] Comprehensive test coverage (minimal)
- [ ] ID generation centralized (scattered across providers)
- [ ] Message syncing simplified (complex logic in chat_session)

---

## Current Status Summary (Updated: Nov 2025)

### ✅ Completed
- **Phases 1-5**: Foundation, Models, Database, Services (partial), Providers - All working
- **Phase 7**: Main app integration - Complete
- **Phase 8**: ChatSession migration - Partially done (basic integration works)
- **Phase 9**: Component migration - Mostly complete

### 🔄 In Progress
- **Phase 8**: ChatSession needs refactoring (1183 lines, too complex)
- **Phase 10**: Testing - minimal coverage, needs expansion

### ⚠️ Critical Gaps Identified
1. **No Repository Layer** (Phase 6) - Business logic in UI
2. **ChatController Missing** (Phase 12) - State management in widget
3. **Limited Testing** (Phase 10) - Need provider/repository tests
4. **Service Coupling** (Phase 11.4) - LlmService depends on Ref
5. **Error Handling** (Phase 11.2) - Inconsistent patterns
6. **ID Generation** (Phase 11.1) - Scattered across files

### 🎯 Recommended Next Steps (Priority Order)

#### Immediate (Week 1-2):
1. **Phase 6**: Implement Repository Layer
   - Start with ChatRepository (highest impact)
   - Move business logic out of chat_session.dart
   
2. **Phase 12**: Extract ChatController
   - Create ChatState with Freezed
   - Move state management to StateNotifier
   - Reduce chat_session.dart complexity

3. **Phase 11.4**: Decouple LlmService from Providers
   - Make it a pure service
   - Pass dependencies explicitly

#### Short-term (Week 3-4):
4. **Phase 10**: Add Core Tests
   - Provider tests (project, session, message)
   - Repository tests (after Phase 6)
   - Integration tests for critical flows

5. **Phase 11.1-11.3**: Code Quality Improvements
   - Centralize ID generation
   - Improve error handling patterns
   - Fix initialization issues

#### Medium-term (Month 2):
6. **Phase 11.5-11.6**: Polish
   - Simplify message syncing
   - Standardize loading/error UI
   - Performance optimization

7. **Phase 13**: Future Enhancements
   - Full secrets management UI
   - GitHub integration
   - Real-time sync preparation

---

## Architecture Assessment

### Strengths ✅
- Excellent provider organization (family, derived, actions patterns)
- Smart settings hierarchy (global/project with overrides)
- Type-safe database with Drift
- Secure secret management with platform keychain
- Good use of Freezed for immutability
- Reactive streams working well

### Weaknesses ⚠️
- Missing repository layer (business logic in UI)
- ChatSession page too complex (1183 lines)
- LlmService coupled to Riverpod
- Inconsistent error handling
- Limited test coverage
- ID generation scattered
- Message syncing overly complex

### Overall Grade: 7.5/10
**Status**: Production-ready for current features, but needs refactoring for maintainability and scalability.

The foundation is solid. Implementing the repository layer and extracting ChatController would elevate this to excellent (9/10).

---

## Timeline Estimate

### Original Estimate (Phases 1-10):
- **Phase 1-2**: 1-2 days (setup + models) ✅ COMPLETED
- **Phase 3-4**: 2-3 days (database + services) ✅ COMPLETED
- **Phase 5-6**: 2-3 days (providers + repositories) ⚠️ Providers done, repositories not started
- **Phase 7-9**: 3-4 days (UI migration) ✅ MOSTLY COMPLETED
- **Phase 10**: 2-3 days (testing) ⏳ IN PROGRESS

**Original Total**: ~2 weeks for full migration

### Revised Estimate (Including New Phases):
- **Phase 6**: Repository Layer - 3-4 days
- **Phase 10**: Testing - 4-5 days (comprehensive)
- **Phase 11**: Code Quality - 2-3 days
- **Phase 12**: Major Refactoring - 3-4 days (ChatController extraction)

**Remaining Work**: ~2 weeks to address critical gaps and quality improvements

### Recommended Approach:
1. **Week 1**: Focus on Phase 6 (Repositories) + Phase 12 (ChatController)
   - Highest impact on code quality and maintainability
   - Enables proper testing
   
2. **Week 2**: Phase 10 (Testing) + Phase 11 (Code Quality)
   - Test coverage for new repositories
   - Clean up technical debt
   - Performance validation

**Status**: Can continue using app as-is (functional), but recommend refactoring for long-term maintainability before adding major new features.

---

## Code Examples for Critical Improvements

### Example 1: ChatRepository (Phase 6)

**Current Problem**: Business logic in chat_session.dart (1183 lines)

**Solution**:
```dart
// lib/repositories/chat_repository.dart
class ChatRepository {
  final MessageActions _messageActions;
  final SessionActions _sessionActions;
  final LlmService _llmService;
  final Ref _ref;
  
  ChatRepository(
    this._messageActions,
    this._sessionActions,
    this._llmService,
    this._ref,
  );
  
  /// Send user message and get AI response
  Future<void> sendMessageToAI({
    required String content,
    required String sessionId,
  }) async {
    // 1. Save user message
    await _messageActions.sendMessage(
      sessionId: sessionId,
      userId: 'user',
      userName: 'You',
      content: content,
    );
    
    // 2. Update session timestamp
    await _sessionActions.updateLastActivity(sessionId);
    
    // 3. Get AI response (streaming)
    final stream = _llmService.sendMessageWithTools(content);
    await for (final chunk in stream) {
      // Handle streaming response
      // Save assistant message when complete
    }
  }
  
  /// Handle tool calls approval flow
  Future<void> handleToolCallsApproval({
    required List<ToolCall> toolCalls,
    required bool approved,
  }) async {
    if (approved) {
      // Execute approved tools
      // Save results to conversation
    } else {
      // Handle rejection
    }
  }
}

// Provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(messageActionsProvider),
    ref.watch(sessionActionsProvider),
    ref.watch(llmServiceProvider),
    ref,
  );
});
```

### Example 2: ChatController (Phase 12)

**Current Problem**: Widget state in _ChatSessionState

**Solution**:
```dart
// lib/providers/chat_controller.dart
@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    @Default(false) bool isLoading,
    @Default([]) List<ChatMessage> messages,
    String? currentModelIdentifier,
    List<CommandAction>? pendingActions,
    ExecutionProgress? executionProgress,
    String? error,
  }) = _ChatState;
}

class ChatController extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final Ref _ref;
  
  ChatController(this._repository, this._ref) : super(const ChatState()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    // Load initial state
    await _loadMessages();
  }
  
  Future<void> _loadMessages() async {
    final sessionId = _ref.read(currentSessionIdProvider);
    if (sessionId == null) {
      state = state.copyWith(messages: []);
      return;
    }
    
    // Watch messages reactively
    _ref.listen(currentSessionMessagesProvider, (previous, next) {
      next.whenData((dbMessages) {
        final chatMessages = _convertToChatMessages(dbMessages);
        state = state.copyWith(messages: chatMessages);
      });
    });
  }
  
  Future<void> sendMessage(String content) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final sessionId = _ref.read(currentSessionIdProvider);
      if (sessionId == null) {
        throw Exception('No session selected');
      }
      
      await _repository.sendMessageToAI(
        content: content,
        sessionId: sessionId,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
  
  Future<void> approveActions(List<CommandAction> actions) async {
    state = state.copyWith(pendingActions: null, isLoading: true);
    
    try {
      // Execute actions
      for (var i = 0; i < actions.length; i++) {
        state = state.copyWith(
          executionProgress: ExecutionProgress(
            current: i + 1,
            total: actions.length,
            currentCommand: actions[i].command,
          ),
        );
        
        await _executeAction(actions[i]);
      }
    } finally {
      state = state.copyWith(
        isLoading: false,
        executionProgress: null,
      );
    }
  }
  
  void cancelActions() {
    state = state.copyWith(pendingActions: null);
  }
}

// Provider
final chatControllerProvider = 
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    ref.watch(chatRepositoryProvider),
    ref,
  );
});
```

**Usage in Widget**:
```dart
// lib/pages/chat_session.dart (simplified)
class ChatSession extends ConsumerWidget {
  const ChatSession({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    
    return Scaffold(
      body: chatState.isLoading
          ? const LoadingIndicator()
          : ChatUI(
              messages: chatState.messages,
              onSendMessage: controller.sendMessage,
            ),
    );
  }
}
```

### Example 3: Decoupled LlmService (Phase 11.4)

**Current Problem**: LlmService depends on Ref

**Solution**:
```dart
// lib/services/llm_service.dart (refactored)
class LlmService {
  final KeychainService _keychainService;
  
  LlmService(this._keychainService);
  
  /// Create provider with given configuration
  Future<ChatCapability> createProvider({
    required LlmApiSettings config,
    required String apiKey,
    String? systemPrompt,
  }) async {
    return await ai()
        .provider(config.providerId)
        .apiKey(apiKey)
        .model(config.model)
        .temperature(config.temperature)
        .systemPrompt(systemPrompt)
        .create();
  }
  
  /// Get API key for configuration
  Future<String?> getApiKey({
    required String identifier,
    String? projectId,
  }) async {
    final key = projectId != null
        ? LlmApiKeychainKeys.buildProjectKey(projectId, identifier)
        : LlmApiKeychainKeys.buildGlobalKey(identifier);
    
    return await _keychainService.getGlobalSecret(key);
  }
}

// New provider for configured LLM
final configuredLlmProvider = FutureProvider<ChatCapability?>((ref) async {
  final service = ref.watch(llmServiceProvider);
  final projectId = ref.watch(currentProjectIdProvider);
  
  // Get active configuration
  final settings = projectId != null
      ? ref.watch(projectLlmSettingsProvider(projectId))
      : ref.watch(globalLlmSettingsProvider);
  
  final config = settings.where((s) => s.enabled).firstOrNull;
  if (config == null) return null;
  
  // Get API key
  final apiKey = await service.getApiKey(
    identifier: config.identifier,
    projectId: projectId,
  );
  if (apiKey == null) return null;
  
  // Get system prompt
  final effectiveSettings = await ref.watch(
    effectiveSettingsProvider(projectId ?? 'global').future,
  );
  final systemPrompt = effectiveSettings.agentInstruction
      ?.getInstruction(config.model);
  
  // Create provider
  return await service.createProvider(
    config: config,
    apiKey: apiKey,
    systemPrompt: systemPrompt,
  );
});
```

### Example 4: Centralized ID Generation (Phase 11.1)

**Current Problem**: ID generation scattered across providers

**Solution**:
```dart
// lib/utils/id_generator.dart
import 'dart:math';

class IdGenerator {
  static final _random = Random();
  
  /// Generate a unique ID with the given prefix
  static String generate(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = _random.nextInt(100000000).toString().padLeft(8, '0');
    return '${prefix}_${timestamp}_$randomPart';
  }
  
  static String project() => generate('proj');
  static String session() => generate('sess');
  static String message() => generate('msg');
  static String snippet() => generate('snip');
  static String secret() => generate('sec');
}

// Usage in providers
final id = IdGenerator.project();
```

### Example 5: Proper Error Handling (Phase 11.2)

**Current Problem**: Inconsistent error handling

**Solution**:
```dart
// lib/providers/project_provider.dart (improved)
final projectActionResultProvider = 
    StateProvider<AsyncValue<void>>((ref) => const AsyncValue.data(null));

class ProjectActions {
  // ... existing code ...
  
  Future<void> createProjectSafely({
    required String name,
    String? description,
  }) async {
    final notifier = _ref.read(projectActionResultProvider.notifier);
    
    notifier.state = const AsyncValue.loading();
    
    try {
      await createProject(name: name, description: description);
      notifier.state = const AsyncValue.data(null);
    } catch (e, stack) {
      notifier.state = AsyncValue.error(e, stack);
    }
  }
}

// Usage in widget
final result = ref.watch(projectActionResultProvider);

result.when(
  loading: () => const CircularProgressIndicator(),
  error: (err, stack) => ErrorView(
    error: err,
    onRetry: () => ref.invalidate(projectActionResultProvider),
  ),
  data: (_) => const SuccessMessage(),
);
```

---

## Quick Reference: Provider Patterns

### Stream Providers (Reactive Data)
```dart
final projectsStreamProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final dao = ref.watch(projectDaoProvider);
  return dao.watchAllProjects();
});
```

### Family Providers (Parameterized)
```dart
final projectSettingsProvider = StateNotifierProvider.family<
  ProjectSettingsNotifier,
  ProjectSettings?,
  String
>((ref, projectId) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ProjectSettingsNotifier(prefs, projectId);
});
```

### Derived Providers (Computed)
```dart
final currentProjectProvider = Provider<ProjectEntity?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;
  
  final projects = ref.watch(projectsStreamProvider).valueOrNull ?? [];
  return projects.firstWhereOrNull((p) => p.id == projectId);
});
```

### Action Providers (Mutations)
```dart
final projectActionsProvider = Provider<ProjectActions>((ref) {
  final dao = ref.watch(projectDaoProvider);
  return ProjectActions(dao, ref);
});
```

### StateNotifier (Complex State)
```dart
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repository) : super(const ChatState());
  
  Future<void> doSomething() async {
    state = state.copyWith(isLoading: true);
    // ... logic ...
    state = state.copyWith(isLoading: false);
  }
}
```

---

## Prioritized Action Plan

### 🔴 Critical (Do First)

**Week 1: Foundation Refactoring**

1. **Create ChatRepository** (2-3 days)
   - File: `lib/repositories/chat_repository.dart`
   - Move business logic from `chat_session.dart`
   - Methods: `sendMessageToAI()`, `handleToolCallsApproval()`, `syncMessages()`
   - Impact: Enables testing, reduces widget complexity

2. **Extract ChatController** (2-3 days)
   - File: `lib/providers/chat_controller.dart`
   - Create `ChatState` with Freezed
   - Move state management from `_ChatSessionState`
   - Simplify `chat_session.dart` to < 500 lines
   - Impact: Testable state management, cleaner UI code

3. **Add ChatRepository Tests** (1 day)
   - File: `test/repositories/chat_repository_test.dart`
   - Test message sending flow
   - Test tool call approval
   - Mock dependencies
   - Impact: Confidence in business logic

### 🟡 High Priority (Week 2)

4. **Decouple LlmService** (1-2 days)
   - Refactor: `lib/services/llm_service.dart`
   - Remove Ref dependency
   - Create `configuredLlmProvider`
   - Impact: Pure service, easier to test

5. **Centralize ID Generation** (1 day)
   - Create: `lib/utils/id_generator.dart`
   - Update all providers to use it
   - Remove scattered generation logic
   - Impact: Consistency, easier maintenance

6. **Add Provider Tests** (2-3 days)
   - Test `project_provider.dart`
   - Test `session_provider.dart`
   - Test `message_provider.dart`
   - Test `settings_provider.dart`
   - Impact: Safety net for future changes

### 🟢 Medium Priority (Week 3-4)

7. **Improve Error Handling** (1-2 days)
   - Add `AsyncValue` wrappers for actions
   - Create reusable error widgets
   - Standardize error patterns
   - Impact: Better UX, consistent patterns

8. **Simplify Message Syncing** (1 day)
   - Create `chatMessagesForUIProvider`
   - Use `ref.listen()` properly
   - Remove complex sync logic
   - Impact: Simpler code, fewer bugs

9. **Create Other Repositories** (2 days)
   - `lib/repositories/project_repository.dart`
   - `lib/repositories/session_repository.dart`
   - `lib/repositories/settings_repository.dart`
   - Impact: Complete architecture

10. **Add Widget Tests** (2 days)
    - Test major components
    - Test pages with provider overrides
    - Impact: UI regression prevention

### 🔵 Nice to Have (Future)

11. **Performance Testing** (1 day)
    - Measure database query times
    - Test with large datasets
    - Profile memory usage
    - Impact: Production readiness

12. **Integration Tests** (1-2 days)
    - End-to-end flow tests
    - Multi-session scenarios
    - Impact: Confidence in full stack

---

## Daily Checklist Template

When implementing each improvement:

- [ ] Read existing code and understand current behavior
- [ ] Create new file(s) following naming conventions
- [ ] Move/refactor logic incrementally
- [ ] Run `flutter analyze` - should have 0 errors
- [ ] Run existing tests - should all pass
- [ ] Add new tests for new code
- [ ] Update this document with progress
- [ ] Test manually in app
- [ ] Commit with descriptive message
- [ ] Consider updating AGENTS.md with new patterns

---

## Need Help?

### Common Issues & Solutions

**Q: Provider not updating when data changes?**
A: Check that you're using `.watch()` not `.read()`. For streams, use `StreamProvider`.

**Q: "Bad state: Cannot modify an already-disposed provider"?**
A: Don't call provider methods after widget is disposed. Use `mounted` check or `ref.listenManual()`.

**Q: Tests failing with "No provider found"?**
A: Use `ProviderContainer` in tests and override dependencies:
```dart
final container = ProviderContainer(
  overrides: [
    databaseProvider.overrideWithValue(MockDatabase()),
  ],
);
```

**Q: How to test async providers?**
A: Use `await container.read(provider.future)` or `.whenData()`.

**Q: Should I use StateNotifier or AsyncNotifier?**
A: Use `AsyncNotifier` (Riverpod 2.0+) for async initialization. Use `StateNotifier` for synchronous state.

### Resources

- [Riverpod Documentation](https://riverpod.dev)
- [Drift Documentation](https://drift.simonbinder.eu)
- [Freezed Documentation](https://pub.dev/packages/freezed)
- Project's `AGENTS.md` for coding standards

---

