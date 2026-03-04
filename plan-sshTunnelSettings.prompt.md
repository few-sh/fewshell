## Plan: Client-Only SSH Tunnel Settings

**TL;DR:** Introduce a client-only SSH tunnel system that reuses the existing `SshSettings` model but stores tunnel configs in `FlutterSecureStorage` (never replicated via CRDT). Multiple projects can share a tunnel. The existing `serverUrl` column is reused with a `tunnelId:` prefix to link projects to tunnels. The existing `SshSettingsDialog` is reused (with minor tweaks) for editing tunnel configs.

**Steps**

### 1. Create a tunnel storage service

New service at `decamp-app/lib/services/ssh_tunnel_storage.dart`.

Reuses the existing `SshSettings` model from agent-core — no new model class needed. The model already has `host`, `port`, `username`, `authMethod`, `privateKeySecretId`, `passphraseSecretId`, `enabled`, timestamps. The `*SecretId` fields double as FlutterSecureStorage keys.

Wraps `FlutterSecureStorageImpl` directly (no CRDT, no sync). Key scheme:
- `tunnelId:{id}` → JSON-encoded `SshSettings` (via its existing `toJson()`)
- `tunnelId:{id}:privateKey` → private key PEM string
- `tunnelId:{id}:passphrase` → optional passphrase

Methods: `listAll()` (reads all `tunnelId:*` keys, filters sub-keys), `get(id)`, `save(id, settings, privateKey, passphrase?)`, `delete(id)` (removes metadata + credential keys), `getPrivateKey(id)`, `getPassphrase(id)`.

Use `readAll()` then filter by prefix for listing — `FlutterSecureStorage.readAll()` is already used by `SecretsCrdt` on load, so this pattern is established.

### 2. Create a Riverpod provider

New provider at `decamp-app/lib/providers/ssh_tunnel_provider.dart`.

- `sshTunnelStorageProvider` — singleton `SshTunnelStorage` instance
- `sshTunnelConfigsProvider` — `AsyncNotifier<Map<String, SshSettings>>` (id → settings) that loads all configs and exposes CRUD methods (`create`, `update`, `delete`)
- `projectTunnelProvider(projectId)` — derives which tunnel is assigned to a project by reading `projectEntity.serverUrl`, parsing the `tunnelId:` prefix, and looking up the config

### 3. Update project ↔ tunnel linking

Reuse the existing `serverUrl` column on `ProjectEntity`. Convention:
- `tunnelId:{uuid}` → project uses SSH tunnel with that config ID
- `wss://...` or `ws://...` → direct WebSocket (existing behavior)
- `null` / empty → local-only project
- Remove the `ssh:user@host` format (no need to migrate since it was never released)

No Drift schema migration needed.

### 4. Update `SyncService` tunnel connection

Modify `decamp-app/lib/services/sync_service.dart` to handle the new `tunnelId:` prefix:

- In `_connectGlobal` and `_connectProject`, when `serverUrl` starts with `tunnelId:`, look up the `SshSettings` from `sshTunnelStorageProvider`, retrieve the private key/passphrase from storage, and call `_connectSshWebSocket` with private key auth instead of password.
- Update `_connectSshWebSocket` to accept private key + passphrase (currently it only takes `sshPassword`). The `dartssh2` `SSHClient` already supports `SSHKeyPair` auth — add that path.
- Remove the old `_getSshTunnelPassword` and `parseSshUrl` helpers.

### 5. Reuse `SshSettingsDialog` for tunnel config

The existing `SshSettingsDialog` already handles host/port/username/private key/passphrase with validation and connection testing. Add a `mode` parameter (or similar) to configure it for tunnel use:
- Hide password auth toggle (force private key)
- Hide sudo password field
- Connection test verifies the tunnel to `agent.sock`, not just SSH connect

No new dialog file needed.

### 6. Update settings page — inline tunnel config in project settings

Modify `decamp-app/lib/pages/main_settings.dart`:

- **Replace** `_buildServerUrlSection` (free-text URL field) with an **inline tunnel section** (same pattern as the existing "Remote Shell" section):
  - **No tunnel configured:** "Configure Tunnel" button → opens `SshSettingsDialog` in tunnel mode → on save, creates `SshSettings` in FlutterSecureStorage and auto-assigns it to this project (`tunnelId:{id}` in `serverUrl`)
  - **Tunnel configured:** Shows card with `username@host:port` and edit/delete buttons
  - **No dropdown, no named-config management page** — the user configures the tunnel directly from the project they're working in
- Under the hood, the same `SshSettings` objects in FlutterSecureStorage can be shared across projects. But the UI doesn't require the user to think about this.
- When creating a tunnel, if an existing config matches the same `username@host`, reuse the existing config id.

### 7. Update `ConnectToAgentServerDialog` to use SSH tunnel flow

Currently `ConnectToAgentServerDialog` (used in project setup and debug page) shows a free-text URL input, connects via `syncService.connectGlobal(url)`, waits for global sync, finds matching projects, and switches to one.

Replace the URL input with the `SshSettingsDialog` in tunnel mode, embedded inline or opened as a sub-dialog. New flow:

1. User opens "Connect to Agent Server"
2. Dialog shows the SSH tunnel fields (host/port/username/private key/passphrase) — i.e. the `SshSettingsDialog` in tunnel mode
3. User fills in credentials and hits "Connect"
4. Dialog saves the `SshSettings` to `FlutterSecureStorage` via `SshTunnelStorage`, generates a `tunnelId:{id}`
5. Dialog sets `serverUrl = tunnelId:{id}` on the current project (or creates a project if none exists)
6. `SyncService` picks up the `serverUrl` change, establishes the SSH tunnel, connects WebSocket through `agent.sock`
7. Dialog shows progress ("Connecting via SSH tunnel...", "Waiting for global sync...", "Switching to project...") — reuse existing `_connectAndSetupSession` logic but adapted for tunnel
8. On success, dialog closes. On failure, shows error and allows to retry.

The dialog remains usable from both `project_setup_view.dart` and `debug_page.dart` via its static `show()` method.

### 8. Migration path for existing `ssh:user@host` URLs

We don't need to migrate because we never released the app with the `ssh:` format.
No need to deprecate. Simply replace the old functionality.

### 9. Sudo password handling via agent prompts

Not part of this scope. No need to implement for now.

---

**Verification**
- Create a tunnel config in settings → verify it appears in the tunnel picker
- Assign tunnel to project → verify `serverUrl` is set to `tunnelId:{id}`
- Connect → verify SSH tunnel establishes, agent.sock is reached, CRDT sync works
- Share tunnel across two projects → verify both connect through the same config
- Delete a tunnel → verify projects using it show "disconnected" / prompt to reconfigure
- Run `dart analyze` on decamp-app — no new warnings
- Verify old `SshSettings` (Remote Shell) still works independently

**Decisions**
- **Tunnel configs in FlutterSecureStorage only** — never replicated via CRDT, never leaves the device
- **Private key auth only** for now (enum allows future expansion)
- **Reuse `serverUrl` column** with `tunnelId:` prefix — no Drift migration
- **Keep old `SshSettings`** in project settings for direct SSH shell use case
- **Sudo via agent prompt** — separate follow-up task
- **Reuse `SshSettings` model** from agent-core — no new model class, just different storage backend
