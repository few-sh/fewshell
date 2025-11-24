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

// WebSocket transport (remote mode)
class WebSocketTransport implements AgentTransport {
  WebSocketChannel? _channel;
  // Uses WebSocket for network communication
}

// E2EE transport (future - blind relay)
class EncryptedWebSocketTransport implements AgentTransport {
  WebSocketChannel? _channel;
  CryptoKeys _keys;
  // Encrypts/decrypts at transport layer
  // Server sees only encrypted blobs, routes blindly
  // Same message protocol, just encrypted
}
```

---

## 2. Communication Protocol

### 2.1 Message Envelope Structure

**All messages use a hierarchical envelope** for extensibility and future features:

```dart
// Top-level envelope (always present)
{
  "v": 1,                          // Protocol version
  "id": "msg_uuid",                // Unique message ID
  "timestamp": "2025-11-24T...",   // ISO 8601
  "sessionId": "session_123",      // Session context
  "userId": "user_456",            // Sender (null for server)
  "type": "event",                 // Envelope type: "command" | "event" | "sync"
  "payload": { /* type-specific */ }
}
```

**Envelope types:**
- `command` - Client requests action (send message, approve tools, etc.)
- `event` - Server broadcasts state change (delta, approval needed, etc.)
- `sync` - Bidirectional state sync (settings, presence, etc.)

**Future-ready:**
- Add `"encrypted": true` + `"encryptedPayload": "..."` for E2EE blind relay
- Add `"replyTo": "msg_id"` for threading
- Add `"priority": "high"` for urgent messages
- Envelope unchanged, only payload varies

### 2.2 Command Payloads (Client → Server)

```json
// Send user message
{
  "v": 1,
  "type": "command",
  "userId": "user_456",
  "sessionId": "session_123",
  "payload": {
    "action": "sendMessage",
    "content": "deploy the app to production"
  }
}

// Approve tools (single or multi-user)
{
  "v": 1,
  "type": "command",
  "userId": "user_456",
  "sessionId": "session_123",
  "payload": {
    "action": "approvTools",
    "approvalId": "approval_789",
    "toolIds": ["tool_1", "tool_2"]
  }
}

// Typing indicator (future: multi-user)
{
  "v": 1,
  "type": "sync",
  "userId": "user_456",
  "sessionId": "session_123",
  "payload": {
    "action": "typing",
    "isTyping": true
  }
}
```

### 2.3 Event Payloads (Server → Client)

```json
// AI text streaming
{
  "v": 1,
  "type": "event",
  "sessionId": "session_123",
  "payload": {
    "event": "aiDelta",
    "messageId": "msg_457",
    "delta": "Here is the deployment status..."
  }
}

// Tool output streaming (future requirement #1)
{
  "v": 1,
  "type": "event",
  "sessionId": "session_123",
  "payload": {
    "event": "toolOutput",
    "toolId": "tool_1",
    "stream": "stdout",  // or "stderr"
    "delta": "Applying deployment.yaml...\n"
  }
}

// Tool approval needed (supports multi-approval)
{
  "v": 1,
  "type": "event",
  "sessionId": "session_123",
  "payload": {
    "event": "approvalRequest",
    "approvalId": "approval_789",
    "messageId": "msg_457",
    "requiredApprovals": 1,  // Future: set to 2+ for multi-person rule
    "currentApprovals": 0,
    "approvedBy": [],        // List of userIds who approved
    "tools": [
      {
        "id": "tool_1",
        "name": "execute_shell_command",
        "params": {"command": "kubectl apply -f deploy.yaml"}
      }
    ]
  }
}

// Approval status update (multi-user collaboration)
{
  "v": 1,
  "type": "event",
  "sessionId": "session_123",
  "payload": {
    "event": "approvalUpdate",
    "approvalId": "approval_789",
    "currentApprovals": 1,
    "approvedBy": ["user_456"],
    "requiresApprovals": 2,
    "status": "pending"  // "pending" | "approved" | "rejected"
  }
}

// Message completed
{
  "v": 1,
  "type": "event",
  "sessionId": "session_123",
  "payload": {
    "event": "messageComplete",
    "messageId": "msg_457"
  }
}

// User activity (typing, viewing, etc.)
{
  "v": 1,
  "type": "event",
  "sessionId": "session_123",
  "payload": {
    "event": "userActivity",
    "userId": "user_789",
    "activity": "typing",  // "typing" | "viewing" | "idle"
    "userName": "Alice"
  }
}

