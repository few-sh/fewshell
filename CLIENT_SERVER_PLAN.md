# Client-Server Architecture Plan

## Executive Summary

Transform Decamp to a **unified client-server architecture** where the agent loop always runs on a server. For "local" execution, the server runs on `localhost:3123`. For "remote" execution, it runs on a remote host. The client is always a thin UI layer that communicates via WebSocket. This eliminates dual code paths and complexity.

---

## 1. Core Architecture Principle

**One execution model, variable server location:**

```
┌─────────────┐
│ Client (UI) │  ← Always thin, always same code
└──────┬──────┘
       │ Transport (Isolate or WebSocket)
       ▼
┌─────────────┐
│ Agent Loop  │  ← In isolate OR on remote server
└─────────────┘
```

### 1.1 Server Responsibilities

- Run the agent loop (message → LLM → tool calls → approval → execution)
- Make LLM API calls
- Execute tools (SSH commands)
- Persist sessions and messages to database
- Stream events to connected clients
- Handle tool approval flow
- **Store project settings** (for remote projects)

### 1.2 Client Responsibilities

- UI rendering only
- Send user commands via transport
- Receive and display streaming deltas
- Show tool approval dialog and send approval
- Cache data locally for offline viewing
- Manage transport connections
- **Sync project settings from server** (for remote projects)

### 1.3 "Local" vs "Remote" - Project Level

**Projects have an execution location, not sessions:**

- **Local Project:** All sessions run in Dart Isolate
  - Settings stored in local database
  - Private to this device
  - Works offline
  
- **Remote Project:** All sessions run on remote server via WebSocket
  - Settings stored on server, synced to client
  - Shared across team members
  - Requires network connection
  - Project can be accessed from multiple devices

**UI:** Project settings screen has "Local" vs "Remote" toggle with server URL field

### 1.4 Transport Abstraction

**Key insight:** Same message protocol, different transport mechanisms

```dart
// Abstract transport layer
abstract class AgentTransport {
  Stream<Map<String, dynamic>> get messageStream;
  void send(Map<String, dynamic> message);
  Future<void> connect();
  Future<void> disconnect();
}

// Isolate transport (local mode - all platforms)
class IsolateTransport implements AgentTransport {
  Isolate? _agentIsolate;
  SendPort? _sendPort;
  // Uses SendPort/ReceivePort for message passing
}

// WebSocket transport (remote mode only)
class WebSocketTransport implements AgentTransport {
  WebSocketChannel? _channel;
  // Uses WebSocket for network communication
}
```

---

## 2. Communication Protocol

### 2.1 Message Protocol (Transport-Agnostic)

**All messages are JSON maps** - same format whether sent via Isolates or WebSocket

**Client → Server (3 types):**

```json
// Send user message (starts agent loop)
{
  "type": "command",
  "sessionId": "session_123",
  "content": "deploy the app to production"
}

// Approve tool execution
{
  "type": "approve",
  "sessionId": "session_123",
  "toolIds": ["tool_1", "tool_2"]
}

// Reject/cancel tool execution  
{
  "type": "reject",
  "sessionId": "session_123"
}
```

**Server → Client (4 types):**

```json
// Streaming text delta
{
  "type": "delta",
  "sessionId": "session_123",
  "messageId": "msg_457",
  "text": "Here is the deployment status..."
}

// Tool approval needed
{
  "type": "approval",
  "sessionId": "session_123",
  "messageId": "msg_457",
  "tools": [
    {
      "id": "tool_1",
      "name": "execute_shell_command",
      "params": {"command": "kubectl apply -f deploy.yaml"}
    }
  ]
}

// Message completed
{
  "type": "done",
  "sessionId": "session_123",
  "messageId": "msg_457"
}

// Error occurred
{
  "type": "error",
  "sessionId": "session_123",
  "message": "LLM API timeout"
}
```

### 2.2 Transport Implementation

