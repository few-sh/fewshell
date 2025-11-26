# Client-Server Architecture Plan (Simplified)

## Executive Summary

Enable remote execution for Decamp with minimal complexity. Keep local sessions using existing code. Add WebSocket server for remote sessions. The agent loop is just 8 lines - everything else is plumbing.

**Key principle:** Build the dumbest thing that works. No premature abstraction.

---

## 1. Core Architecture

### 1.1 Package Boundaries (Quake-Style)

Three packages with clear responsibilities:

**`agent-core`** (shared library - used by both client and server):
- Agent loop (`runAgentLoop()`)
- Tool definitions (`shellTools`)
- Tool execution services (`ShellExecutor`, `FetchExecutor`)
- Message converters (`ChatMessage` ↔ JSON)
- **Models:** `ProjectSettings`, `LlmSettings`, `SshSettings`, `Session`, `Message`, `Snippet`, `Secret`
- **Storage interfaces:** `SessionStore`, `ProjectDataStore`
- **Storage implementations:** `SqliteSessionStore` (works on all platforms)
- **Controllers:** `SessionController` (interface), `LocalSessionController` (local implementation)
- **Utilities:** `IdGenerator`

**`decamp-agent`** (server - thin WebSocket transport):
- WebSocket transport layer (routes commands to agent-core)
- **TOML settings store** (reads/writes `~/.decamp/projects/{id}/`)
- Server startup/config (port, binding)
- Uses `SqliteSessionStore` from agent-core (no duplication!)
- Imports and uses `agent-core` for all business logic

**`decamp-app`** (Flutter client):
- UI components and Flutter-specific code
- For local projects: uses `LocalSessionController` from agent-core directly
- For remote projects: uses `RemoteSessionController` (WebSocket to server)
- **Both use same `SessionController` interface** - UI doesn't know/care
- Riverpod providers, navigation, themes
- `sqlite3_flutter_libs` for native SQLite support

**Key insight (Quake model):**
- Same code runs "single-player" (local) and "multiplayer" (remote)
- Only the transport differs
- Zero code duplication between client and server
- No Drift needed - manual `StreamController` for reactive updates

**Settings flow:**

```
Local Project:
  UI ←→ SessionController ←→ LocalSessionController ←→ SqliteSessionStore ←→ SQLite

Remote Project:
  UI ←→ SessionController ←→ RemoteSessionController ←→ WebSocket ←→ Server ←→ SqliteSessionStore
```

**Why this split (Quake model)?**
- Same code paths for local and remote - only transport differs
- Single `SqliteSessionStore` implementation works everywhere
- No Drift code generation needed
- Reactive streams via `StreamController` (fires on write)
- Testing: mock `SessionController` interface, test once

### 1.2 The 8-Line Agent Loop

```dart
// This is all the "agent loop" actually is:
while (true) {
  response = await llm.complete(conversation, tools);
  if (!response.hasToolCalls) break;
  
  approved = await approvals.request(response.toolCalls);
  if (!approved) break;
  
  results = await executor.execute(approved);
  conversation.add(response);
  conversation.add(results);
}
```

Everything else (DB, UI, streaming) is plumbing outside the loop.

### 1.3 Project-Level Execution Location

Each project has a `serverUrl` field:
- `null` = local project (all sessions run locally)
- `"https://server.com"` = remote project (all sessions run on server)

**Why project-level?** A project represents an infrastructure environment (prod servers, staging, dev machines). All sessions in that project should:
- Use the same execution location
- Share the same settings (SSH config, secrets, AGENTS.md)
- Enable team collaboration (everyone sees the same remote project)

**Simpler UX:** One decision per project, not per session. User creates "Production" project (remote) or "Local Testing" project (local).

### 1.4 Data Storage

**Local projects:**
- Source of truth: SQLite on device (current Drift database)
- All settings, secrets, sessions in local DB + keychain
- Works offline completely
- Private to this device

**Remote projects:**
- Source of truth: SQLite on server (same schema as client)
- Server stores: projects, settings, secrets, sessions, messages
- Client has simple cache (JSON file or single-table SQLite)
- Cache is disposable - can refill from server anytime
- Offline: read-only access to cached data
- Online required for: new messages, edits, deletions, settings changes

---

## 2. Communication Protocol

### 2.1 Simple Messages (No Envelopes)

**Client → Server:**

