import 'package:llm_dart/llm_dart.dart';

/// Defines how the Agent interacts with the LLM and formats its intent.
/// This acts as a translation layer between the specific prompting strategy (Bash, Native, XML)
/// and the core agent loop.
abstract class AgentAdapter {
  String get id;
  String get name;
  String get description;

  /// The system instructions to prepend to the conversation
  String get systemInstruction;

  /// The native tool definitions (if this protocol uses native calling)
  List<Tool> get tools;

  /// Validates and parses the final result of a turn into standardized actions.
  ///
  /// [text] is the raw text response from the LLM.
  /// [nativeToolCalls] are any structured tool calls returned by the LLM provider.
  AdapterResult validate(String text, List<ToolCall> nativeToolCalls);
}

/// The result of an adapter validation step
sealed class AdapterResult {}

/// Validation successful: Tool calls extracted (either from text or native)
class AdapterSuccess implements AdapterResult {
  final List<ToolCall> toolCalls;
  AdapterSuccess(this.toolCalls);
}

/// Validation successful: Turn is complete (no tools, just text/answer)
class AdapterTurnComplete implements AdapterResult {
  final String content; // The final answer text
  AdapterTurnComplete(this.content);
}

/// Validation failed: The agent violated the protocol (e.g. stalled)
/// This triggers a self-correction loop by sending [userErrorMessage] back to the agent.
class AdapterFailure implements AdapterResult {
  final String userErrorMessage;
  AdapterFailure(this.userErrorMessage);
}