// Error occurred
{
  "v": 1,
  "type": "event",
  "sessionId": "session_123",
  "payload": {
    "event": "error",
    "error": "LLM API timeout",
    "recoverable": true
  }
}
```

### 2.4 Protocol Versioning

**Version field (`v`)** enables protocol evolution:
- Clients and servers advertise supported versions
- Negotiate highest common version on connect
- Graceful degradation for older clients
- Breaking changes = new version number

### 2.5 Why Hierarchical Envelopes?

**Supports all future requirements:**

1. **Streaming command output:** Add `toolOutput` event type with `delta` field
2. **Multi-user collaboration:** `userId` in envelope, `userActivity` events
3. **Multi-person approval:** `requiredApprovals` + `approvedBy` array in approval events
4. **Blind relay E2EE:** Handled at transport layer - `EncryptedWebSocketTransport`

**Benefits over flat structure:**
- **Extensible:** Add new envelope fields without breaking old clients
- **Versionable:** Protocol version in every message
- **Routable:** Server can route without parsing payload
- **Type-safe:** Clear separation between envelope and payload schemas
- **Debuggable:** Envelope metadata helps with tracing and logging

**Cost:**
- Slightly more verbose (~30 extra bytes per message)
- Worth it for long-term flexibility

**Note on E2EE:** Encryption is a transport concern, not a protocol concern. The `EncryptedWebSocketTransport` encrypts entire message envelopes before sending. Server routes opaque blobs without seeing content.

### 2.6 Transport Implementation

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

### 2.7 Reconnection

**WebSocket only:**
- Client stores last rendered `messageId`
- On disconnect: exponential backoff reconnection (1s, 2s, 4s, 8s, max 30s)
- On reconnect: server streams all events since last `messageId`

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
  final String userId;
  
  void sendMessage(String content) {
    final envelope = {
      "v": 1,
      "type": "command",
      "userId": userId,
      "sessionId": sessionId,
      "timestamp": DateTime.now().toIso8601String(),
      "payload": {
        "action": "sendMessage",
        "content": content
      }
    };
    transport.send(envelope);
  }
  
  void handleAgentEvent(Map<String, dynamic> envelope) {
    final payload = envelope['payload'];
    
    switch (payload['event']) {
      case 'aiDelta':
        state = state.copyWith(
          streamingText: (state.streamingText ?? '') + payload['delta']
        );
      case 'toolOutput':
        _handleToolOutput(payload);
      case 'approvalRequest':
        _showApprovalDialog(payload['tools'], payload['approvalId']);
      case 'approvalUpdate':
        _updateApprovalStatus(payload);
      case 'messageComplete':
        state = state.copyWith(streamingText: null);
      case 'userActivity':
        _handleUserActivity(envelope['userId'], payload);
      case 'error':
        state = state.copyWith(error: payload['error']);
    }
  }
  
  Future<void> approveTools(String approvalId, List<String> toolIds) async {
    final envelope = {
      "v": 1,
      "type": "command",
      "userId": userId,
      "sessionId": sessionId,
      "timestamp": DateTime.now().toIso8601String(),
      "payload": {
        "action": "approveTools",
        "approvalId": approvalId,
        "toolIds": toolIds
      }
    };
    transport.send(envelope);
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

### 7.2 Hierarchical Message Protocol

**Decision:** Envelope + payload structure instead of flat messages

**Rationale:**
- **Future-proof:** Supports streaming tool output, multi-user, multi-approval, E2EE
- **Versionable:** Protocol version in every message for evolution
- **Routable:** Server can route on envelope without parsing payload
- **Encryptable:** Blind relay can encrypt payload while preserving routing metadata
- **Extensible:** Add envelope fields (userId, replyTo, priority) without breaking clients

**Trade-offs:**
- ~30 bytes overhead per message
- Slightly more complex parsing
- Worth it for 10+ years of protocol stability

**Message count:** Still minimal - just more structured
- Commands: `sendMessage`, `approveTools`, `typing` (future)
- Events: `aiDelta`, `toolOutput`, `approvalRequest`, `messageComplete`, `userActivity`, `error`

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

### 8.5 End-to-End Encryption (Blind Relay)
- New transport: `EncryptedWebSocketTransport`
- Encrypt entire message envelopes at transport layer
- Server routes opaque encrypted blobs
- Zero-knowledge architecture
- Client-to-client encryption keys
- No protocol changes needed - transport layer concern

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
│   │       ├── agent_transport.dart          # Abstract interface
│   │       ├── isolate_transport.dart        # Local mode
│   │       ├── websocket_transport.dart      # Remote mode
│   │       ├── encrypted_websocket_transport.dart  # E2EE (future)
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

This simplified architecture follows a single principle: **one agent loop, variable server location**. By using hierarchical message envelopes and project-level execution, we achieve:

- **Simplicity:** Clear envelope + payload structure, project-level execution decision
- **Future-proof:** Protocol supports streaming tool output, multi-user, multi-approval, E2EE blind relay
- **Maintainability:** One agent loop to test and debug, shared between isolates and remote server
- **Flexibility:** Project-level execution location (local or remote)
- **Collaboration-ready:** Remote projects enable team sharing with multi-user support built into protocol
- **Optimized:** No network overhead for local projects on any platform
- **Incremental migration:** Extract shared package first, then build transports, then optional remote server

The key insights:
1. **Client as pure UI layer** - it sends commands and renders events
2. **Project-level execution** - all sessions in a project run in the same place (isolate or server)
3. **Hierarchical protocol** - envelope metadata + typed payloads for extensibility
4. **Transports handle encryption** - E2EE is a transport concern, not a protocol concern
5. **Settings follow the project** - remote projects sync settings from server

**The hierarchical envelope structure is the critical decision** - it costs ~30 bytes per message but buys 10+ years of protocol evolution without breaking changes. Three of the four future requirements (streaming tool output, multi-user, multi-approval) are naturally supported by the protocol. The fourth (E2EE blind relay) is cleanly handled at the transport layer via `EncryptedWebSocketTransport`.

**Separation of concerns:**
- **Protocol layer:** Message structure, event types, business logic
- **Transport layer:** How messages move (Isolates, WebSocket, encrypted WebSocket)
- This separation means E2EE doesn't pollute the protocol with encryption-specific fields

Start with Phase 1 (shared package extraction) to derisk the refactor without breaking the existing app.