**IsolateTransport (Local - All Platforms):**
```dart
class IsolateTransport implements AgentTransport {
  Future<void> connect() async {
    final receivePort = ReceivePort();
    _agentIsolate = await Isolate.spawn(_agentEntry, receivePort.sendPort);
    _sendPort = await receivePort.first;
    
    // Listen for messages from isolate
    receivePort.listen((message) {
      _messageController.add(message);
    });
  }
  
  void send(Map<String, dynamic> message) {
    _sendPort!.send(message);
  }
  
  static void _agentEntry(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    
    final agentLoop = AgentLoop(/* from shared package */);
    receivePort.listen((message) => agentLoop.handleMessage(message));
  }
}
```

**WebSocketTransport (Remote Only):**
```dart
class WebSocketTransport implements AgentTransport {
  Future<void> connect() async {
    _channel = WebSocketChannel.connect(
      Uri.parse('$serverUrl/ws?sessionId=$sessionId')
    );
    _channel!.stream.listen((data) {
      _messageController.add(jsonDecode(data));
    });
  }
  
  void send(Map<String, dynamic> message) {
    _channel!.sink.add(jsonEncode(message));
  }
}
```

### 2.3 Reconnection

**WebSocket only:**
- Client stores last rendered `messageId`
- On disconnect: exponential backoff reconnection (1s, 2s, 4s, 8s, max 30s)
- On reconnect: server streams all deltas since last `messageId`

**Isolate (local):**
- No reconnection needed (in-process)
- If isolate crashes, restart and rebuild state from database

No event sourcing needed - database is the event log.

---

## 3. Data Model

### 3.1 Project Execution Location

**Add to Projects table:**
```dart
class Projects extends Table {
  // Existing fields...
  TextColumn get id => text()();
  TextColumn get name => text()();
  // ...
  
  // NEW: Execution location
  TextColumn get serverUrl => text().nullable()();
  // null = local (isolate), URL = remote (WebSocket)
}
```

### 3.2 Server Database (Source of Truth for Remote Projects)

**Technology:** SQLite (can migrate to PostgreSQL later if needed)

**Tables:**
- `projects` - project metadata and settings
- `sessions` - session metadata (within projects)
- `messages` - conversation history with tool calls/results
- `project_settings` - SSH config, secrets, AGENTS.md, etc.
- `users` - authentication (optional, add when needed)

**Schema matches existing Drift schema** - agent loop code can be shared.

### 3.3 Client Database (Cache for Remote, Storage for Local)

**For local projects:**
- Client database is the only storage
- Projects with `serverUrl = null`

**For remote projects:**
- Client database is cache only
- Sync project settings from server
- Sessions and messages cached from server responses
- Can be cleared and rebuilt from server

### 3.4 Settings Storage

**Local projects:**
- All settings in client database/keychain
- SSH config, secrets, AGENTS.md stored locally

**Remote projects:**
- Settings fetched from server
- Cached locally for offline viewing
- Changes pushed to server
- Server broadcasts changes to all connected clients

---

## 4. Component Architecture

### 4.1 Shared Package: `decamp_agent_core`

**Location:** `/decamp-agent-core/` (new package)

**Purpose:** Share agent loop logic between server and existing client

**Contents:**
- Agent loop implementation (extracted from `ChatController`)
- LLM service integration
- Tool execution framework
- Message models
- Conversation state management

**Benefits:**
- Refactor without breaking existing app
- Server and client use identical agent logic
- Easy to test in isolation
- Gradual migration path

### 4.2 Server Components (`decamp-agent`)

```dart
// Server main - runs the agent loop service
class DecampServer {
  final AgentLoop agentLoop;        // From shared package
  final WebSocketManager wsManager;
  final SessionStore sessionStore;
  
  void start() {
    // Listen on port 3123
    // Handle WebSocket connections
    // Route messages to agent loop
    // Broadcast events to clients
  }
}

// WebSocket connection handler
class WebSocketManager {
  void handleConnection(WebSocketChannel channel, String sessionId) {
    // Parse incoming messages (command/approve/reject)
    // Send to agent loop
    // Stream agent events back to client
  }
}

// Session storage
class SessionStore {
  Future<Session> getSession(String id);
  Future<List<Message>> getMessages(String sessionId);
  Future<void> saveMessage(Message msg);
}
```

