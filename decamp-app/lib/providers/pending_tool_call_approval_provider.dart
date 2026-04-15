import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../services/sync_service.dart';
import 'providers.dart';

final pendingToolCallApprovalProvider =
    StateNotifierProvider.autoDispose<
      PendingToolCallApprovalNotifier,
      PendingToolCallList
    >((ref) {
      final sessionId = ref.watch(currentSessionIdProvider);
      final projectConnectionState = ref.watch(
        connectionStateProvider.select((state) => state.project),
      );
      final channel = ref.read(syncServiceProvider).projectChannel;

      final notifier = PendingToolCallApprovalNotifier(
        sessionId: sessionId,
        channel: projectConnectionState == LayerConnectionState.connected
            ? channel
            : null,
      );
      ref.onDispose(() {
        unawaited(notifier.close());
      });
      return notifier;
    });

class PendingToolCallApprovalNotifier
    extends StateNotifier<PendingToolCallList> {
  static final _log = Logger('PendingToolCallApprovalNotifier');

  final StateReplicationManager _stateReplicationManager =
      StateReplicationManager();
  StateReplicator<PendingToolCallList>? _replicator;
  void Function()? _removeListener;

  PendingToolCallApprovalNotifier({
    required String? sessionId,
    required MultiplexedWebSocketChannel? channel,
  }) : super(const PendingToolCallList([])) {
    if (sessionId == null || channel == null) {
      return;
    }

    _stateReplicationManager.registerChannel(channel);

    final replicator = _stateReplicationManager
        .createReplicator<PendingToolCallList>(
          sessionId: sessionId,
          decode: PendingToolCallList.decode,
          errorHandler: (error, stackTrace) {
            _log.warning(
              'Pending tool call replication error',
              error,
              stackTrace,
            );
          },
        );
    _replicator = replicator;
    _removeListener = replicator.onChanged((next, previous) {
      // null means no pending calls; keep the replicator alive for future rounds.
      state = next ?? const PendingToolCallList([]);
    });
  }

  Future<void> close() async {
    _removeListener?.call();
    _removeListener = null;
    final replicator = _replicator;
    _replicator = null;
    if (replicator != null) {
      await _stateReplicationManager.disposeReplicator<PendingToolCallList>(
        sessionId: replicator.sessionId,
        objectKind: replicator.objectKind,
        objectKey: replicator.objectKey,
      );
    }
    await _stateReplicationManager.dispose();
  }

  void update(
    PendingToolCallList Function(PendingToolCallList current) change,
  ) {
    _apply(change(state));
  }

  void toggleSelectAll(bool isSelected) {
    update((current) {
      return current.updateAll((item) => item.withSelected(isSelected));
    });
  }

  void setSelected(String toolCallId, bool isSelected) {
    update((current) {
      return current.updateById(
        toolCallId,
        (item) => item.withSelected(isSelected),
      );
    });
  }

  void setCommand(String toolCallId, String command) {
    update((current) {
      return current.updateById(
        toolCallId,
        (item) => item.withCommand(command),
      );
    });
  }

  void setSudoRequired(String toolCallId, bool sudoRequired) {
    update((current) {
      return current.updateById(
        toolCallId,
        (item) => item.withSudoRequired(sudoRequired),
      );
    });
  }

  void setSecrets(String toolCallId, Set<String> secrets) {
    update((current) {
      return current.updateById(
        toolCallId,
        (item) => item.withSecrets(secrets),
      );
    });
  }

  void approveSelected() {
    final approved = state.copyWith(items: state.selectedOnly);
    if (approved.items.isEmpty) {
      return;
    }

    final replicator = _replicator;
    if (replicator != null) {
      unawaited(replicator.optimisticClose(approved));
    }

    state = const PendingToolCallList([]);
  }

  void cancelApproval() {
    final replicator = _replicator;
    if (replicator != null) {
      unawaited(replicator.optimisticClose(const PendingToolCallList([])));
    }

    state = const PendingToolCallList([]);
  }

  void _apply(PendingToolCallList next) {
    final replicator = _replicator;
    if (replicator != null) {
      unawaited(replicator.optimisticUpdate(next));
      return;
    }

    state = next;
  }
}
