import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_instruction.freezed.dart';
part 'agent_instruction.g.dart';

/// Represents agent instructions with a default instruction and optional
/// per-model overrides.
@freezed
class AgentInstruction with _$AgentInstruction {
  const factory AgentInstruction({
    /// Default instruction that applies to all models
    @Default('') String defaultInstruction,

    /// Map of model identifier to model-specific instruction overrides
    /// Key is the LLM identifier (e.g., 'gpt-4', 'claude-3')
    /// Value is the instruction text for that specific model
    @Default({}) Map<String, String> modelOverrides,

    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _AgentInstruction;

  factory AgentInstruction.fromJson(Map<String, dynamic> json) =>
      _$AgentInstructionFromJson(json);
}
