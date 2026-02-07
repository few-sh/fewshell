// This file contains ALL provider declarations for the decamp-app.
// Providers are organized in dependency order (bottom-up) for clarity.
//
// Business logic (StateNotifier classes, Controller classes, etc.) remain
// in their respective files. Only provider declarations are consolidated here.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_core/agent_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:crdt/crdt.dart';
import 'package:logging/logging.dart';

// Import business logic classes from their respective files
import 'theme_provider.dart' show ThemeNotifier;
import 'user_provider.dart' show UserNotifier;
import 'database_provider.dart' as db_provider;
import 'settings_provider.dart'
    show
        GlobalSettingsNotifier,
        ProjectSettingsNotifier,
        CrdtSettingsService,
        AppSettings,
        ProjectSettings;
import 'project_provider.dart' show SelectedProjectNotifier, ProjectController;
import 'session_provider.dart' show SelectedSessionNotifier, SessionController;
import 'snippet_provider.dart' show SnippetController;
import 'saved_prompt_provider.dart' show SavedPromptController;
import 'llm_settings_provider.dart'
    show GlobalLlmSettingsNotifier, ProjectLlmSettingsNotifier, LlmApiSettings;
import 'ssh_settings_provider.dart'
    show ProjectSshSettingsNotifier, SshSettings;
import '../services/storage/flutter_secure_storage_impl.dart';

export 'notification_provider.dart';

final _log = Logger('providers');

// =============================================================================
// LEVEL 1: Base Infrastructure Providers
// =============================================================================

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

/// Provider for PackageInfo
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

// =============================================================================
// LEVEL 2: Database Providers
// =============================================================================

/// Provider for unique node ID
final nodeIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  var nodeId = prefs.getString('node_id');
  if (nodeId == null) {
    nodeId = const Uuid().v4();
    prefs.setString('node_id', nodeId);
  }
  return nodeId;
});

/// Provider for the GlobalDatabase instance (decamp.db).
final globalDatabaseProvider = Provider<GlobalDatabase>((ref) {
  final nodeId = ref.watch(nodeIdProvider);
  Crdt? crdt;
  final database = GlobalDatabase(
    db_provider.openGlobalConnection(nodeId, (c) => crdt = c),
    crdtProvider: () => crdt!,
  );

  // Dispose database when provider is disposed
  ref.onDispose(() {
    _log.info('Closing global database');
    database.close();
  });

  return database;
});

/// Provider for the ProjectDatabase instance.
/// Returns null if no project is selected.
final projectDatabaseProvider = Provider<ProjectDatabase?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;

  final nodeId = ref.watch(nodeIdProvider);
  Crdt? crdt;

  final database = ProjectDatabase(
    db_provider.openProjectConnection(projectId, nodeId, (c) => crdt = c),
    crdtProvider: () => crdt!,
  );

  // Dispose database when provider is disposed (e.g. project changed)
  ref.onDispose(() {
    _log.info('Closing project database for $projectId');
    database.close();
  });

  return database;
});

/// Provider for the DatabaseFacade.
/// This replaces the old databaseProvider.
/// Access DAOs directly: ref.watch(databaseProvider).projectDao
final databaseProvider = Provider<DatabaseFacade>((ref) {
  final globalDb = ref.watch(globalDatabaseProvider);
  final projectDb = ref.watch(projectDatabaseProvider);
  final projectId = ref.watch(currentProjectIdProvider);

  return DatabaseFacade(globalDb, projectDb, projectId);
});

// =============================================================================
// LEVEL 3: Settings Providers
// =============================================================================

/// Provider for CrdtSettingsService
final crdtSettingsServiceProvider = Provider<CrdtSettingsService>((ref) {
  final service = CrdtSettingsService(getApplicationDocumentsDirectory, (
    projectId,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/projects/$projectId');
  });
  ref.onDispose(() => service.close());
  return service;
});

