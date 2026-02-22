import 'package:json_annotation/json_annotation.dart';

part 'secret.g.dart';

@JsonSerializable()
class Secret {
  final String value;
  final bool isVisibleToLlm;
  final bool
      isSystem; // Indicates if this is a system secret that should not be possible to manually delete (e.g. for built-in SSH keys)

  const Secret({
    required this.value,
    this.isVisibleToLlm = true,
    this.isSystem = false,
  });

  factory Secret.fromJson(Map<String, dynamic> json) => _$SecretFromJson(json);

  Map<String, dynamic> toJson() => _$SecretToJson(this);

  Secret copyWith({
    String? value,
    bool? isVisibleToLlm,
    bool? isSystem,
  }) {
    return Secret(
      value: value ?? this.value,
      isVisibleToLlm: isVisibleToLlm ?? this.isVisibleToLlm,
      isSystem: isSystem ?? this.isSystem,
    );
  }
}
