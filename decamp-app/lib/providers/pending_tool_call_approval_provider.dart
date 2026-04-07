import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:agent_core/session_replication.dart';
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
  SessionReplicator<PendingToolCallList>? _replicator;
  void Function()? _removeListener;

  PendingToolCallApprovalNotifier(this._binding)
    : super(_binding.initialState) {
    final channel = _binding.channel;
    if (channel == null) {
      return;
    }

    final replicator = SessionReplicator<PendingToolCallList>.forChannel(
      sessionId: _binding.sessionId,
      objectKind: _objectKind,
      objectKey: _objectKey,
      decode: PendingToolCallList.fromJson,
      channel: channel,
      errorHandler: (error, stackTrace) {
        _log.warning('Pending tool call replication error', error, stackTrace);
      },
    );
    _replicator = replicator;
    _removeListener = replicator.onChanged((next, previous) {
      if (next != null) {
        state = next;
      }
    });

    unawaited(
      replicator.attach(
        channel.onCustomMessage
            .where(
              (message) =>
                  message['type'] == SessionReplicatedEnvelope.messageType,
            )
            .map(SessionReplicatedEnvelope.fromJson),
      ),
    );
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

  void toggleSelectAll(bool isSelected) {
    _apply(
      state.copyWith(
        items: state.items
            .map((item) => item.copyWith(isSelected: isSelected))
            .toList(),
      ),
    );
  }

  void setSelected(String toolCallId, bool isSelected) {
    _apply(
      state.copyWith(
        items: state.items
            .map(
              (item) => item.id == toolCallId
                  ? item.copyWith(isSelected: isSelected)
                  : item,
            )
            .toList(),
      ),
    );
  }

  void setCommand(String toolCallId, String command) {
    _apply(
      state.copyWith(
        items: state.items
            .map(
              (item) => item.id == toolCallId
                  ? item.copyWith(
                      arguments: {...item.arguments, 'command': command},
                    )
                  : item,
            )
            .toList(),
      ),
    );
  }

  void setSudoRequired(String toolCallId, bool sudoRequired) {
    _apply(
      state.copyWith(
        items: state.items
            .map(
              (item) => item.id == toolCallId
                  ? item.copyWith(
                      arguments: {
                        ...item.arguments,
                        'sudo_required': sudoRequired,
                      },
                    )
                  : item,
            )
            .toList(),
      ),
    );
  }

  void setSecrets(String toolCallId, Set<String> secrets) {
    _apply(
      state.copyWith(
        items: state.items
            .map(
              (item) => item.id == toolCallId
                  ? item.copyWith(
                      arguments: {
                        ...item.arguments,
                        'secrets': secrets.toList(),
                      },
                    )
                  : item,
            )
            .toList(),
      ),
    );
  }

  void _apply(PendingToolCallList next) {
    state = next;
    final replicator = _replicator;
    if (replicator != null) {
      unawaited(replicator.update(next));
    }
  }
}
