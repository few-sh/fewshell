import 'package:flutter/material.dart';

/// Show SSH interactive prompt dialog
/// Returns the user's response or empty string if cancelled
Future<String> showSshPrompt(
  BuildContext context,
  String prompt,
  bool echo,
) async {
  if (!context.mounted) return '';

  final controller = TextEditingController();
  return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('SSH Authentication Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prompt),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: !echo,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter response',
                  ),
                  onSubmitted: (value) {
                    Navigator.of(context).pop(value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(''),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ) ??
      '';
}
