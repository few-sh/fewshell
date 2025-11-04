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

### Phase 3: Database Layer (Drift) ✓ TODO
**Goal**: Setup SQLite database with Drift

#### Tasks:
- [ ] Create `database/tables/projects_table.dart`
  - Define table schema
  - Indexes for common queries

- [ ] Create `database/tables/sessions_table.dart`
  - Define table with projectId foreign key
  - Index on projectId + timestamp

- [ ] Create `database/tables/messages_table.dart`
  - Define table with sessionId foreign key
  - Index on sessionId + createdAt

- [ ] Create `database/tables/snippets_table.dart`
  - Define table with projectId foreign key

- [ ] Create `database/database.dart`
  - Main database class
  - Define all tables
  - Migration logic
  - Database version management

- [ ] Create DAOs
  - `database/daos/project_dao.dart` - CRUD + watch streams
  - `database/daos/session_dao.dart` - CRUD + watch streams
  - `database/daos/message_dao.dart` - CRUD + watch streams

- [ ] Run code generation for Drift
  - Generate database code

- [ ] Write database initialization logic
  - Handle first-time setup
  - Seed with sample data for development

#### Success Criteria:
- Database creates successfully
- All DAOs compile
- Watch streams return data
- Can insert/query/update/delete

---

### Phase 4: Services Layer ✓ TODO
**Goal**: External service integrations

#### Tasks:
- [ ] Create `services/keychain_service.dart`
  - Wrapper for `flutter_secure_storage`
  - Methods: saveSecret, getSecret, deleteSecret, listSecrets
  - Handle iOS Keychain / Android Keystore

- [ ] Create `services/sync_service.dart` (stub for future)
  - Interface for real-time sync
  - Placeholder methods

#### Success Criteria:
- Can save/retrieve secrets securely
- Services ready for provider integration

---

### Phase 5: Providers Setup ✓ TODO
**Goal**: Create Riverpod providers for state management

#### Tasks:
- [ ] Create `providers/database_provider.dart`
  - Provide database instance
  - Single source of truth

- [ ] Create `providers/project_provider.dart`
  - `projectsProvider` - Stream all projects
  - `currentProjectIdProvider` - StateProvider for selected project
  - `currentProjectProvider` - Derived provider for current project
  - `projectActionsProvider` - Create/update/delete methods

- [ ] Create `providers/session_provider.dart`
  - `sessionsProvider.family` - Stream sessions per project
  - `currentProjectSessionsProvider` - Sessions for current project
  - `currentSessionIdProvider` - StateProvider for selected session
  - `sessionActionsProvider` - CRUD methods

- [ ] Create `providers/message_provider.dart`
  - `messagesProvider.family` - Stream messages per session
  - `currentSessionMessagesProvider` - Messages for current session
  - `messageActionsProvider` - CRUD methods

- [ ] Create `providers/theme_provider.dart`
  - Migrate existing theme logic from main.dart
  - `themeProvider` - StateNotifier for ThemeMode
  - Persist to SharedPreferences

- [ ] Create `providers/settings_provider.dart`
  - `globalSettingsProvider` - Global settings
  - `projectSettingsProvider.family` - Per-project settings
  - `effectiveSettingsProvider` - Merged global + project
  - Settings persistence

- [ ] Create `providers/secret_provider.dart` (future)
  - List secrets metadata from database
  - Actual values from keychain service

#### Success Criteria:
- All providers compile
- Providers accessible via ref.watch()
- State updates propagate correctly

---

### Phase 6: Repository Layer ✓ TODO
**Goal**: Business logic and data coordination

#### Tasks:
- [ ] Create `repositories/project_repository.dart`
  - Coordinate between database and future sync service
  - Business logic for project operations

- [ ] Create `repositories/session_repository.dart`
  - Session management logic
  - Handle session-project relationships

- [ ] Create `repositories/settings_repository.dart`
  - Settings merge logic (global + project overrides)
  - Validation

#### Success Criteria:
- Clean separation of concerns
- Business logic isolated from UI
- Easy to test

