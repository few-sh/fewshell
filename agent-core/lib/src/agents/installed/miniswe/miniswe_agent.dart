import 'package:llm_dart/llm_dart.dart';
import '../../agent.dart';
import 'bash_block_parser.dart';

class MiniSweAgent implements Agent {
  @override
  String get id => 'miniswe_mode';

  @override
  String get name => 'Mini-SWE Mode';

  @override
  String get description =>
      'Code blocks are parsed as commands. Optimized for coding/scripting.';

  @override
  // No native tools needed, we parse markdown!
  List<Tool> get tools => [];

  @override
  String get systemInstruction => '''
You are a DevOps Assistant.
To execute commands, output a Markdown code block using ```bash or ```sh.
Provide ONE block per turn.
When finished, type COMPLETED_TASK.
If you need to ask the user a question, type ASK_USER.
''';

  @override
  AgentResult validate(String text, List<ToolCall> nativeToolCalls) {
    try {
      // 1. Try to parse bash blocks
      final bashCalls = BashBlockParser.parse(text);

      if (bashCalls.isNotEmpty) {
        return AgentSuccess(bashCalls);
      }

      // 2. Check for completion signals
      if (text.contains('COMPLETED_TASK') || text.contains('ASK_USER')) {
        return AgentTurnComplete(text);
      }

      // 3. Violation (Stalling)
      return AgentFailure(
        'Error: You responded with text but NO command. '
        'You must provide a bash block, COMPLETED_TASK, or ASK_USER. '
        'Do not explain your plan, just execute it.',
      );
    } on BashBlockFormatException catch (e) {
      return AgentFailure(e.message);
    }
  }
}
