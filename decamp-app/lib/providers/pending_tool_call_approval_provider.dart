import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

class PendingToolCallApprovalBinding {
  final String sessionId;
  final PendingToolCallList initialState;
  final MultiplexedWebSocketChannel? channel;

  const PendingToolCallApprovalBinding({
    required this.sessionId,
    required this.initialState,
    required this.channel,
  });
}

final pendingToolCallApprovalBindingProvider =
    Provider<PendingToolCallApprovalBinding>((ref) {
      throw UnimplementedError(
        'pendingToolCallApprovalBindingProvider must be overridden',
      );
    });

final pendingToolCallApprovalProvider =
    StateNotifierProvider.autoDispose<
      PendingToolCallApprovalNotifier,
      PendingToolCallList
    >((ref) {
      final binding = ref.watch(pendingToolCallApprovalBindingProvider);
      final notifier = PendingToolCallApprovalNotifier(binding);
      ref.onDispose(() {
        unawaited(notifier.close());
      });
      return notifier;
    }, dependencies: [pendingToolCallApprovalBindingProvider]);

class PendingToolCallApprovalNotifier
    extends StateNotifier<PendingToolCallList> {
  static final _log = Logger('PendingToolCallApprovalNotifier');
  static const _objectKind = 'pending_tool_calls';
  static const _objectKey = 'active';

  final PendingToolCallApprovalBinding _binding;
  StateReplicator<PendingToolCallList>? _replicator;
  void Function()? _removeListener;

  PendingToolCallApprovalNotifier(this._binding)
    : super(_binding.initialState) {
    final channel = _binding.channel;
    if (channel == null) {
      return;
    }

    final replicator = StateReplicator<PendingToolCallList>.forChannel(
      sessionId: _binding.sessionId,
      objectKind: _objectKind,
      objectKey: _objectKey,
      decode: PendingToolCallList.fromJson,
      channel: channel,
      initialState: _binding.initialState,
      errorHandler: (error, stackTrace) {
        _log.warning('Pending tool call replication error', error, stackTrace);
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
      await replicator.dispose();
    }
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
