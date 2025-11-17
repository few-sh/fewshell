import 'package:llm_dart/llm_dart.dart';

/// Events emitted by the LLM service during streaming
sealed class LlmEvent {}

/// A chunk of text from the LLM response
class TextChunk extends LlmEvent {
  final String text;
  TextChunk(this.text);
}

/// A tool call request from the LLM
class ToolCallEvent extends LlmEvent {
  final ToolCall toolCall;
  ToolCallEvent(this.toolCall);
}

/// Stream completion event
class CompletionEvent extends LlmEvent {
  CompletionEvent();
}

/// Error during streaming
class ErrorEvent extends LlmEvent {
  final String error;
  ErrorEvent(this.error);
}

/// Thinking event (for models that support it)
class ThinkingEvent extends LlmEvent {
  ThinkingEvent();
}
