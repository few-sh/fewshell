import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'settings_provider.dart';
import 'secret_provider.dart';

/// Generate a unique ID for secrets
String _generateSecretId(String prefix) {
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 1000}';
}

/// Provider for project SSH settings (family provider)
final projectSshSettingsProvider =
    StateNotifierProvider.family<
      ProjectSshSettingsNotifier,
      SshSettings?,
      String
    >((ref, projectId) {
      final projectSettings = ref.watch(projectSettingsProvider(projectId));
      final keychain = ref.watch(keychainServiceProvider);
      final settingsNotifier = ref.watch(
        projectSettingsProvider(projectId).notifier,
      );

      return ProjectSshSettingsNotifier(
        projectSettings?.sshSettings,
        settingsNotifier,
        keychain,
        projectId,
      );
    });

/// StateNotifier for managing SSH settings for a project
class ProjectSshSettingsNotifier extends StateNotifier<SshSettings?> {
  final ProjectSettingsNotifier _settingsNotifier;
  final KeychainService _keychain;
  final String _projectId;

  ProjectSshSettingsNotifier(
    super.initialSettings,
    this._settingsNotifier,
    this._keychain,
    this._projectId,
  );

  /// Create new SSH settings for the project
  Future<void> createSshSettings({
    required String host,
    required int port,
    required String username,
    required SshAuthMethod authMethod,
    String? password,
    String? privateKey,
    String? passphrase,
    String? sudoPassword,
  }) async {
    // Generate secret IDs
    String? passwordSecretId;
    String? privateKeySecretId;
    String? passphraseSecretId;
    String? sudoPasswordSecretId;

    // Store secrets in keychain
    if (authMethod == SshAuthMethod.password &&
        password != null &&
        password.isNotEmpty) {
      passwordSecretId = _generateSecretId('ssh_password');
      await _keychain.saveProjectSecret(
        _projectId,
        passwordSecretId,
        Secret(value: password, isVisibleToLlm: false),
      );
    } else if (authMethod == SshAuthMethod.privateKey) {
      if (privateKey != null && privateKey.isNotEmpty) {
        privateKeySecretId = _generateSecretId('ssh_privatekey');
        await _keychain.saveProjectSecret(
          _projectId,
          privateKeySecretId,
          Secret(value: privateKey, isVisibleToLlm: false),
        );
      }
      if (passphrase != null && passphrase.isNotEmpty) {
        passphraseSecretId = _generateSecretId('ssh_passphrase');
        await _keychain.saveProjectSecret(
          _projectId,
          passphraseSecretId,
          Secret(value: passphrase, isVisibleToLlm: false),
        );
      }
    }

    // Store sudo password if provided
    if (sudoPassword != null && sudoPassword.isNotEmpty) {
      sudoPasswordSecretId = _generateSecretId('ssh_sudo_password');
      await _keychain.saveProjectSecret(
        _projectId,
        sudoPasswordSecretId,
        Secret(value: sudoPassword, isVisibleToLlm: false),
      );
    }

    // Create SSH settings object
    final sshSettings = SshSettings(
      host: host,
      port: port,
      username: username,
      authMethod: authMethod,
      passwordSecretId: passwordSecretId,
      privateKeySecretId: privateKeySecretId,
      passphraseSecretId: passphraseSecretId,
      sudoPasswordSecretId: sudoPasswordSecretId,
      enabled: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Update state
    state = sshSettings;

    // Persist to project settings
    final currentSettings = _settingsNotifier.state;
    if (currentSettings != null) {
      await _settingsNotifier.updateSettings(
        currentSettings.copyWith(
          sshSettings: sshSettings,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Update existing SSH settings
  Future<void> updateSshSettings({
    String? host,
    int? port,
    String? username,
    SshAuthMethod? authMethod,
    String? password,
    String? privateKey,
    String? passphrase,
    String? sudoPassword,
    bool? enabled,
  }) async {
    final current = state;
    if (current == null) {
      throw Exception('No SSH settings to update. Create settings first.');
    }

    String? passwordSecretId = current.passwordSecretId;
    String? privateKeySecretId = current.privateKeySecretId;
    String? passphraseSecretId = current.passphraseSecretId;
    String? sudoPasswordSecretId = current.sudoPasswordSecretId;

    final effectiveAuthMethod = authMethod ?? current.authMethod;

    // Handle password updates
    if (effectiveAuthMethod == SshAuthMethod.password) {
      if (password != null && password.isNotEmpty) {
        // Delete old password secret if it exists and auth method changed
        if (current.authMethod != SshAuthMethod.password &&
            current.passwordSecretId != null) {
          await _keychain.deleteProjectSecret(
            _projectId,
            current.passwordSecretId!,
          );
        }

        // Create new password secret or update existing
        passwordSecretId ??= _generateSecretId('ssh_password');
        await _keychain.saveProjectSecret(
          _projectId,
          passwordSecretId,
          Secret(value: password, isVisibleToLlm: false),
        );
      }

      // Clear private key secrets if switching from key auth
      if (current.authMethod == SshAuthMethod.privateKey) {
        if (current.privateKeySecretId != null) {
          await _keychain.deleteProjectSecret(
            _projectId,
            current.privateKeySecretId!,
          );
        }
        if (current.passphraseSecretId != null) {
          await _keychain.deleteProjectSecret(
            _projectId,
            current.passphraseSecretId!,
          );
        }
        privateKeySecretId = null;
        passphraseSecretId = null;
      }
    }
    // Handle private key updates
    else if (effectiveAuthMethod == SshAuthMethod.privateKey) {
      // Delete old private key secrets if switching from password
      if (current.authMethod == SshAuthMethod.password &&
          current.passwordSecretId != null) {
        await _keychain.deleteProjectSecret(
          _projectId,
          current.passwordSecretId!,
        );
        passwordSecretId = null;
      }

      // Update private key
      if (privateKey != null && privateKey.isNotEmpty) {
        privateKeySecretId ??= _generateSecretId('ssh_privatekey');
        await _keychain.saveProjectSecret(
          _projectId,
          privateKeySecretId,
          Secret(value: privateKey, isVisibleToLlm: false),
        );
      }

      // Update passphrase
      if (passphrase != null) {
        if (passphrase.isNotEmpty) {
          passphraseSecretId ??= _generateSecretId('ssh_passphrase');
          await _keychain.saveProjectSecret(
            _projectId,
            passphraseSecretId,
            Secret(value: passphrase, isVisibleToLlm: false),
          );
        } else if (passphraseSecretId != null) {
          // Clear passphrase if empty string provided
          await _keychain.deleteProjectSecret(_projectId, passphraseSecretId);
          passphraseSecretId = null;
        }
      }
    }

    // Handle sudo password updates (independent of auth method)
    if (sudoPassword != null) {
      if (sudoPassword.isNotEmpty) {
        sudoPasswordSecretId ??= _generateSecretId('ssh_sudo_password');
        await _keychain.saveProjectSecret(
          _projectId,
          sudoPasswordSecretId,
          Secret(value: sudoPassword, isVisibleToLlm: false),
        );
      } else if (sudoPasswordSecretId != null) {
        // Clear sudo password if empty string provided
        await _keychain.deleteProjectSecret(_projectId, sudoPasswordSecretId);
        sudoPasswordSecretId = null;
      }
    }

    // Update SSH settings
    final updatedSettings = current.copyWith(
      host: host ?? current.host,
      port: port ?? current.port,
      username: username ?? current.username,
      authMethod: effectiveAuthMethod,
      passwordSecretId: passwordSecretId,
      privateKeySecretId: privateKeySecretId,
      passphraseSecretId: passphraseSecretId,
      sudoPasswordSecretId: sudoPasswordSecretId,
      enabled: enabled ?? current.enabled,
      updatedAt: DateTime.now(),
    );

    // Update state
    state = updatedSettings;

    // Persist to project settings
    final currentProjectSettings = _settingsNotifier.state;
    if (currentProjectSettings != null) {
      await _settingsNotifier.updateSettings(
        currentProjectSettings.copyWith(
          sshSettings: updatedSettings,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  /// Delete SSH settings and all associated secrets
  Future<void> deleteSshSettings() async {
    final current = state;
    if (current == null) return;

    // Delete all secrets
    if (current.passwordSecretId != null) {
      await _keychain.deleteProjectSecret(
        _projectId,
        current.passwordSecretId!,
      );
    }
    if (current.privateKeySecretId != null) {
      await _keychain.deleteProjectSecret(
        _projectId,
        current.privateKeySecretId!,
      );
    }
    if (current.passphraseSecretId != null) {
      await _keychain.deleteProjectSecret(
        _projectId,
        current.passphraseSecretId!,
      );
    }

    // Update state
    state = null;

    // Remove from project settings
    final currentSettings = _settingsNotifier.state;
    if (currentSettings != null) {
      await _settingsNotifier.updateSettings(
        currentSettings.copyWith(sshSettings: null, updatedAt: DateTime.now()),
      );
    }
  }

  /// Get a secret value (for display in edit mode)
  Future<String?> getSecret(String secretId) async {
    return await _keychain.getProjectSecret(_projectId, secretId);
  }
}