```json
// Start agent loop
{"cmd": "run", "sid": "session_123"}

// Approve tools
{"cmd": "approve", "tools": [1, 2, 3]}

// Settings
{"cmd": "get_settings"}
{"cmd": "set_settings", "settings": {...}}

// Snippets
{"cmd": "get_snippets"}
{"cmd": "set_snippet", "snippet": {"id": "...", "name": "...", "content": "..."}}
{"cmd": "delete_snippet", "id": "..."}

// Secrets (value sent to server, never returned)
{"cmd": "get_secrets"}
{"cmd": "set_secret", "id": "...", "name": "...", "value": "..."}
{"cmd": "delete_secret", "id": "..."}
```

**Server → Client:**

```json
// AI text streaming
{"t": "delta", "d": "Here is the status..."}

// Tool approval needed
{"t": "approval", "tools": [
  {"id": 1, "name": "execute_shell", "params": {"cmd": "ls"}}
]}

// Message complete
{"t": "done"}

// Settings (response or broadcast)
{"t": "settings", "settings": {...}}

// Snippets (response or broadcast)
{"t": "snippets", "snippets": [...]}
{"t": "snippet_deleted", "id": "..."}

// Secrets metadata only (never includes values)
{"t": "secrets", "secrets": [
  {"id": "abc", "name": "OPENAI_API_KEY"},
  {"id": "def", "name": "SSH_PASSWORD"}
]}
{"t": "secret_deleted", "id": "..."}

// Error
{"t": "error", "msg": "LLM timeout"}
```

**Real-time sync via WebSocket:**
- Client sends `get_*` on connect → server responds with current state
- Client sends `set_*` / `delete_*` → server saves and broadcasts to all connected clients
- All clients see changes immediately, no conflict dialogs needed
- Last write wins, but everyone sees it
- **Secrets:** Values are write-only (sent to server, never returned)

**That's it.** No versioning, no timestamps, no connection IDs, no nested payloads. Just the data you need.

### 2.2 Connection Metadata (For Logging Only)

Version number passed on connect for debugging:

```dart
ws.connect('$url?v=$APP_VERSION&sid=$sessionId');
```

Server logs it but doesn't make decisions based on it. When you have your first breaking change, then add compatibility logic.

### 2.3 WebSocket Strategy

**Start simple:** One WebSocket = One Active Session

```dart
class SessionConnection {
  WebSocket? _ws;
  
  Future<void> switchTo(String sessionId) async {
    await _ws?.close();
    _ws = await WebSocket.connect('$url?sid=$sessionId');
  }
}
```

**Later, if needed:** Add subscribe/unsubscribe for multiple sessions. But don't build it until users complain about switching delay.

---

## 3. Storage Strategy

### 3.1 Project Metadata

Add `serverUrl` to Projects table:

```dart
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  
  // NEW: Where do ALL sessions in this project run?
  TextColumn get serverUrl => text().nullable()();
  // null = local project, URL = remote project
  
  // ... other fields (createdAt, updatedAt, lastSessionDate)
}
```

**All sessions in a project share the same execution location.**

### 3.2 Local Projects

**Storage:** Existing Drift database on device

**Execution:** Direct function calls (no WebSocket)

```dart
// Just call the agent loop directly
await runAgentLoop(
  conversation: messages,
  llm: llmClient,
  tools: shellTools,
  requestApproval: (tools) => showApprovalDialog(tools),
  executeToolCall: (tc) => shellService.execute(tc),
  onTextDelta: (text) => setState(() => streamingText += text),
  onMessageComplete: (msg) => saveToDatabase(msg),
);
```

**Settings:** All in local database + device keychain

**Offline:** Everything works (source of truth is on device)

### 3.3 Remote Projects

**Server storage:** SQLite database on server (same schema as client)
- Projects, sessions, messages tables
- Project settings (SSH config, AGENTS.md, snippets)
- Secrets (with location metadata)

**Client cache:** For offline read-only access

**Cache implementation:** Single-table SQLite (disposable, no migrations)

