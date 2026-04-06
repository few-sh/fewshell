import 'session_replication_envelope.dart';

/// Encodes and decodes one concrete replicated object payload type.
///
/// The generic replication layer only understands envelopes and revision
/// handling. Domain-specific state, such as pending tool calls, is introduced
/// by implementing this codec.
abstract class SessionReplicatedCodec<TState> {
  /// Converts an envelope payload into a typed state value.
  TState decodePayload(JsonMap payload);

  /// Converts a typed state value back into an envelope payload.
  JsonMap encodePayload(TState state);
}
