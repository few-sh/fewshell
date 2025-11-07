import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ssh_settings.dart';
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
      final secretsActions = ref.watch(projectSecretsProvider(projectId));
      final settingsNotifier = ref.watch(
        projectSettingsProvider(projectId).notifier,
      );

      return ProjectSshSettingsNotifier(
        projectSettings?.sshSettings,
        settingsNotifier,
        secretsActions,
        projectId,
      );
    });

/// StateNotifier for managing SSH settings for a project
class ProjectSshSettingsNotifier extends StateNotifier<SshSettings?> {
  final ProjectSettingsNotifier _settingsNotifier;
  final ProjectSecretsActions _secretsActions;

  ProjectSshSettingsNotifier(
    SshSettings? initialSettings,
    this._settingsNotifier,
    this._secretsActions,
    String projectId,
  ) : super(initialSettings);

  /// Create new SSH settings for the project
  Future<void> createSshSettings({
    required String host,
    required int port,
    required String username,
    required SshAuthMethod authMethod,
    String? password,
    String? privateKey,
    String? passphrase,
  }) async {
    // Generate secret IDs
    String? passwordSecretId;
    String? privateKeySecretId;
    String? passphraseSecretId;

    // Store secrets in keychain
    if (authMethod == SshAuthMethod.password &&
        password != null &&
        password.isNotEmpty) {
      passwordSecretId = _generateSecretId('ssh_password');
      await _secretsActions.saveSecret(passwordSecretId, password);
    } else if (authMethod == SshAuthMethod.privateKey) {
      if (privateKey != null && privateKey.isNotEmpty) {
        privateKeySecretId = _generateSecretId('ssh_privatekey');
        await _secretsActions.saveSecret(privateKeySecretId, privateKey);
      }
      if (passphrase != null && passphrase.isNotEmpty) {
        passphraseSecretId = _generateSecretId('ssh_passphrase');
        await _secretsActions.saveSecret(passphraseSecretId, passphrase);
      }
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
    bool? enabled,
  }) async {
    final current = state;
    if (current == null) {
      throw Exception('No SSH settings to update. Create settings first.');
    }

    String? passwordSecretId = current.passwordSecretId;
    String? privateKeySecretId = current.privateKeySecretId;
    String? passphraseSecretId = current.passphraseSecretId;

    final effectiveAuthMethod = authMethod ?? current.authMethod;

    // Handle password updates
    if (effectiveAuthMethod == SshAuthMethod.password) {
      if (password != null && password.isNotEmpty) {
        // Delete old password secret if it exists and auth method changed
        if (current.authMethod != SshAuthMethod.password &&
            current.passwordSecretId != null) {
          await _secretsActions.deleteSecret(current.passwordSecretId!);
        }

        // Create new password secret or update existing
        if (passwordSecretId == null) {
          passwordSecretId = _generateSecretId('ssh_password');
        }
        await _secretsActions.saveSecret(passwordSecretId, password);
      }

      // Clear private key secrets if switching from key auth
      if (current.authMethod == SshAuthMethod.privateKey) {
        if (current.privateKeySecretId != null) {
          await _secretsActions.deleteSecret(current.privateKeySecretId!);
        }
        if (current.passphraseSecretId != null) {
          await _secretsActions.deleteSecret(current.passphraseSecretId!);
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
        await _secretsActions.deleteSecret(current.passwordSecretId!);
        passwordSecretId = null;
      }

      // Update private key
      if (privateKey != null && privateKey.isNotEmpty) {
        if (privateKeySecretId == null) {
          privateKeySecretId = _generateSecretId('ssh_privatekey');
        }
        await _secretsActions.saveSecret(privateKeySecretId, privateKey);
      }

      // Update passphrase
      if (passphrase != null) {
        if (passphrase.isNotEmpty) {
          if (passphraseSecretId == null) {
            passphraseSecretId = _generateSecretId('ssh_passphrase');
          }
          await _secretsActions.saveSecret(passphraseSecretId, passphrase);
        } else if (passphraseSecretId != null) {
          // Clear passphrase if empty string provided
          await _secretsActions.deleteSecret(passphraseSecretId);
          passphraseSecretId = null;
        }
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
      await _secretsActions.deleteSecret(current.passwordSecretId!);
    }
    if (current.privateKeySecretId != null) {
      await _secretsActions.deleteSecret(current.privateKeySecretId!);
    }
    if (current.passphraseSecretId != null) {
      await _secretsActions.deleteSecret(current.passphraseSecretId!);
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
    return await _secretsActions.getSecret(secretId);
  }

  /// Test SSH connection with current settings
  Future<bool> testConnection() async {
    final current = state;
    if (current == null || !current.enabled) {
      return false;
    }

    // TODO: Implement actual SSH connection test
    // This would use the ssh_client package or similar
    // For now, just return true as a placeholder
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}
