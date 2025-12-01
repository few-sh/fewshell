import 'package:llm_dart/llm_dart.dart';
import '../agent.dart';
import '../tools/system_tools.dart';

class NativeAgent implements Agent {
  @override
  String get id => 'native_mode';

  @override
  String get name => 'Native Tool Mode';

  @override
  String get description =>
      'Standard LLM tool calling. Uses the model\'s native capability to invoke tools.';

  @override
  List<Tool> get tools => shellTools;

  @override
  String get systemInstruction =>
      'You are a DevOps Assistant. Use the provided tools to execute commands.';

  @override
  AgentResult validate(String text, List<ToolCall> nativeToolCalls) {
    // 1. If the LLM used the native API, we are good.
    if (nativeToolCalls.isNotEmpty) {
      return AgentSuccess(nativeToolCalls);
    }

    // 2. Native models usually handle their own stopping,
    // but we can check for text content as a completion.
    // If there are no tool calls, it's a text response.
    return AgentTurnComplete(text);
  }
}