### 4.3 Client Components (`decamp-app`)

```dart
// Transport factory - project-based selection
class AgentTransportFactory {
  static AgentTransport create({
    required String projectId,
    required String sessionId,
  }) async {
    // Get project from database
    final project = await projectDao.getProject(projectId);
    
    // Remote project - use WebSocket
    if (project.serverUrl != null) {
      return WebSocketTransport(project.serverUrl!, sessionId);
    }
    
    // Local project - use Isolate
    return IsolateTransport(sessionId);
  }
}

// Thin client controller - just UI logic
class ChatController extends StateNotifier<ChatState> {
  final AgentTransport transport;
  
  void sendMessage(String content) {
    transport.send({"type": "command", "sessionId": sessionId, "content": content});
  }
  
  void handleAgentEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'delta':
        state = state.copyWith(
          streamingText: (state.streamingText ?? '') + event['text']
        );
      case 'approval':
        _showApprovalDialog(event['tools']);
      case 'done':
        state = state.copyWith(streamingText: null);
      case 'error':
        state = state.copyWith(error: event['message']);
    }
  }
  
  Future<void> approveTools(List<String> toolIds) async {
    transport.send({"type": "approve", "sessionId": sessionId, "toolIds": toolIds});
  }
}

// Project settings sync (for remote projects)
class ProjectSettingsSync {
  Future<void> syncFromServer(String projectId, String serverUrl) async {
    // Fetch project settings from server
    final settings = await _fetchProjectSettings(serverUrl, projectId);
    
    // Update local cache
    await projectDao.updateSettings(projectId, settings);
    
    // Update keychain with synced secrets
    await _syncSecrets(projectId, settings.secrets);
  }
  
  Future<void> pushToServer(String projectId, ProjectSettings settings) async {
    final project = await projectDao.getProject(projectId);
    if (project.serverUrl == null) return; // Local project
    
    // Push changes to server
    await _pushProjectSettings(project.serverUrl!, projectId, settings);
  }
}
```
```

---

## 5. Authentication

### 5.1 Simple Authentication (v1)

**For localhost:** No authentication needed

**For remote server:** Optional shared API key

```dart
// Client sends API key in initial connection (if configured)
final ws = WebSocketChannel.connect(
  Uri.parse('$serverUrl/ws?sessionId=$id&apiKey=$key')
);

