# Client-Server Architecture Plan (Simplified)

## Executive Summary

Enable remote execution for Decamp with minimal complexity. Keep local sessions using existing code. Add WebSocket server for remote sessions. The agent loop is just 8 lines - everything else is plumbing.

**Key principle:** Build the dumbest thing that works. No premature abstraction.

---

## 1. Core Architecture

### 1.1 The 8-Line Agent Loop

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

### 1.2 Session-Level Execution Location

Each session has a `serverUrl` field:
- `null` = local execution (current behavior)
- `"https://server.com"` = remote execution

**Why session-level?** More flexible than project-level. User can have some local sessions for quick testing, some remote sessions for team collaboration.

### 1.3 Data Storage

**Local sessions:**
- Source of truth: SQLite on device (current Drift database)
- Works offline completely

**Remote sessions:**
- Source of truth: SQLite on server (same schema as client)
- Client has simple cache (JSON file or single-table SQLite)
- Cache is disposable - can refill from server anytime
- Offline: read-only access to cached data
- Online required for: new messages, edits, deletions

---

## 2. Communication Protocol

### 2.1 Simple Messages (No Envelopes)

**Client → Server:**

```json
// Start agent loop
{"cmd": "run", "sid": "session_123"}

// Approve tools
{"cmd": "approve", "tools": [1, 2, 3]}
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

// Error
{"t": "error", "msg": "LLM timeout"}
```

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
---

## 3. Storage Strategy

### 3.1 Session Metadata

Add `serverUrl` to Sessions table:

```dart
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get description => text()();
  
  // NEW: Where does this session run?
  TextColumn get serverUrl => text().nullable()();
  // null = local execution, URL = remote execution
  
  // ... other fields
}
```

### 3.2 Local Sessions

**Storage:** Existing Drift database on device

**Execution:** Direct function calls (no WebSocket, no isolate)

```dart
// Just call the agent loop directly
await agentLoop.run(
  conversation: messages,
  onDelta: (text) => setState(() => streamingText += text),
  onApproval: (tools) => showApprovalDialog(tools),
);
```

**Offline:** Everything works (source of truth is on device)

// Thin client controller - just UI logic
class ChatController extends StateNotifier<ChatState> {
### 3.3 Remote Sessions

**Server storage:** SQLite database on server (same schema as client)

**Client cache:** For offline read-only access

**Cache implementation** (pick one based on need):

1. **Single-table SQLite** (if performance becomes an issue):
   ```dart
   // One disposable table, no migrations
   CREATE TABLE cache(session_id TEXT PRIMARY KEY, data TEXT)
   ```

**Offline behavior:**
- **Reads:** Show cached data with "Offline" banner
- **Writes:** Error message "Reconnect to send messages"
- **Deletes:** Error message "Reconnect to delete sessions"
- **On reconnect:** Clear cache, re-fetch from server

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

### 4.3 Client (SessionStore Interface)

```dart
// Single interface, two implementations
abstract class SessionStore {
  Future<void> sendMessage(String sessionId, String content);
  Stream<ChatState> watchSession(String sessionId);
}

// Local: use existing ChatController (unchanged)
class LocalSessionStore implements SessionStore {
  // Uses ChatController.sendMessage() directly
}

// Remote: WebSocket communication
class RemoteSessionStore implements SessionStore {
  WebSocket? _ws;
  
  Future<void> sendMessage(String sessionId, String content) async {
    if (_ws == null) {
      _ws = await WebSocket.connect('$url?sid=$sessionId');
      _listenForEvents();
    }
    _ws!.send(jsonEncode({'cmd': 'run'}));
  }
  
  void _listenForEvents() {
    _ws!.listen((data) {
      final event = jsonDecode(data);
      switch (event['t']) {
        case 'delta': _onTextDelta(event['d']);
        case 'approval': _onApprovalRequest(event['tools']);
        case 'done': _onMessageComplete();
        case 'error': _onError(event['msg']);
      }
    });
  }
}
```

**UI code doesn't change** - it uses `SessionStore` interface regardless of local/remote.

---

## 5. Migration Path

### Phase 1: Extract Agent Loop

- Create `decamp_core` package
- Extract 8-line loop to `runAgentLoop()` function
- `ChatController` now calls `runAgentLoop()`
- **Test:** App works identically

### Phase 2: Basic Server

- Implement WebSocket handler
- Wire up `runAgentLoop()` with WebSocket callbacks
- SQLite on server (copy client schema)
- **Test:** Manual with `websocat` tool

### Phase 3: Client WebSocket

- Add `serverUrl` to Sessions table
- Implement `RemoteSessionStore`
- UI checks `serverUrl`: null → local, URL → remote
- JSON file cache (atomic writes)
- **Test:** Local server connection

### Phase 4: Polish

- Reconnection (exponential backoff)
- Error messages
- Connection status UI
- Deployment guide

**Total: 4 weeks**

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
- ❌ Complex caching (JSON file sufficient)

Build the simplest thing. Add complexity only when users complain.

---

## 7. Key Decisions

### Session-Level Execution

Session has `serverUrl` field. More flexible than project-level (can mix local/remote within one project).

### No Isolates for Local

Direct function calls are simpler. Isolates add complexity without benefit (can't run in background on mobile anyway).

### Simple Protocol

Flat JSON messages. No envelopes, no versioning (yet). Add when first breaking change happens.

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
- ✅ Offline viewing of cached sessions
- ✅ Reconnection recovers cleanly

**Nice to have (later):**
- Team collaboration (shared remote sessions)
- Real-time badges
- Streaming tool output
- Multi-person approvals

---

## Conclusion

**Build for today's problems, not tomorrow's.**

The core value is: "I can run agent loops remotely and share sessions with my team."

Everything else is optimization. Start with ~200 lines of code (8-line agent loop + minimal server + WebSocket client). Ship it. Then iterate based on real usage.

The plan had 1000+ lines describing protocols, transports, envelopes, versioning, caching strategies... **You don't need any of that yet.**

Extract the loop. Wire up WebSocket. Done.
