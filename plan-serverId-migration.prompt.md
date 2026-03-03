# Server ID Migration Plan

## Problem

`server_url` on the `projects` table currently serves triple duty:
1. **Connection routing** — how to reach the server (URL or `tunnelId:`)
2. **Server identity** — which server a project belongs to (used in `changesetBuilder` filtering)
3. **Execution mode flag** — `null` = local-only, non-null = remote

With SSH tunnels, connection info is client-specific (`tunnelId:<uuid>`), but `server_url` is CRDT-replicated. This causes:
- Client A writes `tunnelId:aaa`, which replicates to Client B (which has its own tunnel `tunnelId:bbb`)
- The `changesetBuilder` filter (`record['server_url'] == serverUrl`) breaks because each client has a different tunnel ID
- The server receives meaningless `tunnelId:` values it can't interpret

## Solution: Separate identity from connection

Add a stable **`server_node_id`** field (replicated) to the projects table and make **connection info client-only** (not replicated).

- `server_node_id` — the server's CRDT node ID, like `srv_<uuid>`, set once by the server, replicated to all clients. Used for sync filtering and server identity. Named `serverNodeId` in Dart code. (Not `node_id` — that name collides with the CRDT metadata column that SqliteCrdt adds to every table.)
- Connection info (URL or tunnel config) — stored locally per-client, never replicated. Maps `serverNodeId → connection details`.

## Design Details

