import 'package:agent_core/src/models/secret.dart';

abstract class SecretsStorage {
  Future<void> write({required String key, required Secret value});
  Future<Secret?> read({required String key});
  Future<void> delete({required String key});
  Future<Map<String, Secret>> readAll();
  Future<void> deleteAll();
}
