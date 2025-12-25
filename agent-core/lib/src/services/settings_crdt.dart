import 'dart:async';
import 'dart:io';
import 'package:crdt/crdt.dart';
import 'package:crdt/map_crdt.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';
import 'package:agent_core/src/utils/map_utils.dart';
import 'package:agent_core/src/utils/settings_flattener.dart';

class SettingsCrdt extends MapCrdt {
  static final _log = Logger('SettingsCrdt');
  final File _file;
  Timer? _saveTimer;
  final StreamController<void> _changeController = StreamController.broadcast();

  SettingsCrdt(this._file) : super(['settings']);

  Stream<void> get onChange => _changeController.stream;

  Map<String, dynamic> getAll() {
    final changeset = getChangeset();
    final records = changeset['settings'] ?? [];
    final result = <String, dynamic>{};
    for (final record in records) {
      if (record['is_deleted'] != true) {
        result[record['key'] as String] = record['value'];
      }
    }
    return result;
  }

  static Future<SettingsCrdt> load(Directory dir, String filename) async {
    final file = File(p.join(dir.path, filename));
    final crdt = SettingsCrdt(file);
    await crdt._load();
    return crdt;
  }

  Future<void> _load() async {
    if (await _file.exists()) {
      try {
        final content = await _file.readAsString();
        if (content.isNotEmpty) {
          final toml = TomlDocument.parse(content).toMap();

          final crdtData = toml['_crdt'] as Map<String, dynamic>? ?? {};
          final data = Map<String, dynamic>.from(toml)..remove('_crdt');

          final flatData = SettingsFlattener.flatten(data);
          final records = <Map<String, Object?>>[];

          // Process existing data
          for (final entry in flatData.entries) {
            final key = entry.key;
            final value = entry.value;
            final metadata = crdtData[key] as Map<String, dynamic>?;

            records.add({
              'key': key,
              'value': value,
              'hlc': metadata?['hlc'] ?? Hlc.zero(nodeId).toString(),
              'is_deleted': false,
              'modified':
                  metadata?['modified'] ?? DateTime.now().toIso8601String(),
            });
          }

          // Process deleted data
          for (final entry in crdtData.entries) {
            final key = entry.key;
            if (!flatData.containsKey(key)) {
              final metadata = entry.value as Map<String, dynamic>;
              if (metadata['is_deleted'] == true) {
                records.add({
                  'key': key,
                  'value': null,
                  'hlc': metadata['hlc'],
                  'is_deleted': true,
                  'modified': metadata['modified'],
                });
              }
            }
          }

          await super.merge({'settings': records});
        }
      } catch (e) {
        _log.warning('Error loading settings CRDT: $e');
      }
    }
  }

  @override
  Future<void> put(String table, String key, dynamic value,
      [bool isDeleted = false]) async {
    await super.put(table, key, value, isDeleted);
    _scheduleSave();
    _changeController.add(null);
  }

  @override
  Future<void> merge(Map<String, List<Map<String, Object?>>> changeset) async {
    await super.merge(changeset);
    _scheduleSave();
    _changeController.add(null);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    try {
      final changeset = getChangeset();
      final records = changeset['settings'] ?? [];

      final flatData = <String, dynamic>{};
      final crdtData = <String, dynamic>{};

      for (final record in records) {
        final key = record['key'] as String;
        final value = record['value'];
        final hlc = record['hlc'];
        final isDeleted = record['is_deleted'] as bool? ?? false;

        if (!isDeleted) {
          flatData[key] = value;
        }

        crdtData[key] = {
          'hlc': hlc.toString(),
          'is_deleted': isDeleted,
          'modified': record['modified'],
        };
      }

      final data = SettingsFlattener.unflatten(flatData);
      data['_crdt'] = crdtData;

      final cleanMap = removeNullsFromMap(data);
      final toml = TomlDocument.fromMap(cleanMap).toString();
      await _file.writeAsString(toml);
    } catch (e) {
      _log.severe('Error saving settings CRDT: $e');
    }
  }

  Future<void> close() async {
    _saveTimer?.cancel();
    await _save();
  }
}
