import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crdt_sync/crdt_sync.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:agent_core/agent_core.dart';
import '../providers/database_provider.dart';
import '../providers/project_selection_provider.dart';
import '../providers/project_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class SyncService {
  final Ref ref;
  CrdtSync? _globalSync;
  CrdtSync? _projectSync;

  SyncService(this.ref) {
    _init();
  }

  void _init() {
    // Watch for database changes
    ref.listen(globalDatabaseProvider, (previous, next) {
      _connectGlobal(next);
    });

    ref.listen(projectDatabaseProvider, (previous, next) {
      if (next != null) {
        final projectId = ref.read(currentProjectIdProvider);
        if (projectId != null) {
          _connectProject(next, projectId);
        }
      } else {
        _disconnectProject();
      }
    });

    // Watch for project settings changes (specifically serverUrl)
    ref.listen<ProjectEntity?>(currentProjectProvider, (previous, next) {
      if (next != null &&
          previous?.id == next.id &&
          previous?.serverUrl != next.serverUrl) {
        final projectDb = ref.read(projectDatabaseProvider);
        if (projectDb != null) {
          _connectProject(projectDb, next.id);
        }
      }
    });

    // Initial connection
    _connectGlobal(ref.read(globalDatabaseProvider));
    final projectDb = ref.read(projectDatabaseProvider);
    final projectId = ref.read(currentProjectIdProvider);
    if (projectDb != null && projectId != null) {
      _connectProject(projectDb, projectId);
    }
  }

  String get _baseUrl {
    // TODO: Make this configurable via settings
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:3123';
    }
    return 'ws://localhost:3123';
  }

  Future<void> _connectGlobal(GlobalDatabase db) async {
    _globalSync?.close();

    try {
      // Ensure DB is open so that crdt instance is available
      await db.customSelect('SELECT 1').get();

      final crdt = db.crdt;
      final uri = Uri.parse('$_baseUrl/sync/global');

      developer.log('SyncService: Connecting to global sync at $uri');
      _globalSync = CrdtSync.client(crdt, WebSocketChannel.connect(uri));
    } catch (e) {
      developer.log('SyncService: Global DB not ready or error: $e');
    }
  }

  Future<void> _connectProject(ProjectDatabase db, String projectId) async {
    _projectSync?.close();
    try {
      // Ensure DB is open
      await db.customSelect('SELECT 1').get();

      // Get project settings to check for server URL
      final project = await ref
          .read(databaseProvider)
          .projectDao
          .getProject(projectId);
      final serverUrl = project?.serverUrl;

      if (serverUrl == null) {
        developer.log(
          'SyncService: No server URL configured for project $projectId. Skipping sync.',
        );
        return;
      }

      final crdt = db.crdt;
      final uri = Uri.parse('$serverUrl/sync/project/$projectId');

      developer.log('SyncService: Connecting to project sync at $uri');
      _projectSync = CrdtSync.client(crdt, WebSocketChannel.connect(uri));
    } catch (e) {
      developer.log('SyncService: Project DB not ready or error: $e');
    }
  }

  void _disconnectProject() {
    _projectSync?.close();
    _projectSync = null;
  }

  void dispose() {
    _globalSync?.close();
    _projectSync?.close();
  }
}
