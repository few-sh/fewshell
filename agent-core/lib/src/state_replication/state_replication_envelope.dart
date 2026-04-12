/// Convenience alias used by the replication layer for JSON-like payload maps.
typedef JsonMap = Map<String, dynamic>;

/// The high-level operation represented by a replicated-state envelope.
///
/// These actions intentionally describe lifecycle and synchronization intent at
/// the envelope level, not domain-specific behavior. That keeps the outer wire
/// format generic while allowing each replicated object kind to decide how to
/// interpret the payload.
enum StateReplicatedAction {
  /// A canonical snapshot broadcast from the authoritative source of truth.
  snapshot,

  /// A client or peer-proposed state change for an existing object.
  update,

  /// A request to finalize the current canonical state.
  commit,

  /// A request to abandon the current object interaction.
  cancel,

  /// A terminal notification telling clients the object is no longer active.
  closed;

  /// Parses an action name received from the wire format.
  static StateReplicatedAction fromWireValue(String value) {
    return StateReplicatedAction.values.firstWhere(
      (candidate) => candidate.name == value,
      orElse: () => throw FormatException(
        'Unknown session replicated action: $value',
      ),
    );
  }
}

/// Identifies a replicated object instance within a session.
///
/// `objectKind` names the category of replicated state, such as
/// `pending_tool_calls`. `objectKey` distinguishes multiple instances of the
/// same category if a session ever needs more than one.
class StateReplicatedObjectRef {
  /// The category of replicated object, for example `pending_tool_calls`.
  final String objectKind;

  /// The unique object identity within the session for the given kind.
  final String objectKey;

  const StateReplicatedObjectRef({
    required this.objectKind,
    required this.objectKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'objectKind': objectKind,
      'objectKey': objectKey,
    };
  }
}

/// The generic custom-message envelope used for session-scoped replication.
///
/// This is the stable outer protocol shared by client and server. The server is
/// expected to remain authoritative over the canonical object state, while
/// clients receive snapshots and submit intents back using the same shape.
///
/// The payload is intentionally untyped here. Concrete object kinds provide
/// their own codecs on top of this envelope so the outer protocol can remain
/// reusable.
class StateReplicatedEnvelope {
  /// The custom message type placed on the multiplexed WebSocket channel.
  static const String messageType = 'replicated_state';

  /// The owning agent session for this replicated object instance.
  final String sessionId;

  /// The category of replicated object carried by this envelope.
  final String objectKind;

  /// The unique key of the replicated object within the session.
  final String objectKey;

  /// Monotonically increasing version assigned by the authoritative source.
  final int revision;

  /// The operation represented by this envelope.
  final StateReplicatedAction action;

  /// Object-specific data encoded as a JSON-compatible map.
  ///
  /// This contains the domain payload for the replicated object. The outer
  /// envelope stays generic while codecs interpret this map as typed state.
  final JsonMap? payload;

  const StateReplicatedEnvelope({
    required this.sessionId,
    required this.objectKind,
    required this.objectKey,
    required this.revision,
    required this.action,
    this.payload,
  });

  /// Returns the object identity portion of this envelope.
  StateReplicatedObjectRef get objectRef {
    return StateReplicatedObjectRef(
      objectKind: objectKind,
      objectKey: objectKey,
    );
  }

  /// Returns true when this envelope belongs to the requested session object.
  bool matchesObject({
    required String sessionId,
    required String objectKind,
    required String objectKey,
  }) {
    return this.sessionId == sessionId &&
        this.objectKind == objectKind &&
        this.objectKey == objectKey;
  }

  /// Creates a new envelope by replacing selected fields.
  StateReplicatedEnvelope copyWith({
    String? sessionId,
    String? objectKind,
    String? objectKey,
    int? revision,
    StateReplicatedAction? action,
    JsonMap? payload,
  }) {
    return StateReplicatedEnvelope(
      sessionId: sessionId ?? this.sessionId,
      objectKind: objectKind ?? this.objectKind,
      objectKey: objectKey ?? this.objectKey,
      revision: revision ?? this.revision,
      action: action ?? this.action,
      payload: payload,
    );
  }

  /// Serializes this envelope to the custom message wire format.
  Map<String, dynamic> toJson() {
    return {
      'type': messageType,
      'sessionId': sessionId,
      'objectKind': objectKind,
      'objectKey': objectKey,
      'revision': revision,
      'action': action.name,
      'payload': payload,
    };
  }

  /// Deserializes an envelope from the custom message wire format.
  factory StateReplicatedEnvelope.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type != messageType) {
      throw FormatException(
        'Expected type $messageType but received ${type ?? 'null'}',
      );
    }

    final rawPayload = json['payload'];
    final JsonMap? payload;
    if (rawPayload == null) {
      payload = null;
    } else if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    } else {
      payload = null;
    }

    return StateReplicatedEnvelope(
      sessionId: json['sessionId'] as String,
      objectKind: json['objectKind'] as String,
      objectKey: json['objectKey'] as String,
      revision: json['revision'] as int,
      action: StateReplicatedAction.fromWireValue(
        json['action'] as String,
      ),
      payload: payload,
    );
  }
}
