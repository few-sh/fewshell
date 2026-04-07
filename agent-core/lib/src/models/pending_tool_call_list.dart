import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:llm_dart/llm_dart.dart';

import '../session_replication/session_replicator.dart';

part 'pending_tool_call_list.g.dart';

/// Represents a tool call that needs approval.
@JsonSerializable(explicitToJson: true)
class PendingToolCall {
  /// Current editable arguments for this tool call.
  final Map<String, dynamic> arguments;

  /// The original tool call emitted by the model.
  final ToolCall originalToolCall;

  /// Whether this tool call is currently selected for approval.
  final bool isSelected;

  String get id => originalToolCall.id;
  String get name => originalToolCall.function.name;

  const PendingToolCall({
    required this.arguments,
    required this.originalToolCall,
    this.isSelected = false,
  });

  factory PendingToolCall.fromJson(Map<String, dynamic> json) =>
      _$PendingToolCallFromJson(json);

  Map<String, dynamic> toJson() => _$PendingToolCallToJson(this);

  PendingToolCall copyWith({
    Map<String, dynamic>? arguments,
    ToolCall? originalToolCall,
    bool? isSelected,
  }) {
    return PendingToolCall(
      arguments: arguments ?? this.arguments,
      originalToolCall: originalToolCall ?? this.originalToolCall,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  PendingToolCall withArguments(Map<String, dynamic> newArguments) {
    return copyWith(arguments: newArguments);
  }

  Map<String, dynamic> toApprovalRequestJson() {
    return {
      'id': id,
      'name': name,
      'arguments': arguments,
    };
  }

  Map<String, dynamic> toApprovalResponseJson() {
    return {
      'id': id,
      'arguments': arguments,
    };
  }

  factory PendingToolCall.fromApprovalRequestJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final args = Map<String, dynamic>.from(json['arguments'] as Map);

    return PendingToolCall(
      arguments: args,
      originalToolCall: ToolCall(
        id: id,
        callType: 'function',
        function: FunctionCall(
          name: name,
          arguments: jsonEncode(args),
        ),
      ),
    );
  }
}

/// Business model representing the editable pending approval list.
///
/// This type is intentionally unaware of replication metadata. Session id,
/// object key, revision, and actions belong to the outer replication container
/// and envelope. As far as this class is concerned, it is just a plain JSON
/// serializable model used by both client and server.
@JsonSerializable(explicitToJson: true)
class PendingToolCallList implements SessionReplicatedState {
  /// The current collaboratively editable tool calls.
  final List<PendingToolCall> items;

  const PendingToolCallList(this.items);

  factory PendingToolCallList.fromJson(Map<String, dynamic> json) =>
      _$PendingToolCallListFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PendingToolCallListToJson(this);

  /// Creates a shallow copy with optional replacement of the contained items.
  PendingToolCallList copyWith({List<PendingToolCall>? items}) {
    return PendingToolCallList(items ?? this.items);
  }

  /// Returns only the selected tool calls for final approval or execution.
  List<PendingToolCall> get selectedOnly {
    return items.where((item) => item.isSelected).toList();
  }

  /// Returns the number of selected tool calls.
  int get selectedCount => items.where((item) => item.isSelected).length;

  /// Whether all tool calls are currently selected.
  bool get allSelected =>
      items.isNotEmpty && items.every((item) => item.isSelected);
}
