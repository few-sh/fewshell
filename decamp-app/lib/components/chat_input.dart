import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../themes/terminal_theme.dart';
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
  final TextEditingController? controller;
  final bool isTerminalMode;
  final void Function(List<int>)? onTerminalKeys;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onAbort,
    this.isLoading = false,
    this.enabled = true,
    this.hintText = 'Type your message...',
    this.focusNode,
    this.controller,
    this.isTerminalMode = false,
    this.onTerminalKeys,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late final TextEditingController _controller;
  bool _isLocalController = false;
  late final FocusNode _focusNode;
  bool _isLocalFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController();
      _isLocalController = true;
    } else {
      _controller = widget.controller!;
    }
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _isLocalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }
  }

  @override
  void dispose() {
    if (_isLocalController) {
      _controller.dispose();
    }
    if (_isLocalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleSend() {
    if (widget.isTerminalMode) {
      _handleTerminalEnter();
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled || widget.isLoading) return;

    widget.onSend(text);
    _controller.clear();
  }

  void _handleTerminalEnter() {
    final text = _controller.text;
    final bytes = utf8.encode('$text\n');
    widget.onTerminalKeys?.call(bytes);
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
    final terminalTheme = Theme.of(context).extension<TerminalTheme>();
    final isTerminal = widget.isTerminalMode;
    final isInputEnabled = widget.enabled;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isTerminal
            ? terminalTheme?.backgroundColor ?? theme.colorScheme.background
            : theme.colorScheme.background,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isTerminal) ...[
            ShadButton.link(
              width: 40,
              height: 40,
              padding: EdgeInsets.zero,
              onPressed: isInputEnabled ? _showSavedPrompts : null,
              child: const Icon(LucideIcons.messageSquare),
            ),
            const SizedBox(width: 8),
          ],
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
                maxLines: isTerminal ? 1 : 12,
                keyboardType: isTerminal
                    ? TextInputType.text
                    : TextInputType.multiline,
                autofocus: false,
                autocorrect: false,
                enableSuggestions: false,
                placeholder: Text(
                  isTerminal ? r'$' : widget.hintText,
                  style: isTerminal && terminalTheme != null
                      ? TextStyle(color: terminalTheme.hintColor)
                      : null,
                ),
                style: isTerminal && terminalTheme != null
                    ? TextStyle(
                        color: terminalTheme.textColor,
                        fontFamily: 'monospace',
                      )
                    : null,
                decoration: isTerminal && terminalTheme != null
                    ? ShadDecoration(
                        border: ShadBorder.all(
                          color: terminalTheme.borderColor,
                        ),
                      )
                    : null,
                onSubmitted: isInputEnabled ? (_) => _handleSend() : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isTerminal)
            ShadButton(
              width: 40,
              height: 40,
              padding: EdgeInsets.zero,
              onPressed: widget.onAbort,
              backgroundColor: isTerminal
                  ? terminalTheme?.backgroundColor
                  : theme.colorScheme.background,
              child: Icon(
                LucideIcons.square,
                color: theme.colorScheme.destructive,
              ),
            )
          else if (widget.isLoading && widget.onAbort != null)
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
              onPressed: isInputEnabled && !widget.isLoading
                  ? _handleSend
                  : null,
              backgroundColor: theme.colorScheme.background,
              child: const Icon(LucideIcons.send),
            ),
        ],
      ),
    );
  }
}
