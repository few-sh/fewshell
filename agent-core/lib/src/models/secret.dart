/// Metadata for a secret (API key, password, etc).
///
/// The actual secret value is never included in this class.
/// Values are stored separately and referenced by [id].
///
/// This allows clients to see which secrets exist without
/// ever receiving the actual values over the wire.
class SecretMetadata {
  /// Unique identifier for this secret
  final String id;

  /// Project ID (null for global secrets)
  final String? projectId;

  /// Human-readable name (e.g., "OpenAI API Key", "SSH Password")
  final String name;

  /// Optional description
  final String? description;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last updated timestamp
  final DateTime updatedAt;

  const SecretMetadata({
    required this.id,
    this.projectId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (projectId != null) 'projectId': projectId,
        'name': name,
        if (description != null) 'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SecretMetadata.fromJson(Map<String, dynamic> json) => SecretMetadata(
        id: json['id'] as String,
        projectId: json['projectId'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  SecretMetadata copyWith({
    String? id,
    String? projectId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      SecretMetadata(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretMetadata &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SecretMetadata(id: $id, name: $name)';
}

/// A secret with its value (only used server-side for storage).
///
/// This class should NEVER be sent to clients.
/// Use [SecretMetadata] for client-facing APIs.
class Secret extends SecretMetadata {
  /// The actual secret value
  final String value;

  const Secret({
    required super.id,
    super.projectId,
    required super.name,
    super.description,
    required super.createdAt,
    required super.updatedAt,
    required this.value,
  });

  /// Convert to metadata (strips the value for client responses)
  SecretMetadata toMetadata() => SecretMetadata(
        id: id,
        projectId: projectId,
        name: name,
        description: description,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'value': value,
      };

  factory Secret.fromJson(Map<String, dynamic> json) => Secret(
        id: json['id'] as String,
        projectId: json['projectId'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        value: json['value'] as String,
      );
}