```dart
// Simple cache database - separate from main app DB
class RemoteProjectCache {
  Database? _db;
  
  Future<void> init() async {
    _db = await openDatabase('remote_cache.db', version: 1,
      onCreate: (db, version) {
        // Simple key-value store
        db.execute('''
          CREATE TABLE cache(
            session_id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        db.execute('CREATE INDEX idx_project ON cache(project_id)');
      },
    );
  }
  
  Future<void> cacheSession(String sessionId, String projectId, Map data) async {
    await _db!.insert('cache', {
      'session_id': sessionId,
      'project_id': projectId,
      'data': jsonEncode(data),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<Map?> getSession(String sessionId) async {
    final result = await _db!.query('cache', 
      where: 'session_id = ?', 
      whereArgs: [sessionId]);
    if (result.isEmpty) return null;
    return jsonDecode(result.first['data'] as String);
  }
  
  Future<void> clearProject(String projectId) async {
    await _db!.delete('cache', where: 'project_id = ?', whereArgs: [projectId]);
  }
}
```

**Why SQLite for cache:**
- Already using SQLite (no new dependency)
- Atomic writes (crash-safe)
- Efficient incremental updates (no re-serializing everything)
- Easy queries (get sessions by project, prune old data)
- Simple: one table, no migrations, disposable

**Settings sync:** Fetch on project open, push on change

**Offline behavior:**
- **Reads:** Show cached data with "Offline" banner
- **Writes:** Error message "Reconnect to send messages"
- **Settings changes:** Error message "Reconnect to save settings"
- **On reconnect:** Sync settings from server, refresh cache

### 3.4 Secret Storage

Secrets can be stored on device OR server (user choice per-secret):

```dart
enum SecretLocation {
  device,  // Stored on device keychain only
  server,  // Stored on server only
}
```

**Device secrets:**
- Never leave device
- For remote projects: client sends value when server needs it (ephemeral)
- More private, user controls access

**Server secrets:**
- Never sync to device
- Server uses directly
- Shared with team
- Required for team collaboration

**Default:** Device storage (more private). User explicitly chooses server for shared credentials.

---

## 4. Implementation

### 4.1 The Agent Loop (8 Lines)

Extract from `ChatController.sendMessage()`:

```dart
// This is the entire agent loop
while (true) {
  response = await llm.complete(conversation, tools);
  if (!response.hasToolCalls) break;
  
  approved = await approvals.request(response.toolCalls);
  if (!approved) break;
  
  results = await executor.execute(approved);
  conversation.add(response);
  conversation.add(results);
}
```

Everything else (DB, UI, streaming, approval dialogs) is plumbing around this loop.

### 4.2 Server (Minimal)

```dart
// bin/server.dart
void main() async {
  final db = await openDatabase('decamp.db');
  serve(createRouter(db), 'localhost', 3123);
}

// lib/session_handler.dart
Future<void> handleSession(WebSocket ws, String sid, Database db) async {
  final messages = await db.getMessages(sid);
  final conversation = buildConversation(messages);
  
  ws.stream.listen((data) async {
    final msg = jsonDecode(data);
    
    if (msg['cmd'] == 'run') {
      await runAgentLoop(
        conversation: conversation,
        llm: createLlmClient(),
        tools: shellTools,
        requestApproval: (tools) async {
          ws.sink.add(jsonEncode({'t': 'approval', 'tools': tools}));
          final resp = await ws.stream.first;
          return jsonDecode(resp)['tools'];
        },
        executeToolCall: (tc) => executeShell(tc),
        onTextDelta: (d) => ws.sink.add(jsonEncode({'t': 'delta', 'd': d})),
        onMessageComplete: (msg) async {
          await db.insertMessage(sid, msg);
          ws.sink.add(jsonEncode({'t': 'done'}));
        },
      );
    }
  });
}
```

**~80 lines total.**

### 4.3 Client (Project-Based SessionStore)

