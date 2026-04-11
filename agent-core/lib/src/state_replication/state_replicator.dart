import 'dart:async';

import '../utils/multiplexed_websocket_channel.dart';
import 'state_replication_envelope.dart';

/// Callback signature for high-level replicated value changes.
typedef StateReplicatedValueListener<TState> = void Function(
  TState? next,
  TState? previous,
);

/// Contract for state objects that can be carried by the replication envelope.
abstract interface class ReplicatedState {
  /// Serializes the state into the JSON payload carried by the envelope.
  JsonMap toJson();
}

/// Recreates a typed replicated object from an envelope payload.
typedef StateReplicatedDecoder<TState> = TState Function(JsonMap payload);

/// Callback used to send envelopes to the remote peer or peers.
typedef StateReplicatedEnvelopeSender = FutureOr<void> Function(
  StateReplicatedEnvelope envelope,
);

/// A simple, transport-driven replicated object controller.
///
/// This is the intended low-level primitive for both client and server code.
/// It is deliberately not tied to Riverpod. Callers attach it to an inbound
/// envelope stream, register `onChanged` listeners, and call `update()` or
/// `sendAction()` to participate in replication.
///
/// The replicated business object itself stays free of replication metadata.
/// State id, object kind, object key, revision, and action all live in this
/// container and in the outer envelope.
class StateReplicator<TState extends ReplicatedState> {
  /// The state this replicator instance is scoped to.
  final String sessionId;

  /// The replicated object category this instance tracks.
  final String objectKind;

  /// The replicated object identity within the session.
  final String objectKey;

  /// Recreates a typed value from the payload carried by the envelope.
  final StateReplicatedDecoder<TState> decode;

  /// Outbound envelope sender used for two-way communication.
  final StateReplicatedEnvelopeSender sendEnvelope;

  /// Optional observer for stream and send failures.
  final void Function(Object error, StackTrace stackTrace)? errorHandler;

  /// Registered high-level value listeners added via [onChanged].
  final List<StateReplicatedValueListener<TState>> _listeners = [];

  /// Active subscription to the inbound envelope stream passed to [attach].
  StreamSubscription<StateReplicatedEnvelope>? _subscription;

  /// The latest accepted canonical envelope.
  StateReplicatedEnvelope? _currentEnvelope;

  /// The latest decoded canonical state.
  TState? _currentState;

  /// Whether the replicator is currently subscribed to inbound updates.
  bool isAttached = false;

  /// Whether an outbound message is currently being sent.
  bool isSubmitting = false;

  /// The last error observed by the replicator.
  Object? error;

  StateReplicator({
    required this.sessionId,
    required this.objectKind,
    required this.objectKey,
    required this.decode,
    required this.sendEnvelope,
    TState? initialState,
    int initialRevision = 0,
    StateReplicatedAction initialAction = StateReplicatedAction.snapshot,
    this.errorHandler,
  }) {
    if (initialState != null) {
      _currentEnvelope = StateReplicatedEnvelope(
        sessionId: sessionId,
        objectKind: objectKind,
        objectKey: objectKey,
        revision: initialRevision,
        action: initialAction,
        payload: initialState.toJson(),
      );
      _currentState = initialState;
    }
  }

  /// Convenience factory for the common case of using one multiplexed channel.
  factory StateReplicator.forChannel({
    required String sessionId,
    required String objectKind,
    required String objectKey,
    required StateReplicatedDecoder<TState> decode,
    required MultiplexedWebSocketChannel channel,
    TState? initialState,
    int initialRevision = 0,
    StateReplicatedAction initialAction = StateReplicatedAction.snapshot,
    void Function(Object error, StackTrace stackTrace)? errorHandler,
  }) {
    return StateReplicator<TState>(
      sessionId: sessionId,
      objectKind: objectKind,
      objectKey: objectKey,
      decode: decode,
      sendEnvelope: (envelope) => channel.sendCustomMessage(envelope.toJson()),
      initialState: initialState,
      initialRevision: initialRevision,
      initialAction: initialAction,
      errorHandler: errorHandler,
    );
  }

  /// The latest decoded canonical value, if one has been received.
  TState? get current => _currentState;

  /// The latest accepted revision, if any.
  int? get revision => _currentEnvelope?.revision;

  /// Whether a canonical value has been received.
  bool get hasCurrent => _currentState != null;

  /// The latest accepted envelope together with replication metadata.
  StateReplicatedEnvelope? get currentEnvelope => _currentEnvelope;

  /// Starts listening to an inbound stream of envelopes.
  Future<void> attach(Stream<StateReplicatedEnvelope> envelopes) async {
    if (_subscription != null) {
      return;
    }

    isAttached = true;
    error = null;
    _subscription =
        envelopes.listen(_applyEnvelope, onError: _handleStreamError);
  }

  /// Convenience helper for attaching directly to a multiplexed channel.
  Future<void> attachToChannel(MultiplexedWebSocketChannel channel) {
    return attach(
      channel.onCustomMessage
          .where(
            (message) => message['type'] == StateReplicatedEnvelope.messageType,
          )
          .map(StateReplicatedEnvelope.fromJson),
    );
  }

  /// Stops listening to inbound envelopes.
  Future<void> detach() async {
    await _subscription?.cancel();
    _subscription = null;
    isAttached = false;
    isSubmitting = false;
  }

  /// Registers a high-level value listener.
  ///
  /// The callback receives the new canonical value and the previous value.
  /// Returns a function that removes the listener.
  void Function() onChanged(
    StateReplicatedValueListener<TState> listener, {
    bool fireImmediately = false,
  }) {
    _listeners.add(listener);
    if (fireImmediately) {
      listener(current, null);
    }

    return () {
      _listeners.remove(listener);
    };
  }

