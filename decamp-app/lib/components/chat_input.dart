import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              autofocus: false,
              stylusHandwritingEnabled: false,
              maxLines: null, // Allow multiple lines
              textInputAction: TextInputAction.send,
              onSubmitted: widget.enabled ? (_) => _handleSend() : null,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: widget.enabled ? _handleSend : null,
            color: Theme.of(context).colorScheme.primary,
            disabledColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
