import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/llm_settings_provider.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/secret_provider.dart';
import 'package:decamp/services/keychain_service.dart';
import 'package:decamp/services/llm_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decamp/providers/theme_provider.dart';
import 'package:decamp/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LLM Settings Integration Test', () {
    late KeychainService keychainService;
    late ProviderContainer container;
    const testProjectId = 'test-project-123';
    const testModelId = 'gpt-test-model';
    const testApiKey = 'sk-test-key-12345';

    setUp(() async {
      // 1. Mock Secure Storage
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      keychainService = KeychainService(storage: storage);

      // 2. Mock Shared Preferences (required by settings providers)
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // 3. Setup Provider Container with overrides
      container = ProviderContainer(
        overrides: [
          // Use our real keychain service with mock storage
          keychainServiceProvider.overrideWithValue(keychainService),

          // Provide mocked SharedPreferences
          sharedPreferencesProvider.overrideWithValue(prefs),

          // Set the current project to our test project initially
          currentProjectIdProvider.overrideWith((ref) => testProjectId),

          // Mock current project entity to avoid DB access, respecting currentProjectId
          currentProjectProvider.overrideWith((ref) {
            final id = ref.watch(currentProjectIdProvider);
            if (id == null) return null;
            return ProjectEntity(
              id: id,
              name: 'Test Project',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              lastSessionDate: DateTime.now(),
            );
          }),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // Helper function to verify settings flow
    Future<void> verifySettingsFlow({required bool isGlobal}) async {
      // Setup based on scope
      final BaseLlmSettingsNotifier notifier;
      List<LlmApiSettings> Function() getSettings;
      Future<String?> Function(String modelId) getStoredKey;

      if (isGlobal) {
        // Clear current project so LlmService falls back to global
        container.read(currentProjectIdProvider.notifier).state = null;

        notifier = container.read(globalLlmSettingsProvider.notifier);
        getSettings = () => container.read(globalLlmSettingsProvider);
        getStoredKey = (modelId) => keychainService.getGlobalSecret(
          LlmApiKeychainKeys.buildGlobalKey(modelId),
        );
      } else {
        // Ensure project is set
        container.read(currentProjectIdProvider.notifier).state = testProjectId;

        notifier = container.read(
          projectLlmSettingsProvider(testProjectId).notifier,
        );
        getSettings = () =>
            container.read(projectLlmSettingsProvider(testProjectId));
        getStoredKey = (modelId) => keychainService.getProjectSecret(
          testProjectId,
          LlmApiKeychainKeys.buildProjectKey(testProjectId, modelId),
        );
      }

      // 1. Add Model
      await notifier.addLlmSettings(
        identifier: testModelId,
        apiType: LlmApiType.openai,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: testApiKey,
      );

      // Verify saved
      final settings = getSettings();
      expect(settings.length, 1);
      expect(settings.first.identifier, testModelId);

      // Verify Key Storage
      final storedKey = await getStoredKey(testModelId);
      expect(storedKey, testApiKey);

      // Verify Retrieval via Service
      final llmService = container.read(llmServiceProvider);
      bool isConfigured = false;
      try {
        isConfigured = await llmService.isConfigured();
      } catch (e) {
        fail('LlmService threw exception: $e');
      }
      expect(isConfigured, true);

      // 2. Rename Model (Migration Test)
      const newModelId = 'gpt-renamed';
      await notifier.updateLlmSettings(
        identifier: newModelId,
        originalIdentifier: testModelId,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: null,
      );

      // Verify Old Key Gone
      final oldKey = await getStoredKey(testModelId);
      expect(oldKey, null);

      // Verify New Key Exists
      final newKey = await getStoredKey(newModelId);
      expect(newKey, testApiKey);

      // Verify Service still works
      try {
        isConfigured = await llmService.isConfigured();
      } catch (e) {
        fail('LlmService failed after rename: $e');
      }
      expect(isConfigured, true);
    }

    test('Project Settings Flow (Add, Retrieve, Rename)', () async {
      await verifySettingsFlow(isGlobal: false);
    });

    test('Global Settings Flow (Add, Retrieve, Rename)', () async {
      await verifySettingsFlow(isGlobal: true);
    });
  });
}
