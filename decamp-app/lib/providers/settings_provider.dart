import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import '../utils/default_prompt_loader.dart';
import '../services/toml_settings_service.dart';

/// Provider for TomlSettingsService
final tomlSettingsServiceProvider = Provider<TomlSettingsService>((ref) {
  return TomlSettingsService();
});

/// Provider for global app settings
final globalSettingsProvider =
    StateNotifierProvider<GlobalSettingsNotifier, AppSettings>((ref) {
      final tomlService = ref.watch(tomlSettingsServiceProvider);
      return GlobalSettingsNotifier(tomlService);
    });

/// StateNotifier for global settings
class GlobalSettingsNotifier extends StateNotifier<AppSettings> {
  final TomlSettingsService _tomlService;

  GlobalSettingsNotifier(this._tomlService) : super(const AppSettings()) {
    _loadSettings();
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      final settings = await _tomlService.loadGlobalSettings();

      if (settings != null) {
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
      } else {
        // No saved settings, initialize with default prompt
        await _initializeWithDefault();
      }
    } catch (e) {
      // If loading fails, initialize with default settings and default prompt
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
    await _tomlService.saveGlobalSettings(settings);
  }
}

/// Provider for project-specific settings (family provider)
final projectSettingsProvider =
    StateNotifierProvider.family<
      ProjectSettingsNotifier,
      ProjectSettings?,
      String
    >((ref, projectId) {
      final tomlService = ref.watch(tomlSettingsServiceProvider);
      return ProjectSettingsNotifier(tomlService, projectId);
    });

/// StateNotifier for project settings
class ProjectSettingsNotifier extends StateNotifier<ProjectSettings?> {
  final TomlSettingsService _tomlService;
  final String _projectId;

  ProjectSettingsNotifier(this._tomlService, this._projectId) : super(null) {
    _loadSettings();
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      final settings = await _tomlService.loadProjectSettings(_projectId);
      if (settings != null) {
        state = settings;
      } else {
        // Initialize with default if not found
        state = ProjectSettings(projectId: _projectId);
      }
    } catch (e) {
      // If loading fails, initialize with default
      state = ProjectSettings(projectId: _projectId);
    }
  }

  /// Update settings and persist
  Future<void> updateSettings(ProjectSettings settings) async {
    state = settings;
    await _tomlService.saveProjectSettings(settings);
  }

  /// Delete project settings
  Future<void> deleteSettings() async {
    await _tomlService.deleteProjectSettings(_projectId);
    state = null;
  }
}
