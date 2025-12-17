import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:agent_core/agent_core.dart';

class CrdtSettingsService {
  static final _log = Logger('CrdtSettingsService');
  static const String _globalFilename = 'settings.json';
  static const String _projectCrdtFilename = 'settings_crdt.json';

  final Future<Directory> Function() _getGlobalDir;
  final Future<Directory> Function(String projectId) _getProjectDir;

  // Global settings (Simple JSON)
  AppSettings _globalSettings = const AppSettings();
  final StreamController<AppSettings> _globalSettingsController =
      StreamController.broadcast();

  // Project settings (CRDT)
  final Map<String, SettingsCrdt> _projectCrdts = {};
  final StreamController<void> _projectChangeController =
      StreamController.broadcast();

  CrdtSettingsService(this._getGlobalDir, this._getProjectDir);

  Stream<AppSettings> get globalSettingsStream =>
      _globalSettingsController.stream;
  Stream<void> get onProjectChange => _projectChangeController.stream;

  Future<void> init() async {
    await _loadGlobalSettings();
  }

  Future<void> _loadGlobalSettings() async {
    try {
      final dir = await _getGlobalDir();
      final file = File(p.join(dir.path, _globalFilename));
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final json = jsonDecode(content);
          _globalSettings = AppSettings.fromJson(json);
          _globalSettingsController.add(_globalSettings);
        }
      } else {
        // Try migrating from TOML if JSON doesn't exist
        await _migrateFromToml(dir);
      }
    } catch (e) {
      _log.warning('Error loading global settings: $e');
    }
  }

  Future<void> _migrateFromToml(Directory dir) async {
    final tomlService = TomlSettingsService(() async => dir);
    final settings = await tomlService.loadGlobalSettings();
    if (settings != null) {
      _log.info('Migrating settings from TOML to JSON');
      await saveGlobalSettings(settings);

      // Rename old file
      final file = File(p.join(dir.path, 'settings.toml'));
      if (await file.exists()) {
        await file.rename(p.join(dir.path, 'settings.toml.bak'));
      }
    }
  }

  AppSettings getGlobalSettings() {
    return _globalSettings;
  }

  Future<void> saveGlobalSettings(AppSettings settings) async {
    _globalSettings = settings;
    _globalSettingsController.add(settings);

    try {
      final dir = await _getGlobalDir();
      final file = File(p.join(dir.path, _globalFilename));
      await file.writeAsString(jsonEncode(settings.toJson()));
    } catch (e) {
      _log.severe('Error saving global settings: $e');
    }
  }

  // Project Settings

  Future<SettingsCrdt> getProjectCrdt(String projectId) async {
    if (_projectCrdts.containsKey(projectId)) {
      return _projectCrdts[projectId]!;
    }

    final dir = await _getProjectDir(projectId);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final crdt = await SettingsCrdt.load(dir, _projectCrdtFilename);
    _projectCrdts[projectId] = crdt;

    crdt.onChange.listen((_) {
      _projectChangeController.add(null);
    });

    return crdt;
  }

  static String _projectKey(String projectId) => 'project_$projectId';

  Future<ProjectSettings?> getProjectSettings(String projectId) async {
    final crdt = await getProjectCrdt(projectId);
    final json = crdt.get('settings', _projectKey(projectId));
    if (json != null) {
      try {
        return ProjectSettings.fromJson(Map<String, dynamic>.from(json));
      } catch (e) {
        _log.warning('Error parsing project settings for $projectId: $e');
      }
    }
    return null;
  }

  Future<void> saveProjectSettings(ProjectSettings settings) async {
    final crdt = await getProjectCrdt(settings.projectId);
    // Ensure deep serialization by encoding/decoding
    final json = jsonDecode(jsonEncode(settings.toJson()));
    await crdt.put('settings', _projectKey(settings.projectId), json);
  }

  Future<void> close() async {
    await _globalSettingsController.close();
    await _projectChangeController.close();
    for (final crdt in _projectCrdts.values) {
      await crdt.close();
    }
  }
}
