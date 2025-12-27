import 'dart:async';
import 'package:agent_core/src/services/secrets_crdt.dart';
import 'package:agent_core/src/secrets_storage/secure_storage.dart';

class SecretsService {
  final Future<SecureStorage> Function(String projectId) _storageFactory;
  final Map<String, SecretsCrdt> _crdts = {};

  SecretsService(this._storageFactory);

  Future<SecretsCrdt> getProjectSecretsCrdt(String projectId) async {
    if (_crdts.containsKey(projectId)) {
      return _crdts[projectId]!;
    }

    final storage = await _storageFactory(projectId);
    final crdt = SecretsCrdt(storage);
    _crdts[projectId] = crdt;
    return crdt;
  }

  Future<void> close() async {
    for (final crdt in _crdts.values) {
      await crdt.close();
    }
  }
}
