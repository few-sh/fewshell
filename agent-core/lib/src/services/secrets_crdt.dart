import 'dart:async';
import 'dart:convert';
import 'package:crdt/crdt.dart';
import 'package:crdt/map_crdt.dart';
import 'package:logging/logging.dart';
import 'package:agent_core/src/secrets_storage/secure_storage.dart';

class SecretsCrdt extends MapCrdt implements SecureStorage {
  static final _log = Logger('SecretsCrdt');
  final SecureStorage _storage;
  final StreamController<void> _changeController = StreamController.broadcast();
  late final Future<void> ready;

  SecretsCrdt(this._storage) : super(['secrets']) {
    ready = _load();
  }

  Stream<void> get onChange => _changeController.stream;

  Future<void> _load() async {
    try {
      _log.info('Loading secrets from storage...');
      final allSecrets = await _storage.readAll();
      _log.info('Found ${allSecrets.length} secrets in storage');
      final records = <Map<String, Object?>>[];

      for (final entry in allSecrets.entries) {
        try {
          final json = jsonDecode(entry.value) as Map<String, dynamic>;
          // Check if it looks like our CRDT format
          if (json.containsKey('hlc')) {
            records.add({
              'key': entry.key,
              'value': json['value'],
              'hlc': Hlc.parse(json['hlc']),
              'is_deleted': json['is_deleted'] ?? false,
              'modified': json['modified'] ?? DateTime.now().toIso8601String(),
            });
          } else {
            // Legacy format (just value)
            _log.info('Loading legacy secret: ${entry.key}');
            records.add({
              'key': entry.key,
              'value': entry.value, // The whole string is the value
              'hlc': Hlc.zero(nodeId),
              'is_deleted': false,
              'modified': DateTime.now().toIso8601String(),
            });
          }
        } catch (e) {
          // Not JSON, assume legacy string value
          _log.info('Loading legacy secret (parse error): ${entry.key}');
          records.add({
            'key': entry.key,
            'value': entry.value,
            'hlc': Hlc.zero(nodeId),
            'is_deleted': false,
            'modified': DateTime.now().toIso8601String(),
          });
        }
      }

      if (records.isNotEmpty) {
        await merge({'secrets': records});
        _log.info('Merged ${records.length} secrets into CRDT');
      }
    } catch (e) {
      _log.warning('Error loading secrets CRDT: $e');
    }
  }

  @override
  Future<void> put(String table, String key, dynamic value,
      [bool isDeleted = false]) async {
    _log.info('Putting secret: $key (deleted: $isDeleted)');
    await super.put(table, key, value, isDeleted);
    await _saveKey(key);
    _changeController.add(null);
  }

  @override
  Future<void> merge(Map<String, List<Map<String, Object?>>> changeset) async {
    await super.merge(changeset);
    final records = changeset['secrets'] ?? [];
    _log.info('Merging ${records.length} secrets');
    for (final record in records) {
      await _saveKey(record['key'] as String);
    }
    _changeController.add(null);
  }

  Future<void> _saveKey(String key) async {
    try {
      final record = getRecord('secrets', key);
      if (record != null) {
        final value = record.value;
        final hlc = record.hlc;
        final isDeleted = record.isDeleted;
        final modified = record.modified;

        final json = jsonEncode({
          'value': value,
          'hlc': hlc.toString(),
          'is_deleted': isDeleted,
          'modified': modified,
        });

        await _storage.write(key: key, value: json);
        _log.info('Saved secret: $key');
      } else {
        _log.warning('Record not found for key: $key');
      }
    } catch (e) {
      _log.severe('Error saving secrets CRDT: $e');
    }
  }

  // SecureStorage implementation

  @override
  Future<void> write({required String key, required String value}) async {
    await ready;
    await put('secrets', key, value);
  }

  @override
  Future<String?> read({required String key}) async {
    await ready;
    final value = super.get('secrets', key);
    _log.info('Read secret $key: ${value != null ? 'found' : 'not found'}');
    return value as String?;
  }

  @override
  Future<void> delete({required String key}) async {
    await ready;
    await put('secrets', key, null, true);
  }

  @override
  Future<Map<String, String>> readAll() async {
    await ready;
    final changeset = getChangeset();
    final records = changeset['secrets'] ?? [];
    final result = <String, String>{};
    for (final record in records) {
      if (record['is_deleted'] != true) {
        result[record['key'] as String] = record['value'] as String;
      }
    }
    return result;
  }

  @override
  Future<void> deleteAll() async {
    await ready;
    final all = await readAll();
    for (final key in all.keys) {
      await delete(key: key);
    }
  }

  Future<void> close() async {
    // No-op as we save immediately
  }
}
