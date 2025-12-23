import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = true,
}) {
  return showShadDialog<bool>(
    context: context,
    builder: (context) => ShadDialog.alert(
      title: Text(title),
      description: Text(content),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        if (isDestructive)
          ShadButton.destructive(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          )
        else
          ShadButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
      ],
    ),
  );
}
