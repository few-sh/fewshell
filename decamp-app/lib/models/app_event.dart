/// App-wide events that may require UI responses (dialogs, toasts,
/// navigation). Services emit these onto the [AppEventBus]; the root
/// [AppEventListener] widget handles dispatch via pattern matching.
sealed class AppEvent {
  const AppEvent();
}

// --- Sync events ---

/// Emitted when global sync WebSocket connects and the server's CRDT node ID
/// is discovered from the upgrade response headers.
class GlobalSyncConnected extends AppEvent {
  final String serverNodeId;
  const GlobalSyncConnected(this.serverNodeId);
}

/// Emitted when global sync reaches idle (initial changeset exchange complete).
class GlobalSyncIdle extends AppEvent {
  final String serverNodeId;
  const GlobalSyncIdle(this.serverNodeId);
}

/// Emitted when the global sync WebSocket disconnects.
class GlobalSyncDisconnected extends AppEvent {
  const GlobalSyncDisconnected();
}

/// Emitted when global sync is idle and no projects exist for the connected
/// server. The UI should prompt the user to create one.
class NoProjectsForServer extends AppEvent {
  final String serverNodeId;

  /// The connection info map (e.g. `{'type': 'tunnel', 'tunnelId': '...'}`) so
  /// the newly created project can be mapped to this connection.
  final Map<String, dynamic>? connectionInfo;

  const NoProjectsForServer(this.serverNodeId, {this.connectionInfo});
}
