import 'package:decamp/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';

// Circular import for provider access

// Re-export classes for providers.dart to import
export 'package:agent_core/agent_core.dart'
    show LlmApiSettings, LlmApiType, LlmApiKeychainKeys;

/// Base class for LLM settings logic to reduce duplication
abstract class BaseLlmSettingsNotifier
    extends StateNotifier<List<LlmApiSettings>> {
  final KeychainService _keychainService;

  BaseLlmSettingsNotifier(
    this._keychainService,
    List<LlmApiSettings> initialSettings,
  ) : super(initialSettings);

  // Abstract methods implemented by subclasses
  Future<void> _saveSecret(String identifier, String key);
  Future<String?> _getSecret(String identifier);
  Future<void> _deleteSecret(String identifier);
  Future<void> _saveSettings(
    List<LlmApiSettings> settings, {
    String? newDefaultIdentifier,
    bool updateDefault = false,
  });
  String? get _currentDefaultIdentifier;

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
    final currentState = [...state];
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

    await _saveSecret(identifier, apiKey);

    final updatedList = [...currentState, newSettings];
    if (mounted) {
      state = updatedList;
    }

    final isFirstModel = updatedList.length == 1;
    final defaultLlmIdentifier = isFirstModel
        ? identifier
        : _currentDefaultIdentifier;

    await _saveSettings(
      updatedList,
      newDefaultIdentifier: defaultLlmIdentifier,
      updateDefault: true,
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
    final currentState = [...state];
    final now = DateTime.now();
    final lookupId = originalIdentifier ?? identifier;
    final index = currentState.indexWhere((s) => s.identifier == lookupId);

    if (index == -1) {
      throw Exception('LLM settings with identifier "$lookupId" not found');
    }

    final existing = currentState[index];
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

    if (apiKey != null) {
      await _saveSecret(identifier, apiKey);
    }

    // If renamed, handle key migration
    if (originalIdentifier != null && originalIdentifier != identifier) {
      if (apiKey == null) {
        final oldKey = await _getSecret(originalIdentifier);
        if (oldKey != null) {
          await _saveSecret(identifier, oldKey);
        }
      }
      await _deleteSecret(originalIdentifier);
    }

    final updatedList = currentState;
    updatedList[index] = updatedSettings;
    if (mounted) {
      state = updatedList;
    }

    await _saveSettings(updatedList);
  }

  /// Delete an LLM configuration
  Future<void> deleteLlmSettings(String identifier) async {
    final currentState = [...state];
    await _deleteSecret(identifier);

    final updatedList = currentState
        .where((s) => s.identifier != identifier)
        .toList();
    if (mounted) {
      state = updatedList;
    }

    final currentDefault = _currentDefaultIdentifier;
    final newDefault = currentDefault == identifier ? null : currentDefault;

    await _saveSettings(
      updatedList,
      newDefaultIdentifier: newDefault,
      updateDefault: true,
    );
  }

  /// Get API key for a specific LLM configuration
  Future<String?> getApiKey(String identifier) async {
    return await _getSecret(identifier);
  }

  /// Set the default LLM identifier
  Future<void> setDefaultLlm(String identifier) async {
    await _saveSettings(
      state,
      newDefaultIdentifier: identifier,
      updateDefault: true,
    );
  }
}

/// StateNotifier for global LLM settings
class GlobalLlmSettingsNotifier extends BaseLlmSettingsNotifier {
  final GlobalSettingsNotifier _settingsNotifier;

  GlobalLlmSettingsNotifier(
    this._settingsNotifier,
    KeychainService keychainService,
    List<LlmApiSettings> initialSettings,
  ) : super(keychainService, initialSettings);

  @override
  String? get _currentDefaultIdentifier =>
      _settingsNotifier.state.defaultLlmIdentifier;

  @override
  Future<void> _saveSecret(String identifier, String key) {
    return _keychainService.saveGlobalSecret(
      LlmApiKeychainKeys.buildGlobalKey(identifier),
      Secret(value: key, isVisibleToLlm: false),
    );
  }

  @override
  Future<String?> _getSecret(String identifier) {
    return _keychainService.getGlobalSecret(
      LlmApiKeychainKeys.buildGlobalKey(identifier),
    );
  }

  @override
  Future<void> _deleteSecret(String identifier) {
    return _keychainService.deleteGlobalSecret(
      LlmApiKeychainKeys.buildGlobalKey(identifier),
    );
  }

  @override
  Future<void> _saveSettings(
    List<LlmApiSettings> settings, {
    String? newDefaultIdentifier,
    bool updateDefault = false,
  }) {
    return _settingsNotifier.updateSettings(
      _settingsNotifier.state.copyWith(
        llmSettings: settings,
        defaultLlmIdentifier: updateDefault
            ? newDefaultIdentifier
            : _settingsNotifier.state.defaultLlmIdentifier,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

/// StateNotifier for project-specific LLM settings
class ProjectLlmSettingsNotifier extends BaseLlmSettingsNotifier {
  final String _projectId;
  final ProjectSettingsNotifier _settingsNotifier;

  ProjectLlmSettingsNotifier(
    this._projectId,
    this._settingsNotifier,
    KeychainService keychainService,
    List<LlmApiSettings> initialSettings,
  ) : super(keychainService, initialSettings);

  @override
  String? get _currentDefaultIdentifier =>
      _settingsNotifier.state?.defaultLlmIdentifier;

  @override
  Future<void> _saveSecret(String identifier, String key) {
    return _keychainService.saveProjectSecret(
      _projectId,
      LlmApiKeychainKeys.buildProjectKey(_projectId, identifier),
      Secret(value: key, isVisibleToLlm: false),
    );
  }

  @override
  Future<String?> _getSecret(String identifier) {
    return _keychainService.getProjectSecret(
      _projectId,
      LlmApiKeychainKeys.buildProjectKey(_projectId, identifier),
    );
  }

  @override
  Future<void> _deleteSecret(String identifier) {
    return _keychainService.deleteProjectSecret(
      _projectId,
      LlmApiKeychainKeys.buildProjectKey(_projectId, identifier),
    );
  }

  @override
  Future<void> _saveSettings(
    List<LlmApiSettings> settings, {
    String? newDefaultIdentifier,
    bool updateDefault = false,
  }) async {
    final currentSettings =
        _settingsNotifier.state ??
        ProjectSettings(
          projectId: _projectId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    await _settingsNotifier.updateSettings(
      currentSettings.copyWith(
        llmSettings: settings,
        defaultLlmIdentifier: updateDefault
            ? newDefaultIdentifier
            : currentSettings.defaultLlmIdentifier,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
