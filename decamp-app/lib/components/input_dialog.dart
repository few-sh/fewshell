import 'package:flutter/material.dart';

Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  required String label,
  String? initialValue,
  String? confirmLabel,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) {
          Navigator.pop(context, value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, controller.text.trim());
          },
          child: Text(confirmLabel ?? 'Confirm'),
        ),
      ],
    ),
  );
}
