import 'package:freezed_annotation/freezed_annotation.dart';

part 'secret.freezed.dart';
part 'secret.g.dart';

/// Metadata for a secret (API key, password, etc).
///
/// The actual secret value is never included in this class.
/// Values are stored separately and referenced by [id].
///
/// This allows clients to see which secrets exist without
/// ever receiving the actual values over the wire.
@freezed
class SecretMetadata with _$SecretMetadata {
  const factory SecretMetadata({
    /// Unique identifier for this secret
    required String id,

    /// Project ID (null for global secrets)
    String? projectId,

    /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
    required String name,

    /// Optional description
    String? description,

    /// Creation timestamp
    required DateTime createdAt,

    /// Last updated timestamp
    required DateTime updatedAt,
  }) = _SecretMetadata;

  factory SecretMetadata.fromJson(Map<String, dynamic> json) =>
      _$SecretMetadataFromJson(json);
}

/// A secret with its value (only used server-side for storage).
///
/// This class should NEVER be sent to clients.
/// Use [SecretMetadata] for client-facing APIs.
@freezed
class Secret with _$Secret {
  const Secret._();

  const factory Secret({
    /// Unique identifier for this secret
    required String id,

    /// Project ID (null for global secrets)
    String? projectId,

    /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
    required String name,

    /// Optional description
    String? description,

    /// Creation timestamp
    required DateTime createdAt,

    /// Last updated timestamp
    required DateTime updatedAt,

    /// The actual secret value
    required String value,
  }) = _Secret;

  /// Convert to metadata (strips the value for client responses)
  SecretMetadata toMetadata() => SecretMetadata(
        id: id,
        projectId: projectId,
        name: name,
        description: description,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory Secret.fromJson(Map<String, dynamic> json) => _$SecretFromJson(json);
}
