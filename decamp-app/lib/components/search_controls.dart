import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Floating search controls widget
/// Provides auto-focused text field with clear and close buttons
class SearchControls extends StatefulWidget {
  final Function(String) onSearchChanged;
  final VoidCallback onClose;
  final bool autofocus;
  final String initialQuery;

  const SearchControls({
    super.key,
    required this.onSearchChanged,
    required this.onClose,
    this.autofocus = true,
    this.initialQuery = '',
  });

  @override
  State<SearchControls> createState() => _SearchControlsState();
}

class _SearchControlsState extends State<SearchControls> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onSearchChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: 16,
            color: theme.colorScheme.foreground.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              autocorrect: false,
              enableSuggestions: false,
              style: theme.textTheme.small,
              decoration: InputDecoration(
                hintText: 'Search messages (supports regex)...',
                hintStyle: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.foreground.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          ShadButton.ghost(
            width: 24,
            height: 24,
            padding: EdgeInsets.zero,
            onPressed: widget.onClose,
            child: const Icon(LucideIcons.x, size: 16),
          ),
        ],
      ),
    );
  }
}