```dart
// Single interface, two implementations
abstract class SessionStore {
  Future<void> sendMessage(String sessionId, String content);
  Stream<ChatState> watchSession(String sessionId);
}

// Factory picks implementation based on project
Provider.family<SessionStore, String>((ref, sessionId) {
  final session = ref.watch(sessionProvider(sessionId));
  final project = ref.watch(projectProvider(session.projectId));
  
  if (project.serverUrl == null) {
    // Local project - use existing ChatController
    return LocalSessionStore(
      ref.watch(chatControllerProvider.notifier),
    );
  } else {
    // Remote project - use WebSocket
    return RemoteSessionStore(
      serverUrl: project.serverUrl!,
      projectId: project.id,
    );
  }
});

// Local: use existing ChatController (unchanged)
class LocalSessionStore implements SessionStore {
  final ChatController _controller;
  
  Future<void> sendMessage(String sessionId, String content) async {
    // Just call existing code
    await _controller.sendMessage(
      content: content,
      sessionId: sessionId,
      requestApproval: showApprovalDialog,
    );
  }
}

// Remote: WebSocket communication
class RemoteSessionStore implements SessionStore {
  final String serverUrl;
  final String projectId;
  WebSocket? _ws;
  
  Future<void> sendMessage(String sessionId, String content) async {
    if (_ws == null) {
      _ws = await WebSocket.connect('$serverUrl?sid=$sessionId&pid=$projectId');
      _listenForEvents();
    }
    _ws!.send(jsonEncode({'cmd': 'run', 'content': content}));
  }
  
  void _listenForEvents() {
    _ws!.listen((data) {
      final event = jsonDecode(data);
      switch (event['t']) {
        case 'delta': _onTextDelta(event['d']);
        case 'approval': _onApprovalRequest(event['tools']);
        case 'done': _onMessageComplete();
        case 'error': _onError(event['msg']);
        case 'secret_request': _provideSecret(event['id']);
      }
    });
  }
  
  Future<void> _provideSecret(String secretId) async {
    // Get from device keychain
    final value = await deviceKeychain.get(projectId, secretId);
    if (value != null) {
      // Send ephemeral to server
      _ws!.send(jsonEncode({'cmd': 'provide_secret', 'id': secretId, 'value': value}));
    }
  }
}
```

**UI code doesn't change** - it uses `SessionStore` interface. Project determines local vs remote.

---

## 5. Migration Path

### Phase 1: Extract Agent Loop ✅

- Create `agent-core` package
- Extract loop to `runAgentLoop()` function
- `ChatController` now calls `runAgentLoop()`
- Move tool definitions, message converters, services to shared package
- **Test:** App works identically ✅

### Phase 2: Basic Server ✅

- Implement WebSocket handler
- Wire up `runAgentLoop()` with WebSocket callbacks
- Server uses `FetchExecutor` from agent-core
- **Test:** Manual with `curl` health check ✅

### Phase 3: Client WebSocket ✅

- Add `serverUrl` to Projects table (Drift migration) ✅
- Implement `RemoteSessionController` (WebSocket client) ✅
- Factory checks `project.serverUrl`: null → local, URL → remote ✅
- UI to configure server URL per project ✅
- **Test:** WebSocket connects to server ✅

### Phase 3.5: Server Data Storage ✅

Server needs to store project data (settings, snippets, secrets) to run agent loops.

**Implemented:**

**Models in agent-core:**
- `ProjectSettings` (aggregate)
- `LlmSettings` (provider, model, apiKey, baseUrl)
- `SshSettings` (host, port, username, authMethod, credentials)
- `Snippet` (id, name, content, description, tags, position, timestamps)
- `SecretMetadata` (id, name - values never returned)
- All have JSON serialization

**Server storage (decamp-agent):**
- `TomlProjectDataStore` - stores in `~/.decamp/projects/{projectId}/`
  - `settings.toml` - LLM, SSH, system prompt
  - `snippets.toml` - All project snippets  
  - `secrets/{id}.toml` - Each secret separately
- `ConnectionManager` - tracks WebSocket connections per project for broadcast

**Session handler commands:**
- `get_settings`, `set_settings` 
- `get_snippets`, `set_snippet`, `delete_snippet`
- `get_secrets`, `set_secret`, `delete_secret`
- Changes broadcast to all clients connected to same project

**Client integration (decamp-app):**
- `RemoteSessionController` - WebSocket client with all data methods
- `remote_data_provider.dart` - Riverpod providers for remote data
- `ChatController` passes `projectId` to `RemoteSessionController`
- Conversion utilities between `Snippet` (agent-core) and `SnippetEntity` (local DB)

**Still TODO:**
- Wire up settings/snippets/secrets UI to detect remote and use appropriate source
- End-to-end test: Configure LLM, add snippet, add secret, run agent loop, verify multi-client sync

### Phase 4: Quake-Style Architecture ✅

**Problem:** We were heading toward code duplication between client (Drift) and server (SQLite).

**Solution:** Adopt Quake-style architecture where local and remote use the same code, with only the transport differing:

