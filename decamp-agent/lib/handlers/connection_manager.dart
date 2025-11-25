import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../stores/toml_project_data_store.dart';

/// Manages WebSocket connections and broadcasts to clients.
///
/// Tracks which clients are connected to which projects, enabling
/// broadcast of settings/snippets/secrets changes to all relevant clients.
class ConnectionManager {
  static final ConnectionManager instance = ConnectionManager._();
  ConnectionManager._();

  /// Shared data store
  final TomlProjectDataStore dataStore = TomlProjectDataStore();

  /// Map of projectId -> list of connected WebSocket clients
  final Map<String, List<WebSocketChannel>> _projectClients = {};

  /// Map of WebSocket -> projectId (reverse lookup)
  final Map<WebSocketChannel, String> _clientProjects = {};

  /// Register a client for a project
  void registerClient(WebSocketChannel ws, String projectId) {
    _clientProjects[ws] = projectId;
    _projectClients.putIfAbsent(projectId, () => []).add(ws);
  }

  /// Unregister a client
  void unregisterClient(WebSocketChannel ws) {
    final projectId = _clientProjects.remove(ws);
    if (projectId != null) {
      _projectClients[projectId]?.remove(ws);
      if (_projectClients[projectId]?.isEmpty ?? false) {
        _projectClients.remove(projectId);
      }
    }
  }

  /// Get the project ID for a client
  String? getProjectId(WebSocketChannel ws) => _clientProjects[ws];

  /// Broadcast a message to all clients connected to a project
  void broadcastToProject(String projectId, Map<String, dynamic> message,
      {WebSocketChannel? exclude}) {
    final clients = _projectClients[projectId] ?? [];
    final json = jsonEncode(message);

    for (final client in clients) {
      if (client != exclude) {
        try {
          client.sink.add(json);
        } catch (_) {
          // Client disconnected, will be cleaned up
        }
      }
    }
  }

  /// Broadcast to all clients in a project, including the sender
  void broadcastToProjectAll(String projectId, Map<String, dynamic> message) {
    broadcastToProject(projectId, message);
  }
}
