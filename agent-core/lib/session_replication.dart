/// Shared protocol types for session-scoped replicated state.
///
/// This library is intentionally small and transport-agnostic. It defines the
/// envelope format that client and server can both understand when they want to
/// synchronize authoritative objects that live inside an AgentSession. The
/// first concrete use case is the pending tool call list, but the same message
/// shape is meant to support other replicated session objects later.
export 'src/session_replication/session_replicated_codec.dart';
export 'src/session_replication/session_replication_envelope.dart';
export 'src/session_replication/session_replicator.dart';