```
┌─────────────────────────────────────────────────────────────┐
│                        decamp-app                           │
│  ┌─────────────────┐                                        │
│  │       UI        │                                        │
│  └────────┬────────┘                                        │
│           │                                                 │
│  ┌────────▼────────┐                                        │
│  │SessionController│ ◄── unified interface                  │
│  └────────┬────────┘                                        │
│           │                                                 │
│     ┌─────┴─────┐                                           │
│     ▼           ▼                                           │
│ ┌───────┐  ┌─────────┐                                      │
│ │Local  │  │Remote   │                                      │
│ │Ctrl   │  │Ctrl     │──────► WebSocket to decamp-agent     │
│ └───┬───┘  └─────────┘                                      │
│     │                                                       │
│     ▼                                                       │
│ ┌─────────────────┐                                         │
│ │  agent-core     │ ◄── Same code as decamp-agent uses      │
│ │  SessionStore   │                                         │
│ │  AgentLoop      │                                         │
│ └─────────────────┘                                         │
└─────────────────────────────────────────────────────────────┘
```

**Implemented (agent-core):**
- `SessionController` - Abstract interface for session management
- `LocalSessionController` - Local "single-player" mode implementation
- `SessionStore` - Abstract interface for session/message storage
- `SqliteSessionStore` - Shared SQLite implementation (works on all platforms)
- `Session` and `Message` models with JSON serialization
- `IdGenerator` - Centralized ID generation with prefixes

**Implemented (decamp-agent):**
- Server now uses `SqliteSessionStore` from agent-core (no duplication)
- Session management commands: `get_sessions`, `create_session`, `update_session`, `delete_session`, `get_messages`
- Server persists all messages to SQLite (server is source of truth)

**Key insight:** No Drift needed! `StreamController` fires on writes for reactive updates. Same pattern works for both local (direct) and remote (WebSocket push).

### Phase 5: Client Integration ✅

Wire up decamp-app to use the new architecture:

**5.1 Add sqlite3 to Flutter app:** ✅
```yaml
# pubspec.yaml - already had sqlite3_flutter_libs
dependencies:
  sqlite3: ^2.4.0
  sqlite3_flutter_libs: ^0.5.0  # Native SQLite for iOS/Android/macOS
```

**5.2 Create LocalSessionController instance:** ✅
```dart
// For local projects, use agent-core directly
final controller = LocalSessionController(
  projectId: project.id,
  store: SqliteSessionStore.open(localDbPath),
  createLlmClient: () => llmService.createClient(),
  executeToolCall: (tc) => shellExecutor.execute(tc),
);
```

**5.3 Create RemoteSessionController:** ✅
Implemented `SessionController` interface with WebSocket transport in agent-core:
- `watchSessions()` → Subscribe to server, fire stream on push
- `watchMessages()` → Subscribe to server, fire stream on push  
- `sendMessage()` → Send via WebSocket, handle streaming response
- `continueConversation()` → Resume agent loop without adding user message (for edit/resend)
- `getMessage()`, `updateMessageContent()`, `deleteMessagesAfter()` → Message editing support
- Handle `delta`, `approval`, `message`, `done`, `message_result`, `messages_deleted` events

**5.4 Create SessionController provider:** ✅
Created `session_controller_provider.dart` in decamp-app:
- `sessionControllerProvider` - Returns `LocalSessionController` or `RemoteSessionController` based on project's `serverUrl`
- `controllerSessionsProvider` - Watch sessions via controller
- `controllerArchivedSessionsProvider` - Watch archived sessions  
- `controllerMessagesProvider` - Watch messages via controller
- Added `createClient()` method to `LlmService` for agent-core integration

**5.5 Simplify ChatController to use SessionController:** ✅
Refactored `ChatController` from 817 lines to ~280 lines:
- Removed all legacy fields (`_messageDao`, `_sessionDao`, `_llmService`, `_shellService`, etc.)
- Single constructor requiring only `SessionController`
- `sendMessage()` delegates to `SessionController.sendMessage()`
- `editMessage()` and `resendMessage()` use `SessionController.continueConversation()`
- ChatController is now a thin UI state layer (loading, streaming text, errors)
- Same code path works for both local and remote projects

**5.6 Settings/Snippets/Secrets:** ✅
- `RemoteAgentClient` handles settings/snippets/secrets sync for remote projects
- Local projects use existing database/keychain
- `ProjectLlmSettingsNotifier` detects remote and uses appropriate source

**5.7 Server command handlers:** ✅
Added all message editing commands to decamp-agent:
- `get_message`, `update_message`, `delete_messages_after`
- `continue` - Resume agent loop (for edit/resend operations)

### Phase 5.8: Remove Legacy Code ✅

