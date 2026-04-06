import 'dart:async';

import '../utils/multiplexed_websocket_channel.dart';
import 'session_replicated_codec.dart';
import 'session_replication_envelope.dart';

/// Callback signature for high-level replicated value changes.
typedef SessionReplicatedValueListener<TState> = void Function(
  TState? next,
  TState? previous,
);

/// Callback used to send envelopes to the remote peer or peers.
typedef SessionReplicatedEnvelopeSender = FutureOr<void> Function(
  SessionReplicatedEnvelope envelope,
);

/// Lightweight snapshot of the currently known canonical state.
class SessionReplicatedValue<TState> {
  /// The owning session for this replicated value.
  final String sessionId;

  /// The category of replicated object represented by this value.
  final String objectKind;

  /// The unique object identity within the session.
  final String objectKey;

  /// The authoritative revision currently associated with this value.
  final int revision;

  /// The decoded object state.
  final TState state;

  /// The last envelope action that produced this value.
  final SessionReplicatedAction action;

  const SessionReplicatedValue({
    required this.sessionId,
    required this.objectKind,
    required this.objectKey,
    required this.revision,
    required this.state,
    required this.action,
  });
}

/// A simple, transport-driven replicated object controller.
///
/// This is the intended low-level primitive for both client and server code.
/// It is deliberately not tied to Riverpod. Callers attach it to an inbound
/// envelope stream, register `onChanged` listeners, and call `update()` or
/// `sendAction()` to participate in replication.
///
/// Riverpod can still wrap this class for UI consumption, but the core API is
/// plain Dart and can therefore be reused inside AgentSession as well.
class SessionReplicator<TState> {
  /// The session this replicator instance is scoped to.
  final String sessionId;

  /// The replicated object category this instance tracks.
  final String objectKind;

  /// The replicated object identity within the session.
  final String objectKey;

  /// Codec that converts between typed state and JSON payload maps.
  final SessionReplicatedCodec<TState> codec;

  /// Outbound envelope sender used for two-way communication.
  final SessionReplicatedEnvelopeSender sendEnvelope;

  /// Optional observer for stream and send failures.
  final void Function(Object error, StackTrace stackTrace)? errorHandler;

  /// Registered high-level value listeners added via [onChanged].
  ///
  /// These are local callbacks owned by this replicator instance. They are not
  /// tied to the transport itself. Whenever this replicator accepts a new
  /// canonical value, each listener is notified with the new and previous typed
  /// values.
  final List<SessionReplicatedValueListener<TState>> _listeners = [];

  /// Active subscription to the inbound envelope stream passed to [attach].
  ///
  /// This represents the transport-side connection for incoming replication
  /// events. In contrast to [_listeners], there is only one subscription,
  /// because the replicator consumes one stream of envelopes and then fans out
  /// accepted changes to any number of local listeners.
  StreamSubscription<SessionReplicatedEnvelope>? _subscription;

  /// The latest accepted canonical value together with replication metadata.
  ///
  /// This is the replicator's local cache of the authoritative state most
  /// recently received from the transport. It is what powers [current],
  /// [revision], and listener notifications.
  SessionReplicatedValue<TState>? _currentValue;

  /// Whether the replicator is currently subscribed to inbound updates.
  bool isAttached = false;

  /// Whether an outbound message is currently being sent.
  bool isSubmitting = false;

  /// The last error observed by the replicator.
  Object? error;

  SessionReplicator({
    required this.sessionId,
    required this.objectKind,
    required this.objectKey,
    required this.codec,
    required this.sendEnvelope,
    this.errorHandler,
  });

  /// Convenience factory for the common case of using one multiplexed channel.
  factory SessionReplicator.forChannel({
    required String sessionId,
    required String objectKind,
    required String objectKey,
    required SessionReplicatedCodec<TState> codec,
    required MultiplexedWebSocketChannel channel,
    void Function(Object error, StackTrace stackTrace)? errorHandler,
  }) {
    return SessionReplicator<TState>(
      sessionId: sessionId,
      objectKind: objectKind,
      objectKey: objectKey,
      codec: codec,
      sendEnvelope: (envelope) => channel.sendCustomMessage(envelope.toJson()),
      errorHandler: errorHandler,
    );
  }

  /// The latest decoded canonical value, if one has been received.
  TState? get current => _currentValue?.state;

  /// The latest accepted revision, if any.
  int? get revision => _currentValue?.revision;

  /// Whether a canonical value has been received.
  bool get hasCurrent => _currentValue != null;

  /// The latest accepted typed value together with its replication metadata.
  SessionReplicatedValue<TState>? get currentValue => _currentValue;

  /// Starts listening to an inbound stream of envelopes.
  Future<void> attach(Stream<SessionReplicatedEnvelope> envelopes) async {
    if (_subscription != null) {
      return;
    }

    isAttached = true;
    error = null;
    _subscription =
        envelopes.listen(_applyEnvelope, onError: _handleStreamError);
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
    SessionReplicatedValueListener<TState> listener, {
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
    await submit(next, action: SessionReplicatedAction.update);
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

  /// Submits a typed state update with a caller-provided envelope action.
  Future<void> submit(
    TState next, {
    SessionReplicatedAction action = SessionReplicatedAction.update,
  }) async {
    await _send(
      SessionReplicatedEnvelope(
        sessionId: sessionId,
        objectKind: objectKind,
        objectKey: objectKey,
        revision: revision ?? 0,
        action: action,
        payload: codec.encodePayload(next),
      ),
    );
  }

  /// Sends an action that does not require a typed state payload.
  Future<void> sendAction(
    SessionReplicatedAction action, {
    JsonMap payload = const {},
  }) async {
    await _send(
      SessionReplicatedEnvelope(
        sessionId: sessionId,
        objectKind: objectKind,
        objectKey: objectKey,
        revision: revision ?? 0,
        action: action,
        payload: payload,
      ),
    );
  }

  /// Accepts an inbound envelope if it matches this object and is not stale.
  void applyEnvelope(SessionReplicatedEnvelope envelope) {
    if (!envelope.matchesObject(
      sessionId: sessionId,
      objectKind: objectKind,
      objectKey: objectKey,
    )) {
      return;
    }

    _applyEnvelope(envelope);
  }

  void _applyEnvelope(SessionReplicatedEnvelope envelope) {
    final previous = current;
    final currentRevision = revision;

    if (currentRevision != null && envelope.revision < currentRevision) {
      return;
    }

    if (envelope.action == SessionReplicatedAction.closed) {
      _currentValue = null;
      isSubmitting = false;
      error = null;
      _notifyListeners(null, previous);
      return;
    }

    final decoded = codec.decodePayload(envelope.payload);
    _currentValue = SessionReplicatedValue<TState>(
      sessionId: envelope.sessionId,
      objectKind: envelope.objectKind,
      objectKey: envelope.objectKey,
      revision: envelope.revision,
      state: decoded,
      action: envelope.action,
    );
    isSubmitting = false;
    error = null;
    _notifyListeners(decoded, previous);
  }

  Future<void> _send(SessionReplicatedEnvelope envelope) async {
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
    error = err;
    isAttached = false;
    errorHandler?.call(err, stackTrace);
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
