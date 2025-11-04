import 'package:freezed_annotation/freezed_annotation.dart';

part 'secret.freezed.dart';
part 'secret.g.dart';

/// Represents metadata for a secret.
/// The actual secret value is stored securely in the keychain/secure storage.
@freezed
class Secret with _$Secret {
  const factory Secret({
    required String id,
    String? projectId, // null for global secrets
    required String key,
    required String description,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Secret;

  factory Secret.fromJson(Map<String, dynamic> json) => _$SecretFromJson(json);
}