Now that SessionController handles both local and remote uniformly, legacy compatibility layers have been removed:

**Deleted files:**
- ✅ `lib/extensions/chat_message_extensions.dart` - Not used anywhere
- ✅ `lib/services/shell_tools_provider.dart` - Re-export shim, now imports from agent_core
- ✅ `lib/extensions/` directory - Empty, removed

**Legacy getters removed:**
- ✅ `ToolAction.command` and `ToolAction.isSudoRequired` in `multi_command_approval_overlay.dart`

**Providers migrated to SessionController:**
- ✅ `lib/providers/message_provider.dart` - Now uses SessionController for both local and remote
- ✅ `lib/providers/session_provider.dart` - Now uses SessionController for both local and remote

**Pages migrated to use SessionController:**
- ✅ `lib/pages/chat_session.dart` - Uses SessionController instead of direct DAO
- ✅ `lib/pages/sessions_history.dart` - Uses SessionController instead of direct DAO

**Future cleanup (Phase 9: Drift Removal):**
- Remove Drift dependency entirely
- Delete `lib/database/` folder (DAOs, migrations, database.dart)
- Simpler build (no code generation)

### Phase 6: Cache & Offline (TODO)

- Simple SQLite cache for offline viewing
- Cache messages on receive
- Show cached data with "Offline" banner when disconnected
- **Test:** View cached sessions offline

### Phase 7: Polish (TODO)

- Reconnection (exponential backoff)
- Error messages
- Connection status UI
- Deployment guide

### Phase 8: SSH Tunnel Mode (Future)

Alternative connection method for power users who don't want a public server.

**How it works:**
```
┌─────────────────┐     SSH Tunnel      ┌─────────────────────────────────┐
│  Decamp App     │◄──────────────────►│  Remote Server                  │
│  (Flutter)      │    (encrypted)      │                                 │
│                 │                     │  decamp-agent (TCP localhost)   │
│  SSH Client     │────────────────────►│  or Unix socket + socat         │
│  (dartssh2)     │   Port forwarding   │                                 │
└─────────────────┘                     └─────────────────────────────────┘
```

**Benefits:**
- ✅ No public endpoint needed - works behind NAT/firewall
- ✅ Uses existing SSH keys for auth
- ✅ Familiar model (like VS Code Remote)
- ✅ We already have SSH client (`dartssh2`)

**Requirements:**
- Agent bootstrap script (upload/run binary on remote)
- SSH port forwarding (`directTcpIp` or `StreamLocal`)
- Agent binary distribution (linux-x64, linux-arm64)
- Process management on remote

**Per-project connection method:**
```dart
enum ConnectionMethod { local, websocket, sshTunnel }

// In Projects table:
// - connectionMethod: ConnectionMethod
// - serverUrl: String? (for websocket)
// - sshHost/sshUser: String? (for sshTunnel - reuse SSH settings?)
```

**Deferred because:**
- WebSocket is simpler to implement first
- iOS SSH support is limited
- Binary distribution adds complexity
- Can reuse SSH settings we already have for shell execution

---

## 6. What We're NOT Building

**Don't build until proven necessary:**

- ❌ Protocol versioning (add on first breaking change)
- ❌ Subscribe/unsubscribe (one session = one WS is fine)
- ❌ Multi-user features (single-user first)
- ❌ Offline writes (read-only offline is enough)
- ❌ Real-time badges (fetch on app open)
- ❌ E2EE (later)
- ❌ Isolates (direct calls simpler)
- ❌ Message envelopes (flat JSON works)
- ❌ Cache migrations (disposable cache, just delete/rebuild)
- ❌ Secret sync (device OR server, not both)

Build the simplest thing. Add complexity only when users complain.

---

## 7. Key Decisions

### Project-Level Execution

Project has `serverUrl` field. All sessions in project run in same location. Simpler UX - one decision per project. Projects represent infrastructure environments that naturally belong together.

### No Isolates for Local