/// Provider for global app settings
final globalSettingsProvider =
    StateNotifierProvider<GlobalSettingsNotifier, AppSettings>((ref) {
      final service = ref.watch(crdtSettingsServiceProvider);
      return GlobalSettingsNotifier(service);
    });

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

// =============================================================================
// LEVEL 4: Secret/Keychain Providers
// =============================================================================

/// Provider for SecretsCrdt
final secretsCrdtProvider = Provider<SecretsCrdt>((ref) {
  // Re-create the CRDT when the project ID changes.
  ref.watch(currentProjectIdProvider);

  final storage = FlutterSecureStorageImpl();
  final crdt = SecretsCrdt(storage);
  ref.onDispose(() => crdt.close());
  return crdt;
});

/// Provider for KeychainService singleton
/// Access directly: ref.watch(keychainServiceProvider).saveProjectSecret(...)
final keychainServiceProvider = Provider<KeychainService>((ref) {
  final crdt = ref.watch(secretsCrdtProvider);
  return KeychainService(crdt, changeStream: crdt.onChange);
});

/// Provider to watch project secrets
final projectSecretsProvider =
    StreamProvider.family<Map<String, Secret>, String>((ref, projectId) {
      final keychain = ref.watch(keychainServiceProvider);
      return keychain.watchProjectSecretObjects(projectId);
    });

/// Provider to get all secrets (global and project merged)
final allSecretsProvider = FutureProvider.family<Map<String, String>, String?>((
  ref,
  projectId,
) async {
  final keychain = ref.watch(keychainServiceProvider);

  if (projectId != null) {
    final projectSecrets = await keychain.listProjectSecrets(projectId);
    final globalSecrets = await keychain.listGlobalSecrets();

    // Merge with project secrets taking precedence
    final merged = <String, String>{...globalSecrets};
    merged.addAll(projectSecrets);

    return merged;
  } else {
    return await keychain.listGlobalSecrets();
  }
});

/// Provider to get a specific global secret
final globalSecretProvider = FutureProvider.family<String?, String>((
  ref,
  secretName,
) async {
  final keychain = ref.watch(keychainServiceProvider);
  return keychain.getGlobalSecret(secretName);
});

/// Provider to get a specific project secret
/// Parameter is a record with projectId and secretName
final projectSecretProvider =
    FutureProvider.family<String?, ({String projectId, String secretName})>((
      ref,
      params,
    ) async {
      final keychain = ref.watch(keychainServiceProvider);
      return keychain.getProjectSecret(params.projectId, params.secretName);
    });

// =============================================================================
// LEVEL 5: User & Theme Providers
// =============================================================================

/// Provider for theme state
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

/// Provider for user state
final userProvider = StateNotifierProvider<UserNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserNotifier(prefs);
});

// =============================================================================
// LEVEL 6: Project Providers
// =============================================================================

/// Provider for streaming active projects
final activeProjectsProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final globalDb = ref.watch(globalDatabaseProvider);
  return globalDb.projectDao.watchAllProjects(isArchived: false);
});

/// Provider for streaming archived projects
final archivedProjectsProvider = StreamProvider<List<ProjectEntity>>((ref) {
  final globalDb = ref.watch(globalDatabaseProvider);
  return globalDb.projectDao.watchAllProjects(isArchived: true);
});

// Deprecated: Alias to active for backward compatibility inside this refactor step if needed,
// though we should switch usages.
final projectsStreamProvider = activeProjectsProvider;

/// Provider for the currently selected project ID
/// CONSOLIDATED: Selection state + Persistence logic in one place.
final currentProjectIdProvider =
    StateNotifierProvider<SelectedProjectNotifier, String?>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return SelectedProjectNotifier(prefs, ref);
    });

/// Provider for the currently selected project
/// SIMPLIFIED: Derived state
final currentProjectProvider = Provider<ProjectEntity?>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) return null;

  return ref
      .watch(projectsStreamProvider)
      .whenOrNull(
        data: (projects) {
          try {
            return projects.firstWhere((p) => p.id == projectId);
          } catch (e) {
            return null;
          }
        },
      );
});

