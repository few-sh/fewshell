import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../services/sync_service.dart';
import 'providers.dart';

typedef PendingToolCallApprovalArgs = ({
  String sessionId,
  MultiplexedWebSocketChannel? channel,
});

final pendingToolCallApprovalProvider = StateNotifierProvider.autoDispose
    .family<
      PendingToolCallApprovalNotifier,
      PendingToolCallList,
      PendingToolCallApprovalArgs
    >((ref, args) {
      final notifier = PendingToolCallApprovalNotifier(args);
      ref.onDispose(() {
        unawaited(notifier.close());
      });
      return notifier;
    });

/// Eagerly initializes pending tool call replication for the active session.
/// This avoids missing early updates before the approval UI is shown.
final pendingToolCallApprovalBootstrapProvider = Provider<void>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  final projectConnectionState = ref.watch(
    connectionStateProvider.select((state) => state.project),
  );

  if (sessionId == null ||
      projectConnectionState != LayerConnectionState.connected) {
    return;
  }

  final channel = ref.read(syncServiceProvider).projectChannel;
  ref.watch(
    pendingToolCallApprovalProvider((sessionId: sessionId, channel: channel)),
  );
});

class PendingToolCallApprovalNotifier
    extends StateNotifier<PendingToolCallList> {
  static final _log = Logger('PendingToolCallApprovalNotifier');

  final StateReplicationManager _stateReplicationManager =
      StateReplicationManager();
  StateReplicator<PendingToolCallList>? _replicator;
  void Function()? _removeListener;

  PendingToolCallApprovalNotifier(PendingToolCallApprovalArgs args)
    : super(const PendingToolCallList([])) {
    final channel = args.channel;
    if (channel == null) {
      return;
    }

    _stateReplicationManager.registerChannel(channel);

    final replicator = _stateReplicationManager
        .createReplicator<PendingToolCallList>(
          sessionId: args.sessionId,
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
      if (next == null) {
        state = const PendingToolCallList([]);
        unawaited(close());
        return;
      }

      state = next;
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

  void _apply(PendingToolCallList next) {
    final replicator = _replicator;
    if (replicator != null) {
      unawaited(replicator.optimisticUpdate(next));
      return;
    }

    state = next;
  }
}