Direct function calls are simpler. Isolates add complexity without benefit (can't run in background on mobile anyway).

### Simple Protocol

Flat JSON messages. No envelopes, no versioning (yet). Add when first breaking change happens.

### Secret Storage Choice

User chooses per-secret: device OR server. Device = more private. Server = shared with team. No syncing between them - clear ownership.

### Disposable Cache

For remote sessions, cache is just for offline viewing. Server is source of truth. Cache corrupts? Delete and re-fetch.

### Optimistic Features

Try new features, handle errors gracefully. Don't block on version checks. "Cancel not supported - update server" is fine UX.

### No Subscribe/Unsubscribe

One active session = one WebSocket. Close old connection when switching sessions. Simple.

---

## Success Criteria

**Must have:**
- ✅ Send message → get AI response (local and remote)
- ✅ Tool approval flow works
- ✅ Edit message and resend from that point
- ✅ Settings/snippets/secrets sync for remote projects
- ⏳ Offline viewing of cached sessions (Phase 6)
- ⏳ Reconnection recovers cleanly (Phase 7)

**Nice to have (later):**
- Branch session (create copy of conversation at a point)
- Team collaboration (shared remote sessions)
- Real-time badges
- Streaming tool output
- Multi-person approvals

---

## Current Architecture (Post-Refactor)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           decamp-app                                     │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                           UI Layer                                │   │
│  │  ChatSession, ProjectSettings, SnippetsPage, SecretsPage, etc.   │   │
│  └──────────────────────────────────┬───────────────────────────────┘   │
│                                     │                                    │
│  ┌──────────────────────────────────▼───────────────────────────────┐   │
│  │                      ChatController                               │   │
│  │  - Thin UI state layer (~280 lines)                              │   │
│  │  - Manages: isLoading, streamingText, error                      │   │
│  │  - Delegates all execution to SessionController                   │   │
│  └──────────────────────────────────┬───────────────────────────────┘   │
│                                     │                                    │
│  ┌──────────────────────────────────▼───────────────────────────────┐   │
│  │              sessionControllerProvider                            │   │
│  │  Returns LocalSessionController or RemoteSessionController        │   │
│  │  based on project.serverUrl (null = local, URL = remote)         │   │
│  └───────────┬─────────────────────────────────────┬────────────────┘   │
│              │                                     │                     │
│       Local Project                          Remote Project              │
│              │                                     │                     │
│  ┌───────────▼───────────┐           ┌─────────────▼─────────────┐     │
│  │ LocalSessionController │           │ RemoteSessionController   │     │
│  │ (agent-core)           │           │ (agent-core → WebSocket)  │     │
│  └───────────┬───────────┘           └─────────────┬─────────────┘     │
│              │                                     │                     │
│  ┌───────────▼───────────┐                         │                     │
│  │  SqliteSessionStore   │                         │                     │
│  │  (agent-core)         │                         │                     │
│  └───────────────────────┘                         │                     │
│                                                    │                     │
│  ┌─────────────────────────────────────────────────┼─────────────────┐  │
│  │                   RemoteAgentClient             │                  │  │
│  │  - Settings/Snippets/Secrets sync ◄────────────┘                  │  │
│  │  - Separate from SessionController (different concerns)           │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘

                                    │
                                    │ WebSocket
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          decamp-agent                                    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                     SessionHandler                               │    │
│  │  Commands: run, continue, approve, cancel                        │    │
│  │  Commands: get/create/update/delete_session                     │    │
│  │  Commands: get_messages, get_message, update_message,           │    │
│  │            delete_messages_after                                 │    │
│  │  Commands: get/set_settings, get/set/delete_snippet/secret      │    │
│  └──────────────────────────────┬──────────────────────────────────┘    │
│                                 │                                        │
│  ┌──────────────────────────────▼──────────────────────────────────┐    │
│  │                    agent-core                                    │    │
│  │  - runAgentLoop() - The 8-line agent loop                       │    │
│  │  - SqliteSessionStore - Same implementation as client           │    │
│  │  - ShellExecutor, FetchExecutor - Tool execution                │    │
│  │  - Models: Session, Message, ProjectSettings, etc.              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                  TomlProjectDataStore                            │    │
│  │  Stores settings/snippets/secrets in ~/.decamp/projects/{id}/   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key insight (Quake model):** Same `SessionController` interface for both local and remote. UI doesn't know which transport is being used. Only ~280 lines of UI state management in ChatController - everything else is delegated to the unified interface.

---

## Conclusion

**Build for today's problems, not tomorrow's.**

The core value is: "I can run agent loops remotely and share sessions with my team."

Everything else is optimization. Start with ~200 lines of code (8-line agent loop + minimal server + WebSocket client). Ship it. Then iterate based on real usage.

The plan had 1000+ lines describing protocols, transports, envelopes, versioning, caching strategies... **You don't need any of that yet.**

Extract the loop. Wire up WebSocket. Done.
