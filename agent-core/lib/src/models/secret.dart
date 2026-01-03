import 'package:json_annotation/json_annotation.dart';

part 'secret.g.dart';

@JsonSerializable()
class Secret {
  final String value;
  final bool isVisibleToLlm;

  const Secret({
    required this.value,
    this.isVisibleToLlm = true,
  });

  factory Secret.fromJson(Map<String, dynamic> json) => _$SecretFromJson(json);

  Map<String, dynamic> toJson() => _$SecretToJson(this);

  Secret copyWith({
    String? value,
    bool? isVisibleToLlm,
  }) {
    return Secret(
      value: value ?? this.value,
      isVisibleToLlm: isVisibleToLlm ?? this.isVisibleToLlm,
    );
  }
}
