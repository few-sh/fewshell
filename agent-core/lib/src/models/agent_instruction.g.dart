// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_instruction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AgentInstructionImpl _$$AgentInstructionImplFromJson(
        Map<String, dynamic> json) =>
    _$AgentInstructionImpl(
      defaultInstruction: json['defaultInstruction'] as String? ?? '',
      modelOverrides: (json['modelOverrides'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$AgentInstructionImplToJson(
        _$AgentInstructionImpl instance) =>
    <String, dynamic>{
      'defaultInstruction': instance.defaultInstruction,
      'modelOverrides': instance.modelOverrides,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
