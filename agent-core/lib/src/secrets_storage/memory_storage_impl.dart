import 'package:agent_core/src/secrets_storage/secure_storage.dart';

class MemoryStorageImpl implements SecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _storage[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map.from(_storage);
  }

  @override
  Future<void> deleteAll() async {
    _storage.clear();
  }
}
