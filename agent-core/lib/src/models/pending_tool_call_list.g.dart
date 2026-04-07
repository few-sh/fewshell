// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_tool_call_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PendingToolCall _$PendingToolCallFromJson(Map<String, dynamic> json) =>
    PendingToolCall(
      arguments: json['arguments'] as Map<String, dynamic>,
      originalToolCall:
          ToolCall.fromJson(json['originalToolCall'] as Map<String, dynamic>),
      isSelected: json['isSelected'] as bool? ?? true,
    );

Map<String, dynamic> _$PendingToolCallToJson(PendingToolCall instance) =>
    <String, dynamic>{
      'arguments': instance.arguments,
      'originalToolCall': instance.originalToolCall.toJson(),
      'isSelected': instance.isSelected,
    };

PendingToolCallList _$PendingToolCallListFromJson(Map<String, dynamic> json) =>
    PendingToolCallList(
      (json['items'] as List<dynamic>)
          .map((e) => PendingToolCall.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PendingToolCallListToJson(
        PendingToolCallList instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
    };
