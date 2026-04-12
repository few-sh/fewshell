import 'dart:async';

import '../utils/multiplexed_websocket_channel.dart';
import 'state_replication_envelope.dart';
import 'state_replicator.dart';

/// Coordinates replicated objects and channel lifecycle for one runtime scope.
///
/// The manager centralizes boilerplate for:
/// - registering/unregistering channels
/// - creating and disposing replicators
/// - attaching active channels to newly created replicators
class StateReplicationManager {
  final Set<MultiplexedWebSocketChannel> _channels = {};
  final Map<String, StateReplicator<dynamic>> _replicators = {};

  /// Registers a channel and attaches it to all active replicators.
  void registerChannel(MultiplexedWebSocketChannel channel) {
    if (!_channels.add(channel)) {
      return;
    }

    for (final replicator in _replicators.values) {
      replicator.attachChannel(channel);
    }
  }

  /// Unregisters a channel and detaches it from all active replicators.
  Future<void> unregisterChannel(MultiplexedWebSocketChannel channel) async {
    if (!_channels.remove(channel)) {
      return;
    }

    for (final replicator in _replicators.values) {
      await replicator.detachChannel(channel);
    }
  }

  /// Creates and registers a replicator for the provided object identity.
  ///
  /// Throws [StateError] if a replicator with the same key already exists.
  StateReplicator<TState> createReplicator<TState extends ReplicatedState>({
    required String sessionId,
    String? objectKind,
    String objectKey = StateReplicator.defaultObjectKey,
    required StateReplicatedDecoder<TState> decode,
    TState? initialState,
    int initialRevision = 0,
    StateReplicatedAction initialAction = StateReplicatedAction.snapshot,
    void Function(Object error, StackTrace stackTrace)? errorHandler,
  }) {
    final key = _buildKey(
      sessionId: sessionId,
      objectKind: objectKind ?? StateReplicator.defaultObjectKindFor<TState>(),
      objectKey: objectKey,
    );

    if (_replicators.containsKey(key)) {
      throw StateError('Replicator already exists for key: $key');
    }

    final replicator = StateReplicator<TState>(
      sessionId: sessionId,
      objectKind: objectKind,
      objectKey: objectKey,
      decode: decode,
      initialState: initialState,
      initialRevision: initialRevision,
      initialAction: initialAction,
      errorHandler: errorHandler,
    );

    for (final channel in _channels) {
      replicator.attachChannel(channel);
    }

    _replicators[key] = replicator;
    return replicator;
  }

  StateReplicator<TState>? getReplicator<TState extends ReplicatedState>({
    required String sessionId,
    String? objectKind,
    String objectKey = StateReplicator.defaultObjectKey,
  }) {
    final key = _buildKey(
      sessionId: sessionId,
      objectKind: objectKind ?? StateReplicator.defaultObjectKindFor<TState>(),
      objectKey: objectKey,
    );

    final replicator = _replicators[key];
    if (replicator == null) {
      return null;
    }

    return replicator as StateReplicator<TState>;
  }

  Future<void> disposeReplicator<TState extends ReplicatedState>({
    required String sessionId,
    String? objectKind,
    String objectKey = StateReplicator.defaultObjectKey,
  }) async {
    final key = _buildKey(
      sessionId: sessionId,
      objectKind: objectKind ?? StateReplicator.defaultObjectKindFor<TState>(),
      objectKey: objectKey,
    );

    final replicator = _replicators.remove(key);
    if (replicator != null) {
      await replicator.dispose();
    }
  }

  Future<void> dispose() async {
    for (final replicator in _replicators.values) {
      await replicator.dispose();
    }
    _replicators.clear();
    _channels.clear();
  }

  String _buildKey({
    required String sessionId,
    required String objectKind,
    required String objectKey,
  }) {
    return '$sessionId::$objectKind::$objectKey';
  }
}
