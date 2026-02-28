import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:decamp/models/app_event.dart';
import 'package:decamp/providers/providers.dart';
import 'package:decamp/services/app_event_bus.dart';
import 'package:decamp/components/create_project_dialog.dart';

final _log = Logger('AppEventListener');

/// Root-level widget that subscribes to [AppEventBus.events] and dispatches
/// UI actions (dialogs, toasts) via pattern matching on the sealed [AppEvent]
/// hierarchy.
///
/// Place this near the top of the widget tree so it always has a valid
/// [BuildContext] for showing dialogs.
class AppEventListener extends ConsumerStatefulWidget {
  final Widget child;

  const AppEventListener({super.key, required this.child});

  @override
  ConsumerState<AppEventListener> createState() => _AppEventListenerState();
}

class _AppEventListenerState extends ConsumerState<AppEventListener> {
  StreamSubscription<AppEvent>? _subscription;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    final bus = ref.read(appEventBusProvider);
    _subscription = bus.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onEvent(AppEvent event) {
    switch (event) {
      case NoProjectsForServer(:final serverNodeId, :final connectionInfo):
        _handleNoProjects(serverNodeId, connectionInfo);
      case GlobalSyncConnected():
      case GlobalSyncIdle():
      case GlobalSyncDisconnected():
        break; // Future: handle as needed
    }
  }

  Future<void> _handleNoProjects(
    String serverNodeId,
    Map<String, dynamic>? connectionInfo,
  ) async {
    if (_dialogShowing || !mounted) return;
    _dialogShowing = true;

    try {
      // Defer to next frame to avoid showing the dialog while the navigator
      // is locked (e.g. ConnectionProgressDialog is mid-pop).
      await Future.delayed(Duration.zero);
      if (!mounted) return;

      final name = await showCreateProjectDialog(
        context,
        serverNodeId: serverNodeId,
      );

      if (name == null || !mounted) return;

      final globalDb = ref.read(globalDatabaseProvider);
      final projectId = await globalDb.projectDao.createProjectWithId(
        name: name,
        serverNodeId: serverNodeId,
      );

      _log.info(
        'Created project "$name" ($projectId) for server $serverNodeId.',
      );

      // Save the connection mapping so the sync service can reconnect
      // for this project without re-resolving connection details.
      if (connectionInfo != null) {
        final mappingStorage = ref.read(connectionMappingStorageProvider);
        await mappingStorage.save(projectId, connectionInfo);
        _log.info(
          'Saved connection mapping for project $projectId: $connectionInfo',
        );
      }

      await ref.read(currentProjectIdProvider.notifier).select(projectId);
    } catch (e, st) {
      _log.warning('Error creating project: $e', e, st);
    } finally {
      _dialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
