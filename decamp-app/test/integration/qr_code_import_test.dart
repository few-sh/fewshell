import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/services/project_importer.dart';
import 'package:decamp/providers/llm_settings_provider.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/secret_provider.dart';
import 'package:decamp/providers/theme_provider.dart';
import 'package:agent_core/src/services/keychain_service.dart';
import 'package:decamp/services/storage/flutter_secure_storage_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QR Code Import Integration Tests', () {
    late KeychainService keychainService;
    late ProviderContainer container;
    const testProjectId = 'test-project-qr-123';

    setUp(() async {
      // 1. Mock Secure Storage
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      keychainService = KeychainService(
        FlutterSecureStorageImpl(storage: storage),
      );

      // 2. Mock Shared Preferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // 3. Setup Provider Container with overrides
      container = ProviderContainer(
        overrides: [
          keychainServiceProvider.overrideWithValue(keychainService),
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentProjectIdProvider.overrideWith((ref) => testProjectId),
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

    test('Import QR code with only LLM settings to project', () async {
      // 1. Verify project has no LLM settings initially
      final initialModels = container.read(
        projectLlmSettingsProvider(testProjectId),
      );
      expect(
        initialModels,
        isEmpty,
        reason: 'Project should start with no LLM models',
      );
      print('Initial models count: ${initialModels.length}');

      // 2. Create QR code data (matching the format from get.few.sh)
      final qrData = {
        'l': 'openai', // provider label
        'k': 'sk-test-key-1234567890abcdefghijklmnopqrstuvwxyz', // API key
      };
      final qrJson = jsonEncode(qrData);

      print('QR JSON: $qrJson');

      // 3. Import the QR code
      final importer = container.read(projectImporterProvider);

      try {
        await importer.importFromQrCode(qrJson, targetProjectId: testProjectId);
        print('Import completed without throwing');
      } catch (e, stackTrace) {
        print('Import threw error: $e');
        print('Stack trace: $stackTrace');
        fail('Import should not throw: $e');
      }

      // 4. Verify LLM settings were added
      final updatedModels = container.read(
        projectLlmSettingsProvider(testProjectId),
      );
      print('Updated models count: ${updatedModels.length}');

      if (updatedModels.isEmpty) {
        fail(
          'Project should have LLM models after import, but has ${updatedModels.length}',
        );
      }

      expect(updatedModels.length, 1, reason: 'Should have exactly 1 model');

      final model = updatedModels.first;
      print('Model identifier: ${model.identifier}');
      print('Model apiType: ${model.apiType}');
      print('Model baseUrl: ${model.baseUrl}');

      expect(model.apiType, LlmApiType.openai);

      // 5. Verify API key was saved
      final notifier = container.read(
        projectLlmSettingsProvider(testProjectId).notifier,
      );
      final apiKey = await notifier.getApiKey(model.identifier);
      expect(apiKey, isNotNull, reason: 'API key should be saved');
      expect(apiKey, qrData['k'], reason: 'API key should match QR code data');
    });

    test('Import QR code with anthropic provider', () async {
      final qrData = {'l': 'anthropic', 'k': 'sk-ant-test-key-1234567890'};
      final qrJson = jsonEncode(qrData);

      final importer = container.read(projectImporterProvider);
      await importer.importFromQrCode(qrJson, targetProjectId: testProjectId);

      final models = container.read(projectLlmSettingsProvider(testProjectId));
      expect(models, isNotEmpty);
      expect(models.first.apiType, LlmApiType.anthropic);
    });

    test('Import QR code with google/gemini provider', () async {
      final qrData = {
        'l': 'google', // or 'gemini' should also work
        'k': 'test-google-api-key',
      };
      final qrJson = jsonEncode(qrData);

      final importer = container.read(projectImporterProvider);
      await importer.importFromQrCode(qrJson, targetProjectId: testProjectId);

      final models = container.read(projectLlmSettingsProvider(testProjectId));
      expect(models, isNotEmpty);
      expect(models.first.apiType, LlmApiType.google);
    });

    test('Import QR code with unknown provider should throw', () async {
      final qrData = {'l': 'unknown-provider', 'k': 'test-key'};
      final qrJson = jsonEncode(qrData);

      final importer = container.read(projectImporterProvider);

      expect(
        () => importer.importFromQrCode(qrJson, targetProjectId: testProjectId),
        throwsA(isA<Exception>()),
        reason: 'Should throw exception for unknown provider',
      );
    });

    test('Import QR code with missing API key should not add model', () async {
      final qrData = {
        'l': 'openai',
        // Missing 'k' (API key)
      };
      final qrJson = jsonEncode(qrData);

      final importer = container.read(projectImporterProvider);
      await importer.importFromQrCode(qrJson, targetProjectId: testProjectId);

      // Should not add any models if API key is missing
      final models = container.read(projectLlmSettingsProvider(testProjectId));
      expect(models, isEmpty, reason: 'Should not add model without API key');
    });

    test('Import QR code updates existing model if same identifier', () async {
      // Add initial model with the current default identifier
      final notifier = container.read(
        projectLlmSettingsProvider(testProjectId).notifier,
      );
      await notifier.addLlmSettings(
        identifier: 'gpt-4o', // Current default OpenAI model
        apiType: LlmApiType.openai,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'old-key',
      );

      // Verify initial state
      var models = container.read(projectLlmSettingsProvider(testProjectId));
      expect(models.length, 1);

      // Import QR code with same provider (should update the existing model)
      final qrData = {'l': 'openai', 'k': 'new-key-123'};
      final qrJson = jsonEncode(qrData);

      final importer = container.read(projectImporterProvider);
      await importer.importFromQrCode(qrJson, targetProjectId: testProjectId);

      // Should still have only 1 model (updated, not added)
      models = container.read(projectLlmSettingsProvider(testProjectId));
      expect(models.length, 1);

      // API key should be updated
      final apiKey = await notifier.getApiKey('gpt-4o');
      expect(apiKey, 'new-key-123');
    });
  });
}
