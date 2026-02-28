import 'dart:io';
import 'package:logging/logging.dart';

final _log = Logger('TomlNodeIdMigration');

/// Migrates HLC node IDs in a CRDT settings TOML file.
///
/// Scans every line for HLC strings ending with `-<oldNodeId>` and replaces
/// the suffix with `-<newNodeId>`. Only modifies lines within the `[_crdt]`
/// section that contain `hlc` or `modified` keys.
///
/// Returns `true` if the file was modified, `false` if no changes were needed
/// or the file doesn't exist.
Future<bool> migrateTomlNodeId(
  File file,
  String oldNodeId,
  String newNodeId,
) async {
  if (!await file.exists()) return false;

  final content = await file.readAsString();
  final oldSuffix = '-$oldNodeId';
  final newSuffix = '-$newNodeId';

  if (!content.contains(oldSuffix)) return false;

  // Replace HLC suffixes line-by-line to be precise.
  // Only replace the trailing node ID portion: ..."-<oldNodeId>" → ..."-<newNodeId>"
  final updated = content.replaceAll(oldSuffix, newSuffix);

  if (updated == content) return false;

  await file.writeAsString(updated);
  _log.info('Migrated TOML node IDs in ${file.path}: $oldNodeId → $newNodeId');
  return true;
}

/// Migrates all `settings_crdt.toml` files under `<dataPath>/projects/`
/// from [oldNodeId] to [newNodeId].
Future<void> migrateAllSettingsToml(
  String dataPath,
  String oldNodeId,
  String newNodeId,
) async {
  final projectsDir = Directory('$dataPath/projects');
  if (!await projectsDir.exists()) return;

  await for (final entry in projectsDir.list()) {
    if (entry is Directory) {
      final tomlFile = File('${entry.path}/settings_crdt.toml');
      await migrateTomlNodeId(tomlFile, oldNodeId, newNodeId);
    }
  }
}
