import 'dart:async';
import 'dart:convert';
import 'package:crdt/crdt.dart';
import 'package:crdt/map_crdt.dart';
import 'package:logging/logging.dart';
import 'package:agent_core/src/secrets_storage/secure_storage.dart';
import 'package:agent_core/src/secrets_storage/secrets_storage.dart';
import 'package:agent_core/src/models/secret.dart';

class SecretsCrdt extends MapCrdt implements SecretsStorage {
  static final _log = Logger('SecretsCrdt');
  final SecureStorage _storage;
  final StreamController<void> _changeController = StreamController.broadcast();
  late final Future<void> ready;

  SecretsCrdt(this._storage) : super(['secrets']) {
    ready = _load();
  }

  bool _initialChangeset = true;

  Stream<void> get onChange => _changeController.stream;

  /// Resets the initial changeset flag so the next sync will send all secrets.
  /// Call this when establishing a new sync connection.
  void resetInitialChangeset() {
    _initialChangeset = true;
  }

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
            var value = json['value'];
            // If we have the separate field, construct the Secret map
            if (json.containsKey('isVisibleToLlm')) {
              value = {
                'value': value,
                'isVisibleToLlm': json['isVisibleToLlm']
              };
            }

            records.add({
              'key': entry.key,
              'value': value,
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
        // Use super.merge directly to avoid triggering _saveKey and notifications during load
        await super.merge({'secrets': records});
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
    // Ensure value is encodable (Secret object or Map)
    if (value is Secret) {
      value = value.toJson();
    }
    await super.put(table, key, value, isDeleted);
    await _saveKey(key);
    _changeController.add(null);
  }

  @override
  Future<void> merge(Map<String, List<Map<String, Object?>>> changeset) async {
    final records = changeset['secrets'] ?? [];
    final recordsToMerge = <Map<String, Object?>>[];
    final changedKeys = <String>{};

    // Filter out records that are not newer than what we have
    for (final record in records) {
      final key = record['key'] as String;
      try {
        final hlcVal = record['hlc'];
        final incomingHlc =
            hlcVal is Hlc ? hlcVal : Hlc.parse(hlcVal.toString());

        final existing = getRecord('secrets', key);
        // Only merge if we don't have it, or the incoming one is newer
        if (existing == null || incomingHlc > existing.hlc) {
          recordsToMerge.add(record);
          changedKeys.add(key);
        }
      } catch (e) {
        _log.warning('Invalid HLC in merge for key $key: ${record['hlc']}');
        continue;
      }
    }

    if (recordsToMerge.isNotEmpty) {
      // Only merge the subset of records that are actually new
      await super.merge({'secrets': recordsToMerge});

      _log.info('Merged ${recordsToMerge.length} new/updated secrets');
      for (final key in changedKeys) {
        await _saveKey(key);
      }
      _changeController.add(null);
    } else if (records.isNotEmpty) {
      _log.fine('Ignored ${records.length} redundant secrets during merge');
    }
  }

  Future<void> _saveKey(String key) async {
    try {
      final record = getRecord('secrets', key);
      if (record != null) {
        var value = record.value;
        final hlc = record.hlc;
        final isDeleted = record.isDeleted;
        final modified = record.modified;

        if (isDeleted) {
          // Extra safety: set secret value to null if deleted
          value = null;
        }

        final Map<String, dynamic> jsonMap = {
          'hlc': hlc.toString(),
          'is_deleted': isDeleted,
          'modified': modified,
        };

        if (value is Map<String, dynamic>) {
          jsonMap['value'] = value['value'];
          jsonMap['isVisibleToLlm'] = value['isVisibleToLlm'];
        } else if (value is Secret) {
          jsonMap['value'] = value.value;
          jsonMap['isVisibleToLlm'] = value.isVisibleToLlm;
        } else {
          // String or null
          jsonMap['value'] = value;
        }

        final json = jsonEncode(jsonMap);

        await _storage.write(key: key, value: json);
        _log.info('Saved secret: $key');
      } else {
        _log.warning('Record not found for key: $key');
      }
    } catch (e) {
      _log.severe('Error saving secrets CRDT: $e');
    }
  }

  // New API methods

  @override
  Future<void> write({required String key, required Secret value}) async {
    await ready;
    await put('secrets', key, value);
  }

  @override
  Future<Secret?> read({required String key}) async {
    await ready;
    final value = super.get('secrets', key);
    _log.info('Read secret $key: ${value != null ? 'found' : 'not found'}');
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return Secret.fromJson(value);
    }
    // Fallback for legacy data if any slipped through
    if (value is String) {
      return Secret(value: value);
    }
    return null;
  }

  @override
  Future<void> delete({required String key}) async {
    await ready;
    await put('secrets', key, null, true);
  }

  @override
  Future<Map<String, Secret>> readAll() async {
    await ready;
    final changeset = getChangeset();
    final records = changeset['secrets'] ?? [];
    final result = <String, Secret>{};
    for (final record in records) {
      if (record['is_deleted'] != true) {
        final val = record['value'];
        if (val is Map<String, dynamic>) {
          result[record['key'] as String] = Secret.fromJson(val);
        } else if (val is String) {
          result[record['key'] as String] = Secret(value: val);
        }
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

  FutureOr<CrdtChangeset> changesetFunction({
    required String projectId,
    Iterable<String>? onlyTables,
    String? onlyNodeId,
    String? exceptNodeId,
    Hlc? modifiedOn,
    Hlc? modifiedAfter,
  }) {
    if (_initialChangeset) {
      _log.info('Generating initial changeset for project $projectId');
    }
    final changeset = getChangeset(
      onlyTables: onlyTables,
      onlyNodeId: _initialChangeset
          ? null // Not filtering by nodeId here because the server may need all nodes' data including its own, since its secrets are ephemeral
          : onlyNodeId,
      exceptNodeId: exceptNodeId,
      modifiedOn: modifiedOn,
      modifiedAfter: modifiedAfter,
    );
    _initialChangeset = false;

    if (changeset.containsKey('secrets')) {
      final records = changeset['secrets']!;
      final prefix = 'project:$projectId:';

      // Filter records that match the project prefix
      final filteredRecords = records.where((record) {
        final key = record['key'] as String;
        return key.startsWith(prefix);
      }).toList();

      if (filteredRecords.isEmpty) {
        changeset.remove('secrets');
      } else {
        changeset['secrets'] = filteredRecords;
      }
    }
    return changeset;
  }

  Future<void> close() async {
    _log.info('Disposed SecretsCrdt');
  }
}