  /// Submits a typed state update using the standard update action.
  Future<void> update(TState next) async {
    await submit(next, action: StateReplicatedAction.update);
  }

  /// Updates local current state immediately and then sends the envelope.
  Future<void> optimisticUpdate(
    TState next, {
    StateReplicatedAction action = StateReplicatedAction.update,
  }) async {
    final envelope = _createNextEnvelope(
      action: action,
      payload: next.toJson(),
    );
    _setCurrent(
      next,
      revision: envelope.revision,
      action: envelope.action,
      sessionId: envelope.sessionId,
      objectKind: envelope.objectKind,
      objectKey: envelope.objectKey,
    );
    await _send(envelope);
  }

  /// Applies a transformation to the current value and submits the result.
  Future<void> updateWith(TState Function(TState current) transform) async {
    final currentState = current;
    if (currentState == null) {
      throw StateError(
        'Cannot update replicated object before a canonical value exists.',
      );
    }

    await update(transform(currentState));
  }

  /// Applies a transformation locally first and then sends the result.
  Future<void> optimisticUpdateWith(
    TState Function(TState current) transform,
  ) async {
    final currentState = current;
    if (currentState == null) {
      throw StateError(
        'Cannot update replicated object before a canonical value exists.',
      );
    }

    await optimisticUpdate(transform(currentState));
  }

  /// Submits a typed state update with a caller-provided envelope action.
  Future<void> submit(
    TState next, {
    StateReplicatedAction action = StateReplicatedAction.update,
  }) async {
    await _send(
      _createNextEnvelope(
        action: action,
        payload: next.toJson(),
      ),
    );
  }

  /// Sends an action that does not require a typed state payload.
  Future<void> sendAction(
    StateReplicatedAction action, {
    JsonMap payload = const {},
  }) async {
    await _send(
      _createNextEnvelope(
        action: action,
        payload: payload,
      ),
    );
  }

  /// Accepts an inbound envelope if it matches this object and is not stale.
  bool applyEnvelope(StateReplicatedEnvelope envelope) {
    if (!envelope.matchesObject(
      sessionId: sessionId,
      objectKind: objectKind,
      objectKey: objectKey,
    )) {
      return false;
    }

    return _applyEnvelope(envelope);
  }

  /// Parses and applies a raw custom message when it is a matching envelope.
  bool tryApplyMessage(Map<String, dynamic> message) {
    if (message['type'] != StateReplicatedEnvelope.messageType) {
      return false;
    }

    final envelope = StateReplicatedEnvelope.fromJson(message);
    if (!envelope.matchesObject(
      sessionId: sessionId,
      objectKind: objectKind,
      objectKey: objectKey,
    )) {
      return false;
    }

    return _applyEnvelope(envelope);
  }

  /// Re-sends the current value using the provided action.
  Future<void> syncCurrent({
    StateReplicatedAction action = StateReplicatedAction.snapshot,
  }) async {
    final envelope = currentEnvelope;
    if (envelope == null || current == null) {
      return;
    }

    await _send(envelope.copyWith(action: action));
  }

  bool _applyEnvelope(StateReplicatedEnvelope envelope) {
    final currentRevision = revision;

    if (currentRevision != null && envelope.revision <= currentRevision) {
      return false;
    }

    if (envelope.action == StateReplicatedAction.closed) {
      final previous = _currentState;
      _currentEnvelope = envelope;
      _currentState = null;
      isSubmitting = false;
      error = null;
      _notifyListeners(null, previous);
      return true;
    }

    final decoded = decode(envelope.payload);
    _setCurrent(
      decoded,
      revision: envelope.revision,
      action: envelope.action,
      sessionId: envelope.sessionId,
      objectKind: envelope.objectKind,
      objectKey: envelope.objectKey,
    );
    isSubmitting = false;
    error = null;
    return true;
  }

  void _setCurrent(
    TState next, {
    required int revision,
    required StateReplicatedAction action,
    String? sessionId,
    String? objectKind,
    String? objectKey,
  }) {
    final previous = current;
    _currentEnvelope = StateReplicatedEnvelope(
      sessionId: sessionId ?? this.sessionId,
      objectKind: objectKind ?? this.objectKind,
      objectKey: objectKey ?? this.objectKey,
      revision: revision,
      action: action,
      payload: next.toJson(),
    );
    _currentState = next;
    _notifyListeners(next, previous);
  }

  Future<void> _send(StateReplicatedEnvelope envelope) async {
    isSubmitting = true;
    error = null;
    try {
      await sendEnvelope(envelope);
      isSubmitting = false;
    } catch (err, stackTrace) {
      isSubmitting = false;
      error = err;
      errorHandler?.call(err, stackTrace);
      rethrow;
    }
  }

  void _handleStreamError(Object err, StackTrace stackTrace) {
    final subscription = _subscription;
    _subscription = null;
    error = err;
    isAttached = false;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    errorHandler?.call(err, stackTrace);
  }

  int _nextRevision() {
    final currentRevision = revision;
    if (currentRevision == null) {
      return 0;
    }
    return currentRevision + 1;
  }

  StateReplicatedEnvelope _createNextEnvelope({
    required StateReplicatedAction action,
    required JsonMap payload,
  }) {
    return StateReplicatedEnvelope(
      sessionId: sessionId,
      objectKind: objectKind,
      objectKey: objectKey,
      revision: _nextRevision(),
      action: action,
      payload: payload,
    );
  }

  void _notifyListeners(TState? next, TState? previous) {
    for (final listener in List.of(_listeners)) {
      listener(next, previous);
    }
  }

  /// Releases any active stream subscription and local listeners.
  Future<void> dispose() async {
    await detach();
    _listeners.clear();
  }
}
