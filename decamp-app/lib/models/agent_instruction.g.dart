// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_instruction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AgentInstructionImpl _$$AgentInstructionImplFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(r'_$AgentInstructionImpl', json, ($checkedConvert) {
  final val = _$AgentInstructionImpl(
    defaultInstruction: $checkedConvert(
      'defaultInstruction',
      (v) => v as String? ?? '',
    ),
    modelOverrides: $checkedConvert(
      'modelOverrides',
      (v) =>
          (v as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    ),
    createdAt: $checkedConvert(
      'createdAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    updatedAt: $checkedConvert(
      'updatedAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$$AgentInstructionImplToJson(
  _$AgentInstructionImpl instance,
) => <String, dynamic>{
  'defaultInstruction': instance.defaultInstruction,
  'modelOverrides': instance.modelOverrides,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
