import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/llm_api_settings.dart';
import '../models/settings.dart';
import '../services/keychain_service.dart';
import 'settings_provider.dart';

/// Provider for keychain service instance
final keychainServiceProvider = Provider<KeychainService>((ref) {
  return KeychainService();
});

/// Provider for managing global LLM settings
final globalLlmSettingsProvider =
    StateNotifierProvider<GlobalLlmSettingsNotifier, List<LlmApiSettings>>((
      ref,
    ) {
      final settingsNotifier = ref.watch(globalSettingsProvider.notifier);
      final keychainService = ref.watch(keychainServiceProvider);
      return GlobalLlmSettingsNotifier(settingsNotifier, keychainService);
    });

/// Provider for managing project-specific LLM settings (family provider)
final projectLlmSettingsProvider =
    StateNotifierProvider.family<
      ProjectLlmSettingsNotifier,
      List<LlmApiSettings>,
      String
    >((ref, projectId) {
      final settingsNotifier = ref.watch(
        projectSettingsProvider(projectId).notifier,
      );
      final keychainService = ref.watch(keychainServiceProvider);
      return ProjectLlmSettingsNotifier(
        projectId,
        settingsNotifier,
        keychainService,
      );
    });

/// StateNotifier for global LLM settings
class GlobalLlmSettingsNotifier extends StateNotifier<List<LlmApiSettings>> {
  final GlobalSettingsNotifier _settingsNotifier;
  final KeychainService _keychainService;

  GlobalLlmSettingsNotifier(this._settingsNotifier, this._keychainService)
    : super([]) {
    _loadSettings();
  }

  /// Load LLM settings from app settings
  void _loadSettings() {
    state = _settingsNotifier.state.llmSettings;
  }

  /// Add a new LLM configuration with API key
  Future<void> addLlmSettings({
    required String identifier,
    required String baseUrl,
    required String apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
  }) async {
    final now = DateTime.now();
    final newSettings = LlmApiSettings(
      identifier: identifier,
      baseUrl: baseUrl,
      customHeaders: customHeaders,
      maxTokens: maxTokens,
      temperature: temperature,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );

    // Save API key to keychain
    await _keychainService.saveGlobalSecret(
      LlmApiKeychainKeys.buildGlobalKey(identifier),
      apiKey,
    );

    // Update settings
    final updatedList = [...state, newSettings];
    state = updatedList;

    await _settingsNotifier.updateSettings(
      _settingsNotifier.state.copyWith(
        llmSettings: updatedList,
        updatedAt: now,
      ),
    );
  }

  /// Update an existing LLM configuration
  Future<void> updateLlmSettings({
    required String identifier,
    required String baseUrl,
    String? apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool? enabled,
  }) async {
    final now = DateTime.now();
    final index = state.indexWhere((s) => s.identifier == identifier);

    if (index == -1) {
      throw Exception('LLM settings with identifier "$identifier" not found');
    }

    final existing = state[index];
    final updatedSettings = existing.copyWith(
      baseUrl: baseUrl,
      customHeaders: customHeaders,
      maxTokens: maxTokens,
      temperature: temperature,
      enabled: enabled ?? existing.enabled,
      updatedAt: now,
    );

    // Update API key in keychain if provided
    if (apiKey != null) {
      await _keychainService.saveGlobalSecret(
        LlmApiKeychainKeys.buildGlobalKey(identifier),
        apiKey,
      );
    }

    // Update settings
    final updatedList = [...state];
    updatedList[index] = updatedSettings;
    state = updatedList;

    await _settingsNotifier.updateSettings(
      _settingsNotifier.state.copyWith(
        llmSettings: updatedList,
        updatedAt: now,
      ),
    );
  }

