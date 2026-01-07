import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../utils/ui_utils.dart';
import 'saved_prompts_bottom_sheet.dart';

/// Simple chat input field widget
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback? onAbort;
  final bool isLoading;
  final bool enabled;
  final String hintText;
  final FocusNode? focusNode;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onAbort,
    this.isLoading = false,
    this.enabled = true,
    this.hintText = 'Type your message...',
    this.focusNode,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _isLocalFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _isLocalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_isLocalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled || widget.isLoading) return;

    widget.onSend(text);
    _controller.clear();
  }

  void _insertNewline() {
    if (!widget.enabled || widget.isLoading) return;

    final text = _controller.text;
    final selection = _controller.selection;
    final int start = selection.start;
    final int end = selection.end;

    if (start < 0) {
      final newText = '$text\n';
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } else {
      final newText = text.replaceRange(start, end, '\n');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 1),
      );
    }
  }

  void _showSavedPrompts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SavedPromptsBottomSheet(
        onSend: (content) {
          widget.onSend(content);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isInputEnabled = widget.enabled && !widget.isLoading;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        // border: Border(top: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ShadButton.link(
            width: 40,
            height: 40,
            padding: EdgeInsets.zero,
            onPressed: isInputEnabled ? _showSavedPrompts : null,
            child: const Icon(LucideIcons.messageSquare),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                    _insertNewline,
                const SingleActivator(LogicalKeyboardKey.enter): _handleSend,
              },
              child: ShadInput(
                contextMenuBuilder: adaptiveContextMenuBuilder,
                controller: _controller,
                focusNode: _focusNode,
                enabled: isInputEnabled,
                minLines: 1,
                maxLines: 12,
                keyboardType: TextInputType.multiline,
                autofocus: false,
                autocorrect: false,
                enableSuggestions: false,
                placeholder: Text(widget.hintText),
                onSubmitted: isInputEnabled ? (_) => _handleSend() : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.isLoading && widget.onAbort != null)
            ShadButton(
              width: 40,
              height: 40,
              padding: EdgeInsets.zero,
              onPressed: widget.onAbort,
              backgroundColor: theme.colorScheme.background,
              child: Icon(
                LucideIcons.square,
                color: theme.colorScheme.destructive,
              ),
            )
          else
            ShadButton(
              width: 40,
              height: 40,
              padding: EdgeInsets.zero,
              onPressed: isInputEnabled ? _handleSend : null,
              backgroundColor: theme.colorScheme.background,
              child: const Icon(LucideIcons.send),
            ),
        ],
      ),
    );
  }
}
