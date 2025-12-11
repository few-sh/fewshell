import 'package:flutter/material.dart';

/// Show SSH interactive prompt dialog
/// Returns the user's response or empty string if cancelled
Future<String> showSshPrompt(
  BuildContext context,
  String prompt,
  bool echo,
) async {
  if (!context.mounted) return '';

  return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _SshPromptDialog(prompt: prompt, echo: echo),
      ) ??
      '';
}

class _SshPromptDialog extends StatefulWidget {
  final String prompt;
  final bool echo;

  const _SshPromptDialog({required this.prompt, required this.echo});

  @override
  State<_SshPromptDialog> createState() => _SshPromptDialogState();
}

class _SshPromptDialogState extends State<_SshPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    Navigator.of(context).pop(value ?? _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('SSH Authentication Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.prompt),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: !widget.echo,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter response',
            ),
            onSubmitted: _submit,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => _submit(''), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
