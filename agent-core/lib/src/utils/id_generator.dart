import 'dart:math';

/// Centralized ID generation utility.
///
/// Uses UUID v4-like format without external dependency.
/// Shared between client and server for consistent ID formats.
class IdGenerator {
  static final _random = Random.secure();

  /// Generate a random hex string of the given length
  static String _randomHex(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  /// Generate a unique project ID
  static String projectId() => 'proj_${_randomHex(32)}';

  /// Generate a unique session ID
  static String sessionId() => 'sess_${_randomHex(32)}';

  /// Generate a unique message ID
  static String messageId() => 'msg_${_randomHex(32)}';

  /// Generate a unique snippet ID
  static String snippetId() => 'snip_${_randomHex(32)}';

  /// Generate a unique secret ID
  static String secretId() => 'sec_${_randomHex(32)}';
}