### Server node ID format
- `srv_<uuid-v4>` (e.g. `srv_a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
- Generated once on first server startup, persisted at `data/node_id` (plain text file)
- Used as the server's CRDT node ID (replacing the current hardcoded `'server'`) — this fixes a potential CRDT correctness issue if two agents' records ever coexist in the same DB

### Node ID discovery via header
- The server includes its node ID as a header on the **global sync** WebSocket upgrade response only: `X-Fewshell-Server-Node-Id: srv_...`
- The header name is defined as the constant `kNodeIdHeader` in `agent-core/lib/src/utils/constants.dart`, shared by server and client code
- The client reads this header during WebSocket handshake using a custom HTTP upgrade helper (see Step 5)
- The header is only sent on the `/sync/global` endpoint — project sync doesn't need it since the client already knows the server identity at that point
- No separate endpoint needed — the identity is piggybacked on the existing global sync connection
- The header is NOT added as general middleware to avoid leaking server identity on all HTTP responses

### Client-side connection mapping
- Stored in `FlutterSecureStorage` via the existing `SshTunnelStorage` service
- Key scheme: `connectionMap:<projectId>` → JSON `{ "type": "tunnel", "tunnelId": "<uuid>" }` or `{ "type": "url", "url": "wss://..." }`
- Keyed by **project ID** (not node ID) for direct lookup: given a project, find its connection info
- During initial connection, the `X-Fewshell-Server-Node-Id` header is used transiently to match synced projects by `server_node_id`, then the connection mapping is saved keyed by project ID
- This replaces storing connection info in `server_url`

### WebSocket upgrade helper (client)
- A custom helper method `_connectWebSocketWithHeaders()` performs the HTTP → WebSocket upgrade manually
- Returns both the `WebSocketChannel` and the HTTP response headers (specifically `X-Fewshell-Server-Node-Id`)
- For direct connections: use `HttpClient` with mTLS `SecurityContext`, send upgrade request, extract headers, create `WebSocketChannel` from the upgraded socket
- For SSH tunnel connections: same approach through the local TCP proxy — upgrade is HTTP-level so it works identically through the tunnel
- This is needed because `IOWebSocketChannel.connect()` does not expose the HTTP upgrade response headers

### Node ID format validation (client)
- The client must validate that `server_node_id` values match the expected format: `srv_<uuid-v4>` (regex: `^srv_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
- Validation is applied when reading the `X-Fewshell-Server-Node-Id` header and when receiving `server_node_id` via CRDT replication
- Invalid values are logged and rejected to prevent injection or confusion attacks
- Validation functions (`isValidNodeId()`, `nodeIdPattern`) are in `agent-core/lib/src/utils/server_node_id.dart`

---

## Tasks

### Step 0: Add serverNodeId field to the projects table ✅

- Added `TextColumn get serverNodeId => text().nullable()();` to `projects_table.dart`
- Named `serverNodeId` (not `nodeId`) to avoid colliding with the CRDT metadata column `node_id` that SqliteCrdt adds to every table
- Rebuilt with `dart run build_runner build --delete-conflicting-outputs`
- No schema migration needed since it's nullable and `_reconcileDatabase()` auto-adds missing columns

### Step 1: Generate and persist server node ID on the agent, with automatic migration ✅

**File: `decamp-agent/lib/services/database_manager.dart`**

- Added `late final String nodeId` field to `DatabaseManager`
- In `init()`, calls `readOrCreateNodeId(dataPath)` from `agent-core`
- Passes `nodeId` to `CrdtExecutorFactory.createExecutor(path, nodeId)`
- After opening, runs `_migrateIfNeeded()` + `_setNodeIdOnProjects()`

**Automatic migration at startup:**

The migration logic runs every time the server starts. It is designed to be idempotent and reusable — if you change the `data/node_id` file, the next startup will migrate all records to the new ID.

**Important:** Do NOT use the CRDT library's built-in `resetNodeId()` method — it uses `REPLACE(modified, oldId, newId)` which is an unsafe global substring replacement that could corrupt HLC timestamps if the old node ID appears as a substring in other node IDs. Use the custom `migrateNodeId()` function instead.

1. For each opened CRDT database (global + all project DBs):
   - Read the current CRDT's `canonicalTime.nodeId`
   - If it differs from `nodeId` (from the file), call the custom `migrateNodeId(crdt, oldNodeId, newNodeId)` function
   - Because the HLC timestamps change, CRDT sync will propagate the updated records to any clients that connect afterward
2. For CRDT settings TOML files (`settings_crdt.toml`):
   - Scan for HLC strings ending with `-<oldNodeId>` (suffix match, not substring)
   - Replace the suffix with `-<newNodeId>`
   - Write back
3. Update `server_node_id` values in the `projects` table:
   - Any project records whose `server_node_id` column doesn't match the server's node ID get updated
   - This is a regular CRDT write, so the new value replicates to clients on next sync

**Custom `migrateNodeId()` function** (in a shared utility file):

```dart
/// Safely migrates all HLC timestamps from oldNodeId to newNodeId.
/// Only replaces the trailing node ID suffix — never does substring replacement.
Future<void> migrateNodeId(SqliteCrdt crdt, String oldNodeId, String newNodeId) async {
  for (final table in await crdt.getTables()) {
    await crdt.execute(
      'UPDATE $table SET modified = '
      'SUBSTR(modified, 1, LENGTH(modified) - LENGTH(?1)) || ?2 '
      'WHERE modified LIKE ?3',
      [oldNodeId, newNodeId, '%-$oldNodeId'],
    );
  }
  crdt.canonicalTime = crdt.canonicalTime.apply(nodeId: newNodeId);
}
```

This approach:
- Only modifies the trailing node ID suffix of HLC strings (not a global substring replace)
- Uses `WHERE modified LIKE '%-oldNodeId'` to target only HLC values ending with the old node ID
- Is safe even when node IDs share common substrings (e.g., migrating from `srv_aaa` to `srv_bbb`)
- Eliminates the need for a separate migration CLI tool
- Supports future node ID changes (just edit `data/node_id` and restart)
- Is safe to run repeatedly (no-op if node IDs already match)
- Ensures clients receive the new node ID via normal CRDT replication

**File permissions:** The `data/node_id` file must be created with `0600` permissions (owner-only read/write) to prevent other system users from reading the server's CRDT identity, which could be used to craft malicious CRDT records.

**Implemented files:**
- `agent-core/lib/src/utils/server_node_id.dart` — `readOrCreateNodeId()`, `isValidNodeId()`, `generateServerNodeId()`, `nodeIdPattern`
- `agent-core/lib/src/utils/node_id_migration.dart` — `migrateNodeId(SqliteCrdt, String)` (touch-all-rows approach)
- `agent-core/lib/src/utils/toml_node_id_migration.dart` — `migrateTomlNodeId()`, `migrateAllSettingsToml()`
- `agent-core/lib/src/database/crdt_executor_factory.dart` — `CrdtExecutorResult.crdt` is now `SqliteCrdt`; for empty DBs, sets the requested nodeId via `canonicalTime.apply(nodeId:)`
- `decamp-agent/bin/server.dart` — calls `migrateAllSettingsToml()` at startup before `CrdtSettingsService` init

### Step 2: Add `X-Fewshell-Server-Node-Id` header to global sync WebSocket upgrade response ✅

**File: `decamp-agent/lib/controllers/sync_controller.dart`**

- Extracted `_handleGlobalSync()` method for the global sync handler
- Uses `upgradeWebSocket()` (from `decamp-agent/lib/utils/websocket_upgrade.dart`) instead of `webSocketHandler` to inject the `kNodeIdHeader` into the HTTP 101 response
- The `upgradeWebSocket()` utility performs a manual WebSocket upgrade because shelf_web_socket's `webSocketHandler` doesn't expose a way to add custom headers to the upgrade response
- Only the global sync endpoint has this header — project sync continues using `webSocketHandler`
- Header constant `kNodeIdHeader` is defined in `agent-core/lib/src/utils/constants.dart`

### Step 2b: Server-side validation of incoming project records ✅

**File: `decamp-agent/lib/controllers/sync_controller.dart`**

- In the global sync handler, add a `validateRecord` callback to the server-side `CrdtSync.server`:
  - For the `projects` table: reject any incoming record where `server_node_id` is not null and doesn't match `dbManager.nodeId`
  - This prevents clients from accidentally or maliciously syncing project records destined for a different server
  - Records with `server_node_id == null` should also be rejected (projects must be assigned to a server)
- Example:
  ```dart
  validateRecord: (table, record) {
    if (table == 'projects') {
      final serverNodeId = record['server_node_id'] as String?;
      return serverNodeId != null && serverNodeId == dbManager.nodeId;
    }
    return true;
  },
  ```

### Step 3: Add `server_node_id` column to `projects` table ✅ (done as part of Step 0)

- Added `TextColumn get serverNodeId => text().nullable()();` to `projects_table.dart`
- Column name in SQL is `server_node_id` (avoiding collision with CRDT's `node_id`)
- Regenerated with `dart run build_runner build`

### Step 4: Client connection mapping storage ✅

**File: `decamp-app/lib/services/connection_mapping_storage.dart`** (new file)

- Created `ConnectionMappingStorage` class (separate from `SshTunnelStorage` — different concern)
- Uses the same `SecureStorage` backend
- Methods:
  - `save(String projectId, Map<String, dynamic> connectionInfo)`
  - `get(String projectId) → Map<String, dynamic>?`
  - `delete(String projectId)`
  - `listAll() → Map<String, Map<String, dynamic>>`
- Key scheme: `connectionMap:<projectId>` in SecureStorage
- Connection info JSON: `{ "type": "tunnel", "tunnelId": "..." }` or `{ "type": "url", "url": "wss://..." }`

### Step 5: WebSocket upgrade helper with header extraction ✅

**File: `decamp-app/lib/services/sync_service.dart`** (new helper method)

- Add `_connectWebSocketWithHeaders(Uri uri, {Duration? timeout})` method returning `(WebSocketChannel, Map<String, String> responseHeaders)`:
  1. Create `HttpClient` with mTLS `SecurityContext` (same cert setup as existing `_connectWebSocket`)
  2. Open connection with `client.openUrl('GET', uri)`
  3. Set WebSocket upgrade headers manually: `Connection: Upgrade`, `Upgrade: websocket`, `Sec-WebSocket-Key`, `Sec-WebSocket-Version: 13`
  4. Send request and read response
  5. Extract `X-Fewshell-Server-Node-Id` (and any other headers) from the response
  6. Wrap the upgraded socket in a `WebSocketChannel`
  7. Return both the channel and the headers
- For tunnel connections: the same approach works — the tunnel provides a plain TCP socket, the HTTP upgrade goes through it normally
- This method is only used for global sync connections (where header discovery is needed). Project sync can continue using `IOWebSocketChannel.connect()` directly.

### Step 6: Update SyncService to use `server_node_id` for filtering, connection mapping for routing ✅

**File: `decamp-app/lib/services/sync_service.dart`**

Connection routing changes:
- `_connectGlobal` and `_connectProject`:
  - Look up connection details from `SshTunnelStorage.getConnectionMapping(projectId)` (for routing)
  - Connect via tunnel or direct URL based on the mapping type
- Remove `parseTunnelId()` usage for connection routing — routing comes from the connection mapping, not from `server_url`

Filtering changes (with transitional compatibility):
- `changesetBuilder` in `_connectGlobal`:
  - Filter `projects` records by `server_node_id` instead of `server_url`
  - **Transitional filter:** During the migration period, accept records matching EITHER `server_node_id == project.serverNodeId` OR `server_url == serverUrl` (for clients/servers not yet fully migrated)
  - After migration is confirmed complete, simplify to `server_node_id`-only filter
  - `record['server_node_id'] == project.serverNodeId` (all clients share the same `server_node_id` — this is the stable long-term filter)
- `validateRecord` in `_connectGlobal`:
  - Validate `server_node_id` is non-null and matches expected format (`srv_<uuid>`)
  - **Transitional:** Also accept records with non-null `server_url` if `server_node_id` is not yet set

Node ID discovery (global sync only):
- Use the `_connectWebSocketWithHeaders()` helper (Step 5) for global sync connections
- Read `X-Fewshell-Server-Node-Id` from the upgrade response headers
- Validate the format (`srv_<uuid-v4>`) using `isValidNodeId()` from `agent-core`
- The client does NOT write `server_node_id` to the project record — the server sets `server_node_id` on project records during its migration (Step 1), and CRDT replication naturally propagates this to clients
- The header value is used transiently to:
  1. Save the connection mapping: `connectionMap:<projectId>` → connection details
  2. Match synced projects: find projects where `server_node_id` matches the header value

Bootstrap flow (initial connection, reinstall, or new device):
1. User opens "Connect to Agent Server" and configures SSH tunnel
2. Client connects global sync WebSocket using tunnel, reads `X-Fewshell-Server-Node-Id` header → `serverNodeId`
3. Client waits for global sync to complete
4. Client queries projects table for records where `server_node_id == serverNodeId`
5. For each matching project, saves connection mapping: `connectionMap:<projectId>` → `{ type: tunnel, tunnelId }`
6. Client switches to the matching project and connects project sync

This flow handles all cases where a client needs to (re)establish connection mappings: first-time setup, app reinstall (connection mappings + SSH keys are lost, so user must reconfigure the tunnel anyway), and new device setup.

Auto-mapping for new projects during an active session:
- When global sync is active, the `SyncService` remembers the current `serverNodeId` (from the header) and the connection details used for this session
- After each global sync cycle, check for project records where `server_node_id == serverNodeId` but no `connectionMap:<projectId>` exists
- Auto-create connection mappings for these projects using the same connection details as the active session
- This handles projects created on the server while the client is already connected — they arrive via CRDT sync and automatically get a connection mapping

### Step 7: Update ConnectToAgentServerDialog ✅

**File: `decamp-app/lib/components/connect_to_agent_server.dart`**

- After tunnel save + SSH connection:
  - Connect global sync — the `SyncService` now reads `X-Fewshell-Server-Node-Id` from the upgrade response
  - Wait for global sync to complete
  - Query projects matching the server's `server_node_id` (discovered from header)
  - Connection mappings are auto-created by SyncService (see Step 6 auto-mapping)
  - `server_url` is no longer set (or set to null) — `server_node_id` is set by the server via CRDT replication, not by the client
  - Match projects by `server_node_id` instead of `server_url` when polling for synced projects

### Step 8: Update Settings Page ✅

**File: `decamp-app/lib/pages/main_settings.dart`**

- `_buildServerUrlSection` / tunnel card:
  - Read `serverNodeId` from project to determine if connected to a server
  - Look up connection details from `getConnectionMapping(project.id)` to display tunnel info
  - On tunnel configure/edit: save tunnel + update connection mapping by project ID
  - On tunnel remove: delete connection mapping + clear `serverNodeId`
- The UI should show the `serverNodeId` somewhere for debugging (e.g. small muted text)

### Step 9: Update providers ✅

**File: `decamp-app/lib/providers/ssh_tunnel_provider.dart`**

- `projectTunnelProvider`: derive tunnel info from connection mapping (via `projectId`) instead of parsing `tunnelId:` from `server_url`
- Remove `parseTunnelId()` — no longer needed after migration is complete (keep during transition)

**File: `decamp-app/lib/providers/providers.dart`** or new file

- Add a provider for connection mapping lookups by project ID

### Step 10: Update execution mode check in agent-core ✅

**File: `agent-core/lib/src/controllers/chat_controller.dart`**

- `isLocalExecution` (line 41) should check `_project?.serverNodeId == null` instead of `_project?.serverUrl == null`
- The remote execution gate at line ~427 uses a different expression: `_project?.serverUrl != null` (not `isLocalExecution`). Update this to `_project?.serverNodeId != null` to match.
- Both checks must be updated consistently — `isLocalExecution` is used for local lock acquisition (lines 132, 342, 660), while the direct `serverUrl != null` check is used for remote delegation (line 427)

### Step 11: Update UI references ✅

**File: `decamp-app/lib/pages/projects_page.dart`**

- Cloud icon / server info display: use `serverNodeId` instead of `serverUrl`

**File: `decamp-app/lib/pages/chat_session.dart`**

- `SyncIndicator` visibility: check `serverNodeId != null` instead of `serverUrl != null`

### Step 12: Remove `server_url` field (deferred)

After migration is confirmed working, `server_url` can be deprecated and eventually removed. For now, keep it nullable and unused — removing it requires coordinating schema changes across all clients/servers.

---

## Migration Path for Existing Deployments

1. Deploy new agent code and restart — on startup, the agent:
   - Generates `data/node_id` with `0600` permissions (if not present)
   - Automatically migrates all CRDT databases from `'server'` to the new `srv_<uuid>` node ID using the custom `migrateNodeId()` function
   - Migrates TOML settings files (`settings_crdt.toml`) via `migrateAllSettingsToml()`
   - Sets `server_node_id` on project records (replicated to clients on next sync)
   - Starts serving with `X-Fewshell-Server-Node-Id` header on global sync WebSocket upgrade responses
   - Enables server-side `validateRecord` filtering for incoming project records
2. Update clients:
   - Clients read `X-Fewshell-Server-Node-Id` header on global sync connect to discover server identity
   - Clients save connection mapping by project ID (not on the project record)
   - `server_node_id` on project records arrives via normal CRDT replication from the server
   - **Transitional:** `changesetBuilder` accepts projects matching EITHER `server_node_id` or `server_url` during the migration period
3. Old `server_url` values on project records become stale but harmless (nullable, ignored by new code)
4. After confirming all clients and servers are updated, remove the transitional `server_url` fallback from `changesetBuilder`

## Future Node ID Changes

To change a server's node ID (e.g. after cloning a server, or for debugging):
1. Edit `data/node_id` with the new value (or delete it to auto-generate a fresh one)
2. Restart the agent — migration runs automatically, updating all HLC timestamps and project records
3. Connected clients receive the updated `server_node_id` via CRDT replication on next sync

## Test Plan

### Migration Tests

**Test: Fresh server generates node ID and uses it as CRDT node ID**
1. Start agent with empty `data/` directory
2. Assert `data/node_id` file is created with `srv_` prefix
3. Assert `globalDatabase.crdt.nodeId` matches the file contents

**Test: Existing server migrates from `'server'` to new node ID** ✅ (covered in crdt_node_id_migration_test.dart)
1. Create a CRDT database with node ID `'server'` and insert some records
2. Run `DatabaseManager.init()` with a `data/node_id` file containing `srv_test123`
3. Assert `crdt.nodeId == 'srv_test123'`
4. Assert all `modified` HLC columns in all tables have been updated (no `-server` suffixes remain)
5. Assert the migration is visible to CRDT sync — i.e. `getChangeset()` returns records with the new node ID that would replicate to clients

**Test: Migration is idempotent**
1. Run startup migration once (from `'server'` → `srv_xxx`)
2. Run startup migration again with the same `data/node_id`
3. Assert no changes to the database (no unnecessary writes)

**Test: Node ID rotation**
1. Start with node ID `srv_aaa`, insert records
2. Change `data/node_id` to `srv_bbb`, restart
3. Assert all HLC timestamps updated from `srv_aaa` to `srv_bbb`
4. Assert `server_node_id` column on project records updated to `srv_bbb`
5. Assert a client syncing after the change receives the new `server_node_id` on the project record

**Test: TOML settings migration**
1. Create a `settings_crdt.toml` with HLC values containing `-server`
2. Run migration
3. Assert all HLC values in TOML now contain `-srv_xxx` instead of `-server`
4. Assert non-HLC content in the TOML file is unchanged

### Custom Migration Function Tests

**Test: `migrateNodeId()` safely replaces only trailing node IDs**
1. Create a CRDT database with node ID `'server'`, insert records
2. Manually verify `modified` column values end with `-server`
3. Call `migrateNodeId(crdt, 'server', 'srv_test123')`
4. Assert all `modified` values now end with `-srv_test123`
5. Assert no other part of the HLC timestamp was modified (ISO date, counter intact)

**Test: `migrateNodeId()` doesn't affect records from other nodes**
1. Create a CRDT database, insert records from node `'server'`
2. Merge a changeset from a client node `'client_abc'`
3. Run `migrateNodeId(crdt, 'server', 'srv_test123')`
4. Assert records from `'server'` are migrated to `'srv_test123'`
5. Assert records from `'client_abc'` are UNCHANGED

**Test: `migrateNodeId()` handles node ID that is substring of another**
1. Create records with node ID `'srv_aaa'`
2. Merge records from node ID `'srv_aaa_extended'`
3. Run `migrateNodeId(crdt, 'srv_aaa', 'srv_bbb')`
4. Assert only `'srv_aaa'` records are migrated (not `'srv_aaa_extended'`)

### Filtering Tests

**Test: changesetBuilder only sends projects matching current server_node_id**
1. Create global DB with two projects: project A (`server_node_id: 'srv_aaa'`) and project B (`server_node_id: 'srv_bbb'`)
2. Connect global sync with `server_node_id = 'srv_aaa'`
3. Call `changesetBuilder` to get outgoing changeset
4. Assert changeset contains project A but not project B

**Test: validateRecord rejects projects with null server_node_id**
1. Receive an incoming CRDT record for the `projects` table with `server_node_id: null`
2. Assert `validateRecord` returns false (record rejected)

**Test: validateRecord accepts projects with valid server_node_id**
1. Receive an incoming CRDT record for the `projects` table with `server_node_id: 'srv_aaa'`
2. Assert `validateRecord` returns true (record accepted)

**Test: Multi-client filtering with shared server_node_id**
1. Two clients (A and B) both connect to the same server (`srv_xxx`)
2. Client A has tunnel `tunnelId:aaa`, Client B has tunnel `tunnelId:bbb` (different local connection info)
3. Both projects have `server_node_id: 'srv_xxx'` (same, replicated)
4. Assert both clients' `changesetBuilder` correctly filters by `server_node_id` — both send/receive the same project
5. Assert neither client's local tunnel ID leaks into replicated state

**Test: Client reads X-Fewshell-Server-Node-Id header and uses it for connection mapping**
1. Mock a WebSocket server that returns `X-Fewshell-Server-Node-Id: srv_test` in upgrade response
2. Client connects global sync using the custom WebSocket upgrade helper
3. Assert the header value is read correctly and validated (format: `srv_<uuid>`) using `isValidNodeId()`
4. Assert the client does NOT write `server_node_id` to the project record (this comes via CRDT replication)
5. Assert the client saves connection mapping keyed by project ID
6. Assert project matching uses the header value to find projects where `server_node_id == 'srv_test'`

### Server-Side Validation Tests

**Test: Server rejects incoming project records with wrong server_node_id**
1. Server has `nodeId = 'srv_aaa'`
2. Client sends a changeset with a project record where `server_node_id = 'srv_bbb'`
3. Assert server's `validateRecord` rejects the record

**Test: Server rejects incoming project records with null server_node_id**
1. Server has `nodeId = 'srv_aaa'`
2. Client sends a changeset with a project record where `server_node_id = null`
3. Assert server's `validateRecord` rejects the record

**Test: Server accepts incoming project records with matching server_node_id**
1. Server has `nodeId = 'srv_aaa'`
2. Client sends a changeset with a project record where `server_node_id = 'srv_aaa'`
3. Assert server's `validateRecord` accepts the record

### Node ID Format Validation Tests

**Test: Valid server_node_id format accepted**
1. Validate `'srv_a1b2c3d4-e5f6-7890-abcd-ef1234567890'` → accepted via `isValidNodeId()`

**Test: Invalid server_node_id formats rejected**
1. Validate `'server'` → rejected (old format)
2. Validate `'srv_notauuid'` → rejected
3. Validate `''` → rejected
4. Validate `'malicious_value; DROP TABLE'` → rejected

### Connection Mapping Tests

**Test: Connection mapping stored and retrieved by project ID**
1. Save connection mapping for project `'proj_123'` → `{ type: tunnel, tunnelId: 'tun_abc' }`
2. Retrieve mapping for `'proj_123'` → assert it matches
3. Delete mapping for `'proj_123'` → assert retrieval returns null
