import 'package:freezed_annotation/freezed_annotation.dart';

part 'ssh_settings.freezed.dart';
part 'ssh_settings.g.dart';

/// Authentication method for SSH connection
enum SshAuthMethod { password, privateKey }

/// SSH connection settings for remote shell access
@freezed
class SshSettings with _$SshSettings {
  const factory SshSettings({
    /// Hostname or IP address of the remote server
    required String host,

    /// SSH port (default is 22)
    @Default(22) int port,

    /// Username for SSH authentication
    required String username,

    /// Authentication method (password or private key)
    @Default(SshAuthMethod.password) SshAuthMethod authMethod,

    /// Secret ID for password (stored in secrets table)
    /// Only used when authMethod is password
    String? passwordSecretId,

    /// Secret ID for private key (stored in secrets table)
    /// Only used when authMethod is privateKey
    String? privateKeySecretId,

    /// Optional passphrase secret ID for encrypted private keys
    String? passphraseSecretId,

    /// Whether this configuration is enabled
    @Default(true) bool enabled,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _SshSettings;

  factory SshSettings.fromJson(Map<String, dynamic> json) =>
      _$SshSettingsFromJson(json);
}
