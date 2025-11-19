import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/llm_api_settings.dart';
import '../models/settings.dart';
import '../services/keychain_service.dart';
import 'settings_provider.dart';
import 'secret_provider.dart';

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
    required LlmApiType apiType,
    required String baseUrl,
    required String apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
  }) async {
    final now = DateTime.now();
    final newSettings = LlmApiSettings(
      identifier: identifier,
      apiType: apiType,
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

    // If this is the first model, automatically set it as default
    final isFirstModel = state.isEmpty;
    final defaultLlmIdentifier = isFirstModel
        ? identifier
        : _settingsNotifier.state.defaultLlmIdentifier;

    await _settingsNotifier.updateSettings(
      _settingsNotifier.state.copyWith(
        llmSettings: updatedList,
        defaultLlmIdentifier: defaultLlmIdentifier,
        updatedAt: now,
      ),
    );
  }

  /// Update an existing LLM configuration
  Future<void> updateLlmSettings({
    required String identifier,
    String? originalIdentifier,
    LlmApiType? apiType,
    required String baseUrl,
    String? apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool? enabled,
  }) async {
    final now = DateTime.now();
    final lookupId = originalIdentifier ?? identifier;
    final index = state.indexWhere((s) => s.identifier == lookupId);

    if (index == -1) {
      throw Exception('LLM settings with identifier "$lookupId" not found');
    }

    final existing = state[index];
    final updatedSettings = existing.copyWith(
      identifier: identifier,
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

    // If renamed, handle key migration
    if (originalIdentifier != null && originalIdentifier != identifier) {
      // If no new key provided, migrate the old one
      if (apiKey == null) {
        final oldKey = await _keychainService.getGlobalSecret(
          LlmApiKeychainKeys.buildGlobalKey(originalIdentifier),
        );
        if (oldKey != null) {
          await _keychainService.saveGlobalSecret(
            LlmApiKeychainKeys.buildGlobalKey(identifier),
            oldKey,
          );
        }
      }

      // Clean up old key
      await _keychainService.deleteGlobalSecret(
        LlmApiKeychainKeys.buildGlobalKey(originalIdentifier),
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

    // If deleting the default model, clear the default
    final currentDefault = _settingsNotifier.state.defaultLlmIdentifier;
    final newDefault = currentDefault == identifier ? null : currentDefault;

    await _settingsNotifier.updateSettings(
      _settingsNotifier.state.copyWith(
        llmSettings: updatedList,
        defaultLlmIdentifier: newDefault,
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
    required LlmApiType apiType,
    required String baseUrl,
    required String apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
  }) async {
    final now = DateTime.now();
    final newSettings = LlmApiSettings(
      identifier: identifier,
      apiType: apiType,
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

    // If this is the first model, automatically set it as default
    final isFirstModel = state.isEmpty;
    final defaultLlmIdentifier = isFirstModel
        ? identifier
        : currentSettings.defaultLlmIdentifier;

    await _settingsNotifier.updateSettings(
      currentSettings.copyWith(
        llmSettings: updatedList,
        defaultLlmIdentifier: defaultLlmIdentifier,
        updatedAt: now,
      ),
    );
  }

  /// Update an existing LLM configuration for this project
  Future<void> updateLlmSettings({
    required String identifier,
    String? originalIdentifier,
    LlmApiType? apiType,
    required String baseUrl,
    String? apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool? enabled,
  }) async {
    final now = DateTime.now();
    final lookupId = originalIdentifier ?? identifier;
    final index = state.indexWhere((s) => s.identifier == lookupId);

    if (index == -1) {
      throw Exception('LLM settings with identifier "$lookupId" not found');
    }

    final existing = state[index];
    final updatedSettings = existing.copyWith(
      identifier: identifier,
      apiType: apiType ?? existing.apiType,
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

    // If renamed, handle key migration
    if (originalIdentifier != null && originalIdentifier != identifier) {
      // If no new key provided, migrate the old one
      if (apiKey == null) {
        final oldKey = await _keychainService.getProjectSecret(
          _projectId,
          LlmApiKeychainKeys.buildProjectKey(_projectId, originalIdentifier),
        );
        if (oldKey != null) {
          await _keychainService.saveProjectSecret(
            _projectId,
            LlmApiKeychainKeys.buildProjectKey(_projectId, identifier),
            oldKey,
          );
        }
      }

      // Clean up old key
      await _keychainService.deleteProjectSecret(
        _projectId,
        LlmApiKeychainKeys.buildProjectKey(_projectId, originalIdentifier),
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
      // If deleting the default model, clear the default
      final currentDefault = currentSettings.defaultLlmIdentifier;
      final newDefault = currentDefault == identifier ? null : currentDefault;

      await _settingsNotifier.updateSettings(
        currentSettings.copyWith(
          llmSettings: updatedList,
          defaultLlmIdentifier: newDefault,
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
