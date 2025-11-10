import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/settings.dart';
import '../models/agent_instruction.dart';
import '../utils/default_prompt_loader.dart';
import 'theme_provider.dart';

/// Key for storing global settings in SharedPreferences
const String _globalSettingsKey = 'app_settings';

/// Key prefix for storing project settings in SharedPreferences
const String _projectSettingsPrefix = 'project_settings_';

/// Provider for global app settings
final globalSettingsProvider =
    StateNotifierProvider<GlobalSettingsNotifier, AppSettings>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return GlobalSettingsNotifier(prefs);
    });

/// StateNotifier for global settings
class GlobalSettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  GlobalSettingsNotifier(this._prefs) : super(const AppSettings()) {
    _loadSettings();
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    final json = _prefs.getString(_globalSettingsKey);
    if (json != null) {
      try {
        final settings = AppSettings.fromJson(jsonDecode(json));

        // If no agent instruction exists, load the default one
        if (settings.agentInstruction == null) {
          final defaultPrompt = await loadDefaultSystemPrompt();
          state = settings.copyWith(
            agentInstruction: AgentInstruction(
              defaultInstruction: defaultPrompt,
            ),
          );
        } else {
          state = settings;
        }
      } catch (e) {
        // If loading fails, initialize with default settings and default prompt
        await _initializeWithDefault();
      }
    } else {
      // No saved settings, initialize with default prompt
      await _initializeWithDefault();
    }
  }

  /// Initialize settings with the default system prompt
  Future<void> _initializeWithDefault() async {
    final defaultPrompt = await loadDefaultSystemPrompt();
    state = AppSettings(
      agentInstruction: AgentInstruction(defaultInstruction: defaultPrompt),
    );
  }

  /// Update settings and persist
  Future<void> updateSettings(AppSettings settings) async {
    state = settings;
    await _prefs.setString(_globalSettingsKey, jsonEncode(settings.toJson()));
  }
}

/// Provider for project-specific settings (family provider)
final projectSettingsProvider =
    StateNotifierProvider.family<
      ProjectSettingsNotifier,
      ProjectSettings?,
      String
    >((ref, projectId) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ProjectSettingsNotifier(prefs, projectId);
    });

/// StateNotifier for project settings
class ProjectSettingsNotifier extends StateNotifier<ProjectSettings?> {
  final SharedPreferences _prefs;
  final String _projectId;

  ProjectSettingsNotifier(this._prefs, this._projectId) : super(null) {
    _loadSettings();
  }

  /// Load settings from persistent storage
  void _loadSettings() {
    final key = '$_projectSettingsPrefix$_projectId';
    final json = _prefs.getString(key);
    if (json != null) {
      try {
        state = ProjectSettings.fromJson(jsonDecode(json));
      } catch (e) {
        // If loading fails, initialize with default
        state = ProjectSettings(projectId: _projectId);
      }
    } else {
      // Initialize with default if not found
      state = ProjectSettings(projectId: _projectId);
    }
  }

  /// Update settings and persist
  Future<void> updateSettings(ProjectSettings settings) async {
    state = settings;
    final key = '$_projectSettingsPrefix$_projectId';
    await _prefs.setString(key, jsonEncode(settings.toJson()));
  }

  /// Delete project settings
  Future<void> deleteSettings() async {
    final key = '$_projectSettingsPrefix$_projectId';
    await _prefs.remove(key);
    state = null;
  }
}
