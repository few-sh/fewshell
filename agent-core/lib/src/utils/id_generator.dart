import 'package:uuid/uuid.dart';

/// Centralized ID generation utility
/// Uses UUID v4 for proper randomness instead of timestamp-based IDs
class IdGenerator {
  static const _uuid = Uuid();

  /// Generate a unique project ID
  static String projectId() => 'proj_${_uuid.v4().replaceAll('-', '')}';

  /// Generate a unique session ID
  static String sessionId() => 'sess_${_uuid.v4().replaceAll('-', '')}';

  /// Generate a unique message ID
  static String messageId() => 'msg_${_uuid.v4().replaceAll('-', '')}';

  /// Generate a unique snippet ID
  static String snippetId() => 'snip_${_uuid.v4().replaceAll('-', '')}';

  /// Generate a unique tool call ID
  static String toolCallId() => 'call_${_uuid.v4().replaceAll('-', '')}';
}
