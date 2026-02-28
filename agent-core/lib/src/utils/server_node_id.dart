import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

final _log = Logger('ServerNodeId');

/// Regex for validating server node ID format: `srv_<uuid-v4>`.
final nodeIdPattern = RegExp(
  r'^srv_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Whether [value] is a valid server node ID (`srv_<uuid-v4>`).
bool isValidNodeId(String value) => nodeIdPattern.hasMatch(value);

/// Generates a new server node ID: `srv_<uuid-v4>`.
String generateServerNodeId() => 'srv_${const Uuid().v4()}';

/// Reads or generates the server node ID from `<dataPath>/node_id`.
///
/// If the file doesn't exist, generates a new ID, writes it with `0600`
/// permissions, and returns it. If the file exists, reads and validates it.
///
/// Throws [FormatException] if the existing file contains an invalid ID.
Future<String> readOrCreateNodeId(String dataPath) async {
  final file = File(p.join(dataPath, 'node_id'));

  if (await file.exists()) {
    final content = (await file.readAsString()).trim();
    if (!isValidNodeId(content)) {
      throw FormatException(
        'Invalid node ID in ${file.path}: "$content" '
        '(expected format: srv_<uuid-v4>)',
      );
    }
    _log.info('Read server node ID from ${file.path}: $content');
    return content;
  }

  final nodeId = generateServerNodeId();
  await file.parent.create(recursive: true);
  await file.writeAsString(nodeId);

  // Set file permissions to 0600 (owner-only read/write).
  // This is a POSIX-only call; on non-POSIX platforms it's a no-op.
  try {
    await Process.run('chmod', ['600', file.path]);
  } catch (_) {
    // Ignore on platforms that don't support chmod
  }

  _log.info('Generated new server node ID: $nodeId → ${file.path}');
  return nodeId;
}
