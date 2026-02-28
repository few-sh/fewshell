import 'package:logging/logging.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';

final _log = Logger('NodeIdMigration');

/// Migrates all CRDT records to a new node ID by "touching" every row.
///
/// Sets the canonical time to the new node ID, then performs a no-op
/// UPDATE on every table. The CRDT layer's interceptor automatically stamps
/// each row with new hlc/node_id/modified values using the new node ID.
///
/// This is safe because:
/// - Uses the normal CRDT write path (no raw SQL hacks)
/// - No substring replacement — immune to node ID collision issues
/// - Records get newer timestamps, so they appear in changesets and replicate
///
/// Returns `true` if migration was performed, `false` if already up-to-date.
Future<bool> migrateNodeId(SqliteCrdt crdt, String newNodeId) async {
  if (crdt.nodeId == newNodeId) return false;

  final oldNodeId = crdt.nodeId;
  _log.info('Migrating CRDT node ID: $oldNodeId → $newNodeId');

  // Set canonical time to use the new node ID. Subsequent CRDT writes
  // will stamp records with this node ID.
  // ignore: invalid_use_of_protected_member
  crdt.canonicalTime = crdt.canonicalTime.apply(nodeId: newNodeId);

  // Touch every row in every table. The no-op `SET is_deleted = is_deleted`
  // triggers the CRDT interceptor to rewrite hlc, node_id, and modified.
  for (final table in await crdt.getTables()) {
    await crdt.execute('UPDATE $table SET is_deleted = is_deleted');
  }

  _log.info('CRDT node ID migration complete');
  return true;
}
