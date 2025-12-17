import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crdt/map_crdt.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';

class SettingsCrdt extends MapCrdt {
  static final _log = Logger('SettingsCrdt');
  final File _file;
  Timer? _saveTimer;
  final StreamController<void> _changeController = StreamController.broadcast();

  SettingsCrdt(this._file) : super(['settings']);

  Stream<void> get onChange => _changeController.stream;

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
          final changeset = toml.map((table, records) {
            return MapEntry(
                table, (records as List).cast<Map<String, dynamic>>());
          });
          await super.merge(changeset);
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
      final jsonCompatible = jsonDecode(jsonEncode(changeset));
      final toml = TomlDocument.fromMap(jsonCompatible).toString();
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