// Server validates
if (serverApiKey != null && requestApiKey != serverApiKey) {
  closeConnection();
}
```

### 5.2 Future Enhancements (when needed)

- JWT tokens with expiration
- Per-user authentication
- OAuth2 integration

---

## 6. Implementation Plan

### Phase 1: Extract Agent Loop to Shared Package

**Goal:** Refactor without breaking existing app

**Tasks:**
- [ ] Create `decamp-agent-core` package
- [ ] Extract agent loop from `ChatController` into `AgentLoop` class
- [ ] Extract LLM interaction logic
- [ ] Extract tool execution logic
- [ ] Update `ChatController` to use `AgentLoop` from shared package
- [ ] Verify existing app still works

**Deliverable:** Working app using shared agent core

### Phase 2: Build Basic Server

**Goal:** Server can run agent loop and stream events

**Tasks:**
- [ ] Create server project structure
- [ ] Implement WebSocket handler (4 message types)
- [ ] Integrate `AgentLoop` from shared package
- [ ] Add SQLite database for sessions/messages
- [ ] Stream deltas back to clients
- [ ] Basic error handling

**Deliverable:** Server that can run an agent loop

### Phase 3: Build Thin Client with Transport Abstraction

**Goal:** Client can use agent via transport layer

**Tasks:**
- [ ] Create `AgentTransport` interface
- [ ] Implement `IsolateTransport` (local mode)
- [ ] Implement `WebSocketTransport` (remote mode)
- [ ] Create `AgentTransportFactory`
- [ ] Simplify `ChatController` to use `AgentTransport`
- [ ] Handle agent events (delta/approval/done/error)
- [ ] Add server URL to settings (null = local, URL = remote)
- [ ] Test isolate transport
- [ ] Test WebSocket transport with remote server

**Deliverable:** Client working with both transport types

### Phase 4: Tool Approval Flow

**Goal:** Interactive tool approval across WebSocket

**Tasks:**
- [ ] Server: Emit approval requests
- [ ] Server: Wait for approval before executing
- [ ] Client: Display approval dialog
- [ ] Client: Send approval/rejection
- [ ] Test end-to-end flow

**Deliverable:** Full agent loop with approvals

### Phase 5: Polish Local Mode

**Goal:** Rock-solid local experience

**Tasks:**
- [ ] Isolate crash detection and auto-restart
- [ ] Proper isolate cleanup on app termination
- [ ] Handle isolate errors gracefully
- [ ] Performance testing: Isolate overhead
- [ ] Memory profiling: Ensure no leaks
- [ ] Settings UI: Toggle between local and remote

**Deliverable:** Bulletproof local mode using isolates

### Phase 6: Reconnection & Production Ready

**Goal:** Production-ready for remote deployments

**Tasks:**
- [ ] WebSocket reconnection with exponential backoff
- [ ] Catch-up on reconnect (stream missed deltas)
- [ ] Connection status indicators in UI
- [ ] Better error messages and recovery
- [ ] Remote server deployment guide
- [ ] Load testing remote server
- [ ] Security hardening (optional API key)

**Deliverable:** Production-ready system, local and remote

---

## 7. Key Technical Decisions

### 7.1 Always Client-Server

**Decision:** No dual code paths. Client always talks to server.

**Rationale:**
- One agent loop, one execution model
- Easier to test and maintain
- localhost vs remote is just configuration
- No migration complexity

### 7.2 Minimal Protocol

**Decision:** 7 message types (3 client→server, 4 server→client)

**Rationale:**
- Every message type is code to maintain
- Complex protocols are hard to debug
- Start simple, add only when needed

### 7.4 Database as Cache

**Decision:** Client database role depends on project type

**For local projects:**
- Client database is the only storage
- All project settings, sessions, messages stored locally
- No syncing needed

**For remote projects:**
- Client database is cache only
- Server is source of truth
- Settings synced from server
- Can rebuild cache from server

**Rationale:**
- Simpler: no dual storage for local projects
- Server only runs when you need it (remote projects)
- Clear ownership: local = client DB, remote = server DB

### 7.4 Shared Agent Core

**Decision:** Extract agent loop to shared package first

**Rationale:**
- Refactor without breaking existing app
- Server reuses exact same logic as client
- Easier to test agent loop in isolation
- Natural migration path

### 7.5 Transport Abstraction

**Decision:** Project-level execution location (local vs remote)

**Rationale:**
- Projects represent infrastructure/environments
- All sessions in a project should use same execution location
- Project settings naturally belong with the project
- Team collaboration: share entire projects, not individual sessions
- Simpler UX: one decision per project, not per session

### 7.6 Isolates for Local, WebSocket for Remote

**Decision:** Isolates for all local projects, WebSocket only for remote

**Rationale:**
- Isolates work on all platforms (iOS, Android, Desktop, Web)
- No network overhead for local execution
- No localhost server process to manage
- Better battery life on mobile (no sockets)
- Simpler: only 2 transport types, not 3

**Benefits:**
- Unified local execution across all platforms
- WebSocket only needed for actual remote servers
- Less code, fewer edge cases
- Test local mode once, works everywhere

---

## 8. Future Enhancements

**When needed, not now:**

### 8.1 Project Migration
- "Move to server" - convert local project to remote
- "Download locally" - convert remote project to local
- Preserves all sessions and history

### 8.2 Multi-Client Collaboration (Remote Projects)
- Broadcast events to all connected clients
- Show "another user is typing" indicators
- Handle concurrent tool approvals
- Real-time settings sync

### 8.3 Offline Support (Remote Projects)
- Queue commands when offline
- Sync when reconnected
- Graceful degradation

### 8.4 Advanced Authentication
- Per-user accounts on server
- JWT tokens
- OAuth2 providers
- Project-level access control

---

## 9. Success Criteria

**Functional:**
- ✅ Agent loop works via server
- ✅ Streaming text appears in real-time
- ✅ Tool approvals work across WebSocket
- ✅ Localhost auto-starts (or manual start is easy)
- ✅ Remote server deployment works
- ✅ Reconnection recovers gracefully

**Non-Functional:**
- Message latency < 100ms
- Reconnection within 30 seconds
- No data loss on disconnect
- Clear error messages

---

## 10. File Structure

```
decamp-agent-core/          # Shared package
├── lib/
│   ├── agent_loop.dart     # Core agent loop logic
│   ├── llm_client.dart     # LLM integration
│   ├── tool_executor.dart  # Tool execution
│   └── models/
│       ├── message.dart
│       └── session.dart
└── pubspec.yaml

