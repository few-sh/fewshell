import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:agent_core/agent_core.dart';

class CrdtSettingsService {
  static final _log = Logger('CrdtSettingsService');
  static const String _crdtFilename = 'settings_crdt.json';
  static const String _globalKey = 'global';

  final Future<Directory> Function() _getBaseDir;
  SettingsCrdt? _crdt;
  final StreamController<AppSettings> _settingsController =
      StreamController.broadcast();

  CrdtSettingsService(this._getBaseDir);

  SettingsCrdt? get crdt => _crdt;

  Stream<AppSettings> get settingsStream => _settingsController.stream;

  Future<void> init() async {
    if (_crdt != null) return;
    final dir = await _getBaseDir();
    _crdt = await SettingsCrdt.load(dir, _crdtFilename);

    // Check if migration is needed
    if (_crdt!.get('settings', _globalKey) == null) {
      await _migrateFromToml(dir);
    }

    // Emit initial value
    _emitSettings();

    // Listen for changes
    _crdt!.onChange.listen((_) {
      _emitSettings();
    });
  }

  Future<void> _migrateFromToml(Directory dir) async {
    final tomlService = TomlSettingsService(() async => dir);
    final settings = await tomlService.loadGlobalSettings();
    if (settings != null) {
      _log.info('Migrating settings from TOML to CRDT');
      await saveGlobalSettings(settings);

      // Rename old file
      final file = File(p.join(dir.path, 'settings.toml'));
      if (await file.exists()) {
        await file.rename(p.join(dir.path, 'settings.toml.bak'));
      }
    }
  }

  void _emitSettings() {
    final json = _crdt!.get('settings', _globalKey);
    if (json != null) {
      try {
        final settings = AppSettings.fromJson(Map<String, dynamic>.from(json));
        _settingsController.add(settings);
      } catch (e) {
        _log.warning('Error parsing settings from CRDT: $e');
      }
    } else {
      _settingsController.add(const AppSettings());
    }
  }

  Future<void> saveGlobalSettings(AppSettings settings) async {
    if (_crdt == null) return;
    await _crdt!.put('settings', _globalKey, settings.toJson());
  }

  static String _projectKey(String projectId) => 'project_$projectId';

  Future<void> saveProjectSettings(ProjectSettings settings) async {
    if (_crdt == null) return;
    await _crdt!
        .put('settings', _projectKey(settings.projectId), settings.toJson());
  }

  ProjectSettings? getProjectSettings(String projectId) {
    final json = _crdt!.get('settings', _projectKey(projectId));
    if (json != null) {
      try {
        return ProjectSettings.fromJson(Map<String, dynamic>.from(json));
      } catch (e) {
        _log.warning('Error parsing project settings for $projectId: $e');
      }
    }
    return null;
  }

  Stream<void> get onChange => _crdt?.onChange ?? const Stream.empty();

  Future<void> close() async {
    await _crdt?.close();
    await _settingsController.close();
  }
}