  /// Delete an LLM configuration
  Future<void> deleteLlmSettings(String identifier) async {
    // Delete API key from keychain
    await _keychainService.deleteGlobalSecret(
      LlmApiKeychainKeys.buildGlobalKey(identifier),
    );

    // Update settings
    final updatedList = state.where((s) => s.identifier != identifier).toList();
    state = updatedList;

    await _settingsNotifier.updateSettings(
      _settingsNotifier.state.copyWith(
        llmSettings: updatedList,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Get API key for a specific LLM configuration
  Future<String?> getApiKey(String identifier) async {
    return await _keychainService.getGlobalSecret(
      LlmApiKeychainKeys.buildGlobalKey(identifier),
    );
  }

  /// Set the default LLM identifier
  Future<void> setDefaultLlm(String identifier) async {
    await _settingsNotifier.updateSettings(
      _settingsNotifier.state.copyWith(
        defaultLlmIdentifier: identifier,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

/// StateNotifier for project-specific LLM settings
class ProjectLlmSettingsNotifier extends StateNotifier<List<LlmApiSettings>> {
  final String _projectId;
  final ProjectSettingsNotifier _settingsNotifier;
  final KeychainService _keychainService;

  ProjectLlmSettingsNotifier(
    this._projectId,
    this._settingsNotifier,
    this._keychainService,
  ) : super([]) {
    _loadSettings();
  }

  /// Load LLM settings from project settings
  void _loadSettings() {
    final projectSettings = _settingsNotifier.state;
    state = projectSettings?.llmSettings ?? [];
  }

  /// Add a new LLM configuration with API key for this project
  Future<void> addLlmSettings({
    required String identifier,
    required String baseUrl,
    required String apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
  }) async {
    final now = DateTime.now();
    final newSettings = LlmApiSettings(
      identifier: identifier,
      baseUrl: baseUrl,
      customHeaders: customHeaders,
      maxTokens: maxTokens,
      temperature: temperature,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );

    // Save API key to keychain with project scope
    await _keychainService.saveProjectSecret(
      _projectId,
      LlmApiKeychainKeys.buildProjectKey(_projectId, identifier),
      apiKey,
    );

    // Update settings
    final updatedList = [...state, newSettings];
    state = updatedList;

    final currentSettings =
        _settingsNotifier.state ??
        ProjectSettings(projectId: _projectId, createdAt: now, updatedAt: now);

    await _settingsNotifier.updateSettings(
      currentSettings.copyWith(llmSettings: updatedList, updatedAt: now),
    );
  }

  /// Update an existing LLM configuration for this project
  Future<void> updateLlmSettings({
    required String identifier,
    required String baseUrl,
    String? apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool? enabled,
  }) async {
    final now = DateTime.now();
    final index = state.indexWhere((s) => s.identifier == identifier);

    if (index == -1) {
      throw Exception('LLM settings with identifier "$identifier" not found');
    }

    final existing = state[index];
    final updatedSettings = existing.copyWith(
      baseUrl: baseUrl,
      customHeaders: customHeaders,
      maxTokens: maxTokens,
      temperature: temperature,
      enabled: enabled ?? existing.enabled,
      updatedAt: now,
    );

    // Update API key in keychain if provided
    if (apiKey != null) {
      await _keychainService.saveProjectSecret(
        _projectId,
        LlmApiKeychainKeys.buildProjectKey(_projectId, identifier),
        apiKey,
      );
    }

    // Update settings
    final updatedList = [...state];
    updatedList[index] = updatedSettings;
    state = updatedList;

    final currentSettings = _settingsNotifier.state;
    if (currentSettings != null) {
      await _settingsNotifier.updateSettings(
        currentSettings.copyWith(llmSettings: updatedList, updatedAt: now),
      );
    }
  }

  /// Delete an LLM configuration for this project
  Future<void> deleteLlmSettings(String identifier) async {
    // Delete API key from keychain
    await _keychainService.deleteProjectSecret(
      _projectId,
      LlmApiKeychainKeys.buildProjectKey(_projectId, identifier),
    );

    // Update settings
    final updatedList = state.where((s) => s.identifier != identifier).toList();
    state = updatedList;

    final currentSettings = _settingsNotifier.state;
    if (currentSettings != null) {
      await _settingsNotifier.updateSettings(
        currentSettings.copyWith(
          llmSettings: updatedList,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Get API key for a specific LLM configuration in this project
  Future<String?> getApiKey(String identifier) async {
    return await _keychainService.getProjectSecret(
      _projectId,
      LlmApiKeychainKeys.buildProjectKey(_projectId, identifier),
    );
  }

  /// Set the default LLM identifier for this project
  Future<void> setDefaultLlm(String identifier) async {
    final currentSettings = _settingsNotifier.state;
    if (currentSettings != null) {
      await _settingsNotifier.updateSettings(
        currentSettings.copyWith(
          defaultLlmIdentifier: identifier,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }
}
