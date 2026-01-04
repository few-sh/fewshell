import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'llm_settings_provider.dart';
import 'project_provider.dart';
import 'settings_provider.dart';
import 'secret_provider.dart';
import 'database_provider.dart';

/// Provider for the LLM service
final llmServiceProvider = Provider<LlmService>((ref) {
  final keychainService = ref.watch(keychainServiceProvider);
  final currentProject = ref.watch(currentProjectProvider);
  final database = ref.watch(databaseProvider);

  // Watch global settings
  final globalLlmSettings = ref.watch(globalLlmSettingsProvider);
  final globalSettings = ref.watch(globalSettingsProvider);

  // Watch project settings if a project is active
  List<LlmApiSettings> projectLlmSettings = [];
  ProjectSettings? projectSettings;

  if (currentProject != null) {
    projectLlmSettings = ref.watch(
      projectLlmSettingsProvider(currentProject.id),
    );
    projectSettings = ref.watch(projectSettingsProvider(currentProject.id));
  }

  return LlmService(
    keychainService: keychainService,
    snippetDao: database.snippetDao,
    currentProjectId: currentProject?.id,
    projectLlmSettings: projectLlmSettings,
    projectSettings: projectSettings,
    globalLlmSettings: globalLlmSettings,
    globalSettings: globalSettings,
  );
});

/// Provider for the active model identifier
final activeModelIdentifierProvider = FutureProvider<String?>((ref) async {
  final llmService = ref.watch(llmServiceProvider);
  return llmService.getActiveModelIdentifier();
});