/// Provider for the ProjectController
final projectControllerProvider = Provider((ref) => ProjectController(ref));

// =============================================================================
// LEVEL 7: Session Providers
// =============================================================================

/// Provider for sessions of the currently selected project
final currentProjectSessionsProvider = StreamProvider<List<SessionEntity>>(((
  ref,
) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) {
    return Stream.value([]);
  }
  final sessionDao = ref.watch(databaseProvider).sessionDao;
  return sessionDao.watchNonArchivedSessionsByProject(projectId);
}));

/// Provider for archived sessions of the currently selected project
final archivedSessionsProvider = StreamProvider<List<SessionEntity>>((ref) {
  final projectId = ref.watch(currentProjectIdProvider);
  if (projectId == null) {
    return Stream.value([]);
  }
  final sessionDao = ref.watch(databaseProvider).sessionDao;
  return sessionDao.watchArchivedSessionsByProject(projectId);
});

/// Provider for the currently selected session ID
final currentSessionIdProvider =
    StateNotifierProvider<SelectedSessionNotifier, String?>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return SelectedSessionNotifier(prefs, ref);
    });

/// Provider for the lock status of the current session
final currentSessionLockProvider = StreamProvider<bool>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return Stream.value(false);

  final db = ref.watch(databaseProvider);
  // If project database is not loaded yet, return false
  if (db.projectDatabase == null) return Stream.value(false);

  return db.sessionMutexDao.watchLock(sessionId);
});

/// Provider for session controller
final sessionControllerProvider = Provider((ref) => SessionController(ref));

/// Provider for the currently selected session
/// Returns null if no session is selected or session doesn't exist
final currentSessionProvider = Provider<SessionEntity?>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return null;

  final sessionsAsync = ref.watch(currentProjectSessionsProvider);
  return sessionsAsync.whenData((sessions) {
    try {
      return sessions.firstWhere((s) => s.id == sessionId);
    } catch (e) {
      return null;
    }
  }).value;
});

// =============================================================================
// LEVEL 8: Message Providers
// =============================================================================

/// Provider for messages of the currently selected session
final currentSessionMessagesProvider = StreamProvider<List<MessageEntity>>((
  ref,
) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) {
    return Stream.value([]);
  }
  final messageDao = ref.watch(databaseProvider).messageDao;
  return messageDao.watchCompletedMessagesBySession(sessionId);
});

/// Stream provider for message subscribers by session and device token
/// Takes a record (sessionId, deviceToken) as parameter
final messageSubscribersBySessionAndDeviceProvider =
    StreamProvider.family<
      List<MessageSubscriberEntity>,
      (String sessionId, String deviceToken)
    >((ref, params) {
      final projectDb = ref.watch(projectDatabaseProvider);
      if (projectDb == null) {
        return Stream.value([]);
      }
      final (sessionId, deviceToken) = params;
      return projectDb.messageSubscriberDao
          .watchSubscriptionsBySessionAndDevice(sessionId, deviceToken);
    });

// =============================================================================
// LEVEL 9: Snippet Providers
// =============================================================================

/// Stream provider for global snippets
final globalSnippetsProvider = StreamProvider<List<SnippetEntity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.snippetDao.watchGlobalSnippets();
});

/// Stream provider for project snippets (family provider)
final projectSnippetsProvider =
    StreamProvider.family<List<SnippetEntity>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.snippetDao.watchProjectSnippets(projectId);
    });

/// Provider for snippet controller
final snippetControllerProvider = Provider((ref) => SnippetController(ref));

// =============================================================================
// LEVEL 10: Saved Prompt Providers
// =============================================================================

/// Stream provider for global saved prompts
final globalSavedPromptsProvider = StreamProvider<List<SavedPromptEntity>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return db.savedPromptDao.watchGlobalSavedPrompts();
});