decamp-agent/               # Server
├── bin/
│   └── server.dart         # Main entry point
├── lib/
│   ├── handlers/
│   │   └── websocket_handler.dart
│   ├── services/
│   │   ├── session_store.dart
│   │   └── websocket_manager.dart
│   └── database/
│       └── database.dart   # SQLite schema
└── pubspec.yaml

decamp-app/                 # Client
├── lib/
│   ├── providers/
│   │   └── chat_controller.dart      # Simplified to UI logic
│   ├── services/
│   │   └── transport/
│   │       ├── agent_transport.dart  # Abstract interface
│   │       ├── isolate_transport.dart
│   │       ├── websocket_transport.dart
│   │       └── transport_factory.dart
│   └── database/
│       └── database.dart             # Cache only, no changes
└── pubspec.yaml
```

---

## 11. Dependencies

**Shared Core (`decamp-agent-core`):**
```yaml
dependencies:
  llm_dart:
    path: ../llm_dart
  drift: ^2.14.0
  uuid: ^4.0.0
```

**Server (`decamp-agent`):**
```yaml
dependencies:
  decamp_agent_core:
    path: ../decamp-agent-core
  shelf: ^1.4.0
  shelf_web_socket: ^1.0.4
  shelf_router: ^1.1.4
  sqlite3: ^2.0.0
```

**Client (`decamp-app`):**
```yaml
dependencies:
  web_socket_channel: ^2.4.0  # For WebSocketTransport only
  # Dart Isolate support is built-in, no package needed
  # existing dependencies...
```

---

## Conclusion

This simplified architecture follows a single principle: **one agent loop, variable server location**. By eliminating dual execution modes and complex sync protocols, we achieve:

- **Simplicity:** ~7 message types instead of 13+, no mode switching, no sync metadata
- **Maintainability:** One agent loop to test and debug, shared between isolates and remote server
- **Flexibility:** Project-level execution location (local or remote)
- **Collaboration-ready:** Remote projects enable team sharing
- **Optimized:** No network overhead for local projects on any platform
- **Incremental migration:** Extract shared package first, then build transports, then optional remote server

The key insights:
1. **Client as pure UI layer** - it sends commands and renders events
2. **Project-level execution** - all sessions in a project run in the same place (isolate or server)
3. **Two transports only** - Isolates for local projects, WebSocket for remote projects
4. **Settings follow the project** - remote projects sync settings from server

Start with Phase 1 (shared package extraction) to derisk the refactor without breaking the existing app.
