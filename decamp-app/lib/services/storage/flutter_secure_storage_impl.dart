import 'package:agent_core/agent_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FlutterSecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageImpl({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> write({required String key, required String value}) async {
    await _storage.write(
      key: key,
      value: value,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  @override
  Future<String?> read({required String key}) async {
    return await _storage.read(
      key: key,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  @override
  Future<void> delete({required String key}) async {
    await _storage.delete(
      key: key,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  @override
  Future<Map<String, String>> readAll() async {
    return await _storage.readAll(
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll(
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  AndroidOptions _getAndroidOptions() {
    return const AndroidOptions(encryptedSharedPreferences: true);
  }

  IOSOptions _getIOSOptions() {
    return const IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  }
}