/// Stream provider for project saved prompts (family provider)
final projectSavedPromptsProvider =
    StreamProvider.family<List<SavedPromptEntity>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.savedPromptDao.watchProjectSavedPrompts(projectId);
    });

/// Provider for saved prompt controller
final savedPromptControllerProvider = Provider(
  (ref) => SavedPromptController(ref),
);

// =============================================================================
// LEVEL 11: LLM Settings Providers
// =============================================================================

/// Provider for managing global LLM settings
final globalLlmSettingsProvider =
    StateNotifierProvider<GlobalLlmSettingsNotifier, List<LlmApiSettings>>((
      ref,
    ) {
      final settings = ref.watch(globalSettingsProvider);
      final settingsNotifier = ref.watch(globalSettingsProvider.notifier);
      final keychainService = ref.watch(keychainServiceProvider);
      return GlobalLlmSettingsNotifier(
        settingsNotifier,
        keychainService,
        settings.llmSettings,
      );
    });

/// Provider for managing project-specific LLM settings (family provider)
final projectLlmSettingsProvider =
    StateNotifierProvider.family<
      ProjectLlmSettingsNotifier,
      List<LlmApiSettings>,
      String
    >((ref, projectId) {
      final settings = ref.watch(projectSettingsProvider(projectId));
      final settingsNotifier = ref.watch(
        projectSettingsProvider(projectId).notifier,
      );
      final keychainService = ref.watch(keychainServiceProvider);
      return ProjectLlmSettingsNotifier(
        projectId,
        settingsNotifier,
        keychainService,
        settings?.llmSettings ?? [],
      );
    });

// =============================================================================
// LEVEL 12: SSH Settings Providers
// =============================================================================

/// Provider for project SSH settings (family provider)
final projectSshSettingsProvider =
    StateNotifierProvider.family<
      ProjectSshSettingsNotifier,
      SshSettings?,
      String
    >((ref, projectId) {
      final projectSettings = ref.watch(projectSettingsProvider(projectId));
      final keychain = ref.watch(keychainServiceProvider);
      final settingsNotifier = ref.watch(
        projectSettingsProvider(projectId).notifier,
      );

      return ProjectSshSettingsNotifier(
        projectSettings?.sshSettings,
        settingsNotifier,
        keychain,
        projectId,
      );
    });

// =============================================================================
// LEVEL 13: Service Providers
// =============================================================================

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

/// Provider for the shell service
/// Now requires a project ID to access SSH settings
final shellServiceProvider = Provider.family<ShellService, String?>((
  ref,
  projectId,
) {
  if (projectId == null) {
    return ShellService(null, null, null);
  }

  final sshSettings = ref.watch(projectSshSettingsProvider(projectId));
  final keychain = ref.watch(keychainServiceProvider);
  return ShellService(sshSettings, keychain, projectId);
});

// =============================================================================
// LEVEL 14: Chat Controller Provider
// =============================================================================

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

      // Get database facade
      final db = ref.watch(databaseProvider);

      // Get sessionMutexDao for local execution locking (may be null if no project)
      final sessionMutexDao = db.projectDatabase?.sessionMutexDao;

      // Create conversation summarizer for local execution
      final llmService = ref.watch(llmServiceProvider);
      final conversationSummarizer = db.projectDatabase != null
          ? ConversationSummarizer(
              messageDao: db.messageDao,
              llmStream: (conversation) => llmService.streamChat(conversation),
            )
          : null;

      return ChatController(
        messageDao: db.messageDao,
        sessionDao: db.sessionDao,
        sessionMutexDao: sessionMutexDao,
        llmService: ref.watch(llmServiceProvider),
        shellService: ref.watch(shellServiceProvider(projectId)),
        secretRedactor: secretRedactor,
        sshSettings: sshSettings,
        project: currentProject,
        conversationSummarizer: conversationSummarizer,
        sessionId: sessionId,
      );
    });
