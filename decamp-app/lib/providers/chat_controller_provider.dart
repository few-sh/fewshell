import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'llm_service_provider.dart';
import 'shell_service_provider.dart';
import 'database_provider.dart';
import 'project_provider.dart';
import 'ssh_settings_provider.dart';
import 'secret_provider.dart';

/// Provider for ChatController
/// Uses family provider to scope controller to specific session
final chatControllerProvider =
    StateNotifierProvider.family<ChatController, ChatState, String?>((
      ref,
      sessionId,
    ) {
      // Get current project to access shell service and SSH settings
      final currentProject = ref.watch(currentProjectProvider);
      final projectId = currentProject?.id;

      final sshSettings = projectId != null
          ? ref.watch(projectSshSettingsProvider(projectId))
          : null;

      // Create secret redactor for this project
      final keychain = ref.watch(keychainServiceProvider);
      final secretRedactor = SecretRedactor(keychain, projectId);

      return ChatController(
        messageDao: ref.watch(databaseProvider).messageDao,
        sessionDao: ref.watch(databaseProvider).sessionDao,
        llmService: ref.watch(llmServiceProvider),
        shellService: ref.watch(shellServiceProvider(projectId)),
        secretRedactor: secretRedactor,
        sshSettings: sshSettings,
        project: currentProject,
        sessionId: sessionId,
      );
    });
