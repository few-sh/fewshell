/// Authentication method for SSH connection.
enum SshAuthMethod {
  password,
  privateKey;

  static SshAuthMethod fromString(String value) {
    switch (value.toLowerCase()) {
      case 'password':
        return SshAuthMethod.password;
      case 'privatekey':
      case 'private_key':
        return SshAuthMethod.privateKey;
      default:
        return SshAuthMethod.password;
    }
  }
}

/// SSH connection settings for remote shell access.
///
/// Secrets (passwords, private keys) are stored separately and referenced by ID.
class SshSettings {
  /// Hostname or IP address of the remote server
  final String host;

  /// SSH port (default is 22)
  final int port;

  /// Username for SSH authentication
  final String username;

  /// Authentication method (password or private key)
  final SshAuthMethod authMethod;

  /// Secret ID for password (stored in secrets)
  /// Only used when authMethod is password
  final String? passwordSecretId;

  /// Secret ID for private key (stored in secrets)
  /// Only used when authMethod is privateKey
  final String? privateKeySecretId;

  /// Optional passphrase secret ID for encrypted private keys
  final String? passphraseSecretId;

  /// Secret ID for sudo password
  final String? sudoPasswordSecretId;

  /// Whether this configuration is enabled
  final bool enabled;

  const SshSettings({
    required this.host,
    this.port = 22,
    required this.username,
    this.authMethod = SshAuthMethod.password,
    this.passwordSecretId,
    this.privateKeySecretId,
    this.passphraseSecretId,
    this.sudoPasswordSecretId,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'authMethod': authMethod.name,
        if (passwordSecretId != null) 'passwordSecretId': passwordSecretId,
        if (privateKeySecretId != null)
          'privateKeySecretId': privateKeySecretId,
        if (passphraseSecretId != null)
          'passphraseSecretId': passphraseSecretId,
        if (sudoPasswordSecretId != null)
          'sudoPasswordSecretId': sudoPasswordSecretId,
        'enabled': enabled,
      };

  factory SshSettings.fromJson(Map<String, dynamic> json) => SshSettings(
        host: json['host'] as String,
        port: json['port'] as int? ?? 22,
        username: json['username'] as String,
        authMethod: SshAuthMethod.fromString(
            json['authMethod'] as String? ?? 'password'),
        passwordSecretId: json['passwordSecretId'] as String?,
        privateKeySecretId: json['privateKeySecretId'] as String?,
        passphraseSecretId: json['passphraseSecretId'] as String?,
        sudoPasswordSecretId: json['sudoPasswordSecretId'] as String?,
        enabled: json['enabled'] as bool? ?? true,
      );

  SshSettings copyWith({
    String? host,
    int? port,
    String? username,
    SshAuthMethod? authMethod,
    String? passwordSecretId,
    String? privateKeySecretId,
    String? passphraseSecretId,
    String? sudoPasswordSecretId,
    bool? enabled,
  }) =>
      SshSettings(
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        authMethod: authMethod ?? this.authMethod,
        passwordSecretId: passwordSecretId ?? this.passwordSecretId,
        privateKeySecretId: privateKeySecretId ?? this.privateKeySecretId,
        passphraseSecretId: passphraseSecretId ?? this.passphraseSecretId,
        sudoPasswordSecretId: sudoPasswordSecretId ?? this.sudoPasswordSecretId,
        enabled: enabled ?? this.enabled,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SshSettings &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          username == other.username &&
          authMethod == other.authMethod &&
          passwordSecretId == other.passwordSecretId &&
          privateKeySecretId == other.privateKeySecretId &&
          passphraseSecretId == other.passphraseSecretId &&
          sudoPasswordSecretId == other.sudoPasswordSecretId &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        host,
        port,
        username,
        authMethod,
        passwordSecretId,
        privateKeySecretId,
        passphraseSecretId,
        sudoPasswordSecretId,
        enabled,
      );

  @override
  String toString() =>
      'SshSettings(host: $host, port: $port, username: $username)';
}
