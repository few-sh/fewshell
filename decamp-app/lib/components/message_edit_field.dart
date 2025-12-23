import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Inline edit field for message editing
/// Shows a text field with Save and Cancel buttons
class MessageEditField extends StatefulWidget {
  final String initialContent;
  final Function(String) onSave;
  final VoidCallback onCancel;

  const MessageEditField({
    super.key,
    required this.initialContent,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<MessageEditField> createState() => _MessageEditFieldState();
}

class _MessageEditFieldState extends State<MessageEditField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _focusNode = FocusNode();

    // Auto-focus when edit mode starts
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        _focusNode.requestFocus();
        // Move cursor to end
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSave() {
    final newContent = _controller.text.trim();
    if (newContent.isNotEmpty && newContent != widget.initialContent) {
      widget.onSave(newContent);
    } else {
      // If no changes or empty, just cancel
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadInput(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            autocorrect: false,
            enableSuggestions: false,
            placeholder: const Text('Edit your message...'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShadButton.outline(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ShadButton(
                onPressed: _handleSave,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.check, size: 18),
                    SizedBox(width: 8),
                    Text('Save'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
