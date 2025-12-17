import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/default_prompt_loader.dart';

/// Provider for CrdtSettingsService
final crdtSettingsServiceProvider = Provider<CrdtSettingsService>((ref) {
  return CrdtSettingsService(getApplicationDocumentsDirectory);
});

/// Provider for global app settings
final globalSettingsProvider =
    StateNotifierProvider<GlobalSettingsNotifier, AppSettings>((ref) {
      final service = ref.watch(crdtSettingsServiceProvider);
      return GlobalSettingsNotifier(service);
    });

/// StateNotifier for global settings
class GlobalSettingsNotifier extends StateNotifier<AppSettings> {
  final CrdtSettingsService _service;

  GlobalSettingsNotifier(this._service) : super(const AppSettings()) {
    _init();
  }

  Future<void> _init() async {
    await _service.init();

    // Listen to stream
    _service.settingsStream.listen((settings) {
      _updateState(settings);
    });
  }

  void _updateState(AppSettings settings) {
    if (settings.agentInstruction == null) {
      loadDefaultSystemPrompt().then((defaultPrompt) {
        if (mounted) {
          state = settings.copyWith(
            agentInstruction: AgentInstruction(
              defaultInstruction: defaultPrompt,
            ),
          );
        }
      });
    } else {
      if (mounted) state = settings;
    }
  }

  /// Update settings and persist
  Future<void> updateSettings(AppSettings settings) async {
    state = settings;
    await _service.saveGlobalSettings(settings);
  }
}

/// Provider for project-specific settings (family provider)
final projectSettingsProvider =
    StateNotifierProvider.family<
      ProjectSettingsNotifier,
      ProjectSettings?,
      String
    >((ref, projectId) {
      final service = ref.watch(crdtSettingsServiceProvider);
      return ProjectSettingsNotifier(service, projectId);
    });

/// StateNotifier for project settings
class ProjectSettingsNotifier extends StateNotifier<ProjectSettings?> {
  final CrdtSettingsService _service;
  final String _projectId;

  ProjectSettingsNotifier(this._service, this._projectId) : super(null) {
    _init();
  }

  Future<void> _init() async {
    await _service.init();
    _loadSettings();

    _service.onChange.listen((_) {
      _loadSettings();
    });
  }

  void _loadSettings() {
    final settings = _service.getProjectSettings(_projectId);
    if (settings != null) {
      if (mounted) state = settings;
    } else {
      if (mounted) state = ProjectSettings(projectId: _projectId);
    }
  }

  /// Update settings and persist
  Future<void> updateSettings(ProjectSettings settings) async {
    state = settings;
    await _service.saveProjectSettings(settings);
  }

  /// Delete project settings
  Future<void> deleteSettings() async {
    // TODO: Implement delete in CrdtSettingsService
    state = null;
  }
}
