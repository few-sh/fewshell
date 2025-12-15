import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/providers/settings_provider.dart';
import 'package:decamp/services/project_importer.dart';
import 'package:decamp/providers/llm_settings_provider.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/secret_provider.dart';
import 'package:decamp/providers/theme_provider.dart';
import 'package:decamp/services/storage/flutter_secure_storage_impl.dart';
import 'package:logging/logging.dart';

final _log = Logger('QrCodeImportTest');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QR Code Import Integration Tests', () {
    late KeychainService keychainService;
    late ProviderContainer container;
    late GlobalDatabase globalDb;
    late ProjectDatabase projectDb;
    late Directory tempDir;
    const testProjectId = 'test-project-qr-123';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('decamp_test_');

      // 1. Mock Secure Storage
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      keychainService = KeychainService(
        FlutterSecureStorageImpl(storage: storage),
      );

      // 2. Mock Shared Preferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Initialize in-memory databases with CRDT support
      final globalExecutorResult = await CrdtExecutorFactory.createExecutor(
        ':memory:',
        'test-node',
      );
      globalDb = GlobalDatabase(
        globalExecutorResult.executor,
        crdt: globalExecutorResult.crdt,
      );

      final projectExecutorResult = await CrdtExecutorFactory.createExecutor(
        ':memory:',
        'test-node',
      );
      projectDb = ProjectDatabase(
        projectExecutorResult.executor,
        crdt: projectExecutorResult.crdt,
      );

      // 3. Setup Provider Container with overrides
      container = ProviderContainer(
        overrides: [
          keychainServiceProvider.overrideWithValue(keychainService),
          sharedPreferencesProvider.overrideWithValue(prefs),
          globalDatabaseProvider.overrideWithValue(globalDb),
          projectDatabaseProvider.overrideWithValue(projectDb),
          tomlSettingsServiceProvider.overrideWith((ref) {
            return TomlSettingsService(() async => tempDir);
          }),
          currentProjectIdProvider.overrideWith((ref) {
            final prefs = ref.watch(sharedPreferencesProvider);
            final notifier = SelectedProjectNotifier(prefs, ref);
            notifier.state = testProjectId;
            return notifier;
          }),
          currentProjectProvider.overrideWith((ref) {
            final id = ref.watch(currentProjectIdProvider);
            if (id == null) return null;
            return ProjectEntity(
              id: id,
              name: 'Test Project',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              lastSessionDate: DateTime.now(),
              isArchived: false,
            );
          }),
        ],
      );

      // Wait for settings to be loaded for the test project
      await Future.doWhile(() async {
        final settings = container.read(projectSettingsProvider(testProjectId));
        if (settings != null) return false;
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      });
    });

    tearDown(() async {
      await globalDb.close();
      await projectDb.close();
      container.dispose();
      await tempDir.delete(recursive: true);
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
      _log.info('Initial models count: ${initialModels.length}');

      // 2. Create QR code data (matching the format from get.few.sh)
      final qrData = {
        'l': 'openai', // provider label
        'k': 'sk-test-key-1234567890abcdefghijklmnopqrstuvwxyz', // API key
      };
      final qrJson = jsonEncode(qrData);

      _log.info('QR JSON: $qrJson');

      // 3. Import the QR code
      final importer = container.read(projectImporterProvider);

      try {
        await importer.importFromQrCode(qrJson, targetProjectId: testProjectId);
        _log.info('Import completed without throwing');
      } catch (e, stackTrace) {
        _log.info('Import threw error: $e');
        _log.info('Stack trace: $stackTrace');
        fail('Import should not throw: $e');
      }

      // 4. Verify LLM settings were added
      final updatedModels = container.read(
        projectLlmSettingsProvider(testProjectId),
      );
      _log.info('Updated models count: ${updatedModels.length}');

      if (updatedModels.isEmpty) {
        fail(
          'Project should have LLM models after import, but has ${updatedModels.length}',
        );
      }

      expect(updatedModels.length, 1, reason: 'Should have exactly 1 model');

      final model = updatedModels.first;
      _log.info('Model identifier: ${model.identifier}');
      _log.info('Model apiType: ${model.apiType}');
      _log.info('Model baseUrl: ${model.baseUrl}');

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
