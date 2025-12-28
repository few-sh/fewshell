import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'saved_prompts_bottom_sheet.dart';

/// Simple chat input field widget
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final bool enabled;
  final String hintText;
  final FocusNode? focusNode;

  const ChatInput({
    super.key,
    required this.onSend,
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
    if (text.isEmpty || !widget.enabled) return;

    widget.onSend(text);
    _controller.clear();
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
            onPressed: widget.enabled ? _showSavedPrompts : null,
            child: const Icon(LucideIcons.messageSquare),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShadInput(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              minLines: 1,
              //              maxLines: 5,
              autofocus: false,
              autocorrect: false,
              enableSuggestions: false,
              placeholder: Text(widget.hintText),
              onSubmitted: widget.enabled ? (_) => _handleSend() : null,
            ),
          ),
          const SizedBox(width: 8),
          ShadButton(
            width: 40,
            height: 40,
            padding: EdgeInsets.zero,
            onPressed: widget.enabled ? _handleSend : null,
            backgroundColor: theme.colorScheme.background,
            child: const Icon(LucideIcons.send),
          ),
        ],
      ),
    );
  }
}
