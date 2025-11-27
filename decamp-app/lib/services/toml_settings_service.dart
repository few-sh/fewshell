import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:toml/toml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_core/agent_core.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

class TomlSettingsService {
  static const String _globalSettingsFilename = 'settings.toml';
  static const String _projectSettingsFilename = 'settings.toml';

  // Legacy keys for migration
  static const String _legacyGlobalSettingsKey = 'app_settings';
  static const String _legacyProjectSettingsPrefix = 'project_settings_';

  Future<Directory> get _documentsDir => getApplicationDocumentsDirectory();

  /// Load global settings, migrating from SharedPreferences if necessary
  Future<AppSettings?> loadGlobalSettings() async {
    final dir = await _documentsDir;
    final file = File(p.join(dir.path, _globalSettingsFilename));

    if (await file.exists()) {
      try {
        print('Loading global settings from TOML: ${file.path}');
        final content = await file.readAsString();
        final document = TomlDocument.parse(content);
        final map = document.toMap();
        return AppSettings.fromJson(map);
      } catch (e) {
        print('Error loading global settings from TOML: $e');
        // Fallback to migration check if file is corrupted?
        // Or just return null to trigger default?
        // For now, let's try to migrate if we can't read the file,
        // but maybe we should be careful not to overwrite if it's just a parse error.
        // If it exists but fails, it might be better to return null or throw.
        return null;
      }
    }

    // Check for migration
    return _migrateGlobalSettings(file);
  }

  /// Save global settings to TOML
  Future<void> saveGlobalSettings(AppSettings settings) async {
    final dir = await _documentsDir;
    final file = File(p.join(dir.path, _globalSettingsFilename));

    // Convert to Map using toJson
    // Note: toJson produces a Map<String, dynamic> which might contain objects
    // that TOML doesn't support directly if not simple types.
    // However, AppSettings.toJson() typically produces JSON-safe types (String, int, bool, List, Map).
    // TOML supports these. DateTime in JSON is usually a String.
    final map =
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>;
    final cleanMap = _removeNullsFromMap(map);

    final toml = TomlDocument.fromMap(cleanMap).toString();
    await file.writeAsString(toml);
  }

  /// Load project settings, migrating from SharedPreferences if necessary
  Future<ProjectSettings?> loadProjectSettings(String projectId) async {
    final dir = await _documentsDir;
    final projectDir = Directory(p.join(dir.path, 'projects', projectId));
    final file = File(p.join(projectDir.path, _projectSettingsFilename));

    if (await file.exists()) {
      try {
        print(
          'Loading project settings for $projectId from TOML: ${file.path}',
        );
        final content = await file.readAsString();
        final document = TomlDocument.parse(content);
        final map = document.toMap();
        return ProjectSettings.fromJson(map);
      } catch (e) {
        print('Error loading project settings for $projectId from TOML: $e');
        return null;
      }
    }

    // Check for migration
    return _migrateProjectSettings(projectId, file);
  }

  /// Save project settings to TOML
  Future<void> saveProjectSettings(ProjectSettings settings) async {
    final dir = await _documentsDir;
    final projectDir = Directory(
      p.join(dir.path, 'projects', settings.projectId),
    );

    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }

    final file = File(p.join(projectDir.path, _projectSettingsFilename));

    final map =
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>;
    final cleanMap = _removeNullsFromMap(map);
    final toml = TomlDocument.fromMap(cleanMap).toString();
    await file.writeAsString(toml);
  }

  /// Delete project settings file
  Future<void> deleteProjectSettings(String projectId) async {
    final dir = await _documentsDir;
    final file = File(
      p.join(dir.path, 'projects', projectId, _projectSettingsFilename),
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  // --- Migration Logic ---

  Future<AppSettings?> _migrateGlobalSettings(File targetFile) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_legacyGlobalSettingsKey);

    if (json != null) {
      try {
        print('Migrating global settings from SharedPreferences to TOML...');
        final settings = AppSettings.fromJson(jsonDecode(json));

        // Save to TOML
        await saveGlobalSettings(settings);

        // Clear legacy
        await prefs.remove(_legacyGlobalSettingsKey);
        print('Global settings migration complete.');

        return settings;
      } catch (e) {
        print('Error migrating global settings: $e');
      }
    }
    return null;
  }

  Future<ProjectSettings?> _migrateProjectSettings(
    String projectId,
    File targetFile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_legacyProjectSettingsPrefix$projectId';
    final json = prefs.getString(key);

    if (json != null) {
      try {
        print(
          'Migrating project settings for $projectId from SharedPreferences to TOML...',
        );
        final settings = ProjectSettings.fromJson(jsonDecode(json));

        // Save to TOML
        await saveProjectSettings(settings);

        // Clear legacy
        await prefs.remove(key);
        print('Project settings migration for $projectId complete.');

        return settings;
      } catch (e) {
        print('Error migrating project settings for $projectId: $e');
      }
    }
    return null;
  }

  /// Recursively remove null values from a map
  Map<String, dynamic> _removeNullsFromMap(Map<String, dynamic> map) {
    final newMap = <String, dynamic>{};
    map.forEach((key, value) {
      if (value != null) {
        if (value is Map) {
          newMap[key] = _removeNullsFromMap(Map<String, dynamic>.from(value));
        } else if (value is List) {
          newMap[key] = value.map((e) {
            if (e is Map) {
              return _removeNullsFromMap(Map<String, dynamic>.from(e));
            }
            return e;
          }).toList();
        } else {
          newMap[key] = value;
        }
      }
    });
    return newMap;
  }
}
