import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/settings.dart';
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
  void _loadSettings() {
    final json = _prefs.getString(_globalSettingsKey);
    if (json != null) {
      try {
        state = AppSettings.fromJson(jsonDecode(json));
      } catch (e) {
        // If loading fails, keep default settings
      }
    }
  }

  /// Update settings and persist
  Future<void> updateSettings(AppSettings settings) async {
    state = settings;
    await _prefs.setString(_globalSettingsKey, jsonEncode(settings.toJson()));
  }

  /// Update dark mode
  Future<void> setDarkMode(bool darkMode) async {
    await updateSettings(state.copyWith(darkMode: darkMode));
  }

  /// Update default agents.md content
  Future<void> setDefaultAgentsMd(String content) async {
    await updateSettings(state.copyWith(defaultAgentsMd: content));
  }

  /// Update global secrets metadata
  Future<void> setGlobalSecrets(Map<String, dynamic>? secrets) async {
    await updateSettings(state.copyWith(globalSecrets: secrets));
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
        // If loading fails, keep null (will fall back to global)
      }
    }
  }

  /// Update settings and persist
  Future<void> updateSettings(ProjectSettings settings) async {
    state = settings;
    final key = '$_projectSettingsPrefix$_projectId';
    await _prefs.setString(key, jsonEncode(settings.toJson()));
  }

  /// Update agents.md content
  Future<void> setAgentsMd(String? content) async {
    final now = DateTime.now();
    final updated = (state ?? ProjectSettings(projectId: _projectId)).copyWith(
      agentsMd: content,
      updatedAt: now,
      createdAt: state?.createdAt ?? now,
    );
    await updateSettings(updated);
  }

  /// Update GitHub repository
  Future<void> setGithubRepo(String? repo) async {
    final now = DateTime.now();
    final updated = (state ?? ProjectSettings(projectId: _projectId)).copyWith(
      githubRepo: repo,
      updatedAt: now,
      createdAt: state?.createdAt ?? now,
    );
    await updateSettings(updated);
  }

  /// Update GitHub branch
  Future<void> setGithubBranch(String? branch) async {
    final now = DateTime.now();
    final updated = (state ?? ProjectSettings(projectId: _projectId)).copyWith(
      githubBranch: branch,
      updatedAt: now,
      createdAt: state?.createdAt ?? now,
    );
    await updateSettings(updated);
  }

  /// Update project secrets metadata
  Future<void> setSecrets(Map<String, String>? secrets) async {
    final now = DateTime.now();
    final updated = (state ?? ProjectSettings(projectId: _projectId)).copyWith(
      secrets: secrets,
      updatedAt: now,
      createdAt: state?.createdAt ?? now,
    );
    await updateSettings(updated);
  }

  /// Update GitHub sync enabled flag
  Future<void> setGithubSyncEnabled(bool enabled) async {
    final now = DateTime.now();
    final updated = (state ?? ProjectSettings(projectId: _projectId)).copyWith(
      enableGithubSync: enabled,
      updatedAt: now,
      createdAt: state?.createdAt ?? now,
    );
    await updateSettings(updated);
  }

  /// Delete project settings
  Future<void> deleteSettings() async {
    final key = '$_projectSettingsPrefix$_projectId';
    await _prefs.remove(key);
    state = null;
  }
}

/// Provider for effective settings (merged global + project overrides)
final effectiveSettingsProvider = Provider.family<EffectiveSettings, String>((
  ref,
  projectId,
) {
  final globalSettings = ref.watch(globalSettingsProvider);
  final projectSettings = ref.watch(projectSettingsProvider(projectId));

  return EffectiveSettings(global: globalSettings, project: projectSettings);
});

/// Class representing merged settings
class EffectiveSettings {
  final AppSettings global;
  final ProjectSettings? project;

  EffectiveSettings({required this.global, this.project});

  /// Get agents.md content (project overrides global)
  String get agentsMd => project?.agentsMd ?? global.defaultAgentsMd;

  /// Get GitHub repo (project specific)
  String? get githubRepo => project?.githubRepo;

  /// Get GitHub branch (project specific)
  String? get githubBranch => project?.githubBranch;

  /// Get GitHub sync enabled flag
  bool get githubSyncEnabled => project?.enableGithubSync ?? true;

  /// Check if project has custom agents.md
  bool get hasCustomAgentsMd => project?.agentsMd != null;

  /// Check if GitHub is configured for project
  bool get hasGithubConfigured =>
      project?.githubRepo != null && project?.githubRepo?.isNotEmpty == true;
}