---

### Phase 7: Update Main App ✓ TODO
**Goal**: Wrap app with ProviderScope, migrate theme

#### Tasks:
- [ ] Update `main.dart`
  - Add `ProviderScope` wrapper
  - Remove theme state management (move to provider)
  - Initialize database on startup
  - Handle loading state during init

- [ ] Move theme definition
  - Move `neonDarkTheme` to `themes/neon_dark.dart`
  - Import where needed

- [ ] Add error handling
  - Global error boundary for provider errors

#### Success Criteria:
- App starts without errors
- ProviderScope wraps MaterialApp
- Theme loads from provider

---

### Phase 8: Migrate ChatSession Page ✓ TODO
**Goal**: Convert main page to use Riverpod providers

#### Tasks:
- [ ] Update `pages/chat_session.dart`
  - Change from `StatefulWidget` to `ConsumerStatefulWidget`
  - Remove local state (_projects, _sessions, etc.)
  - Replace with `ref.watch()` calls
  - Update callbacks to use provider actions
  - Remove initState data initialization

- [ ] Update drawer
  - Watch current project from provider
  - Use project actions for switching

- [ ] Update app bar
  - Watch loading states
  - Update session history button

- [ ] Update message handling
  - Save messages to database via provider
  - Load from database on session open

#### Success Criteria:
- Page renders without errors
- Can switch projects
- Can view sessions
- Chat messages persist

---

### Phase 9: Migrate Components ✓ TODO
**Goal**: Convert presentational components to ConsumerWidgets

#### Tasks:
- [ ] Update `components/project_list.dart`
  - Change to `ConsumerWidget`
  - Remove callback props (use providers directly)
  - Watch projects from provider
  - Use project actions for delete/create

- [ ] Update `components/session_list.dart`
  - Change to `ConsumerWidget`
  - Watch sessions from provider
  - Use session actions

- [ ] Create new components as needed
  - Message bubble component
  - Loading states
  - Error states

#### Success Criteria:
- All components are ConsumerWidgets
- No prop drilling
- Actions call providers directly

---

### Phase 10: Testing & Refinement ✓ TODO
**Goal**: Ensure everything works, add tests

#### Tasks:
- [ ] Manual testing
  - Create/read/update/delete projects
  - Create/read/update/delete sessions
  - Send/receive messages
  - Switch projects and verify session isolation
  - Theme persistence
  - App restart - verify data persists

- [ ] Handle edge cases
  - Empty states
  - Loading states
  - Error states
  - Slow database operations

- [ ] Add unit tests
  - Provider tests
  - Repository tests
  - Model tests

- [ ] Add widget tests
  - Component tests
  - Page tests

- [ ] Performance testing
  - Large number of projects/sessions
  - Message history pagination

#### Success Criteria:
- All CRUD operations work
- Data persists across restarts
- No memory leaks
- Smooth UI performance

---

### Phase 11: Future Enhancements (Not Immediate)
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
- [ ] Zero setState() calls in widgets
- [ ] All data persists across app restarts
- [ ] < 100ms for common database operations
- [ ] Zero memory leaks
- [ ] 80%+ test coverage for providers/repositories

### User Experience
- [ ] Instant UI updates on state changes
- [ ] Smooth animations (60fps)
- [ ] Data loads within 1 second
- [ ] No data loss

### Code Quality
- [ ] All models immutable (Freezed)
- [ ] Type-safe database queries (Drift)
- [ ] Clear separation of concerns
- [ ] Easy to add new features

---

## Timeline Estimate

- **Phase 1-2**: 1-2 days (setup + models)
- **Phase 3-4**: 2-3 days (database + services)
- **Phase 5-6**: 2-3 days (providers + repositories)
- **Phase 7-9**: 3-4 days (UI migration)
- **Phase 10**: 2-3 days (testing)

**Total**: ~2 weeks for full migration

**Recommendation**: Can go live with basic functionality after Phase 9, iterate on testing and refinements.
