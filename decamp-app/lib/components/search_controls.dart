import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      color: colorScheme.surface,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: 'Search messages (supports regex)...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Close search',
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}
