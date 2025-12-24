import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Reusable dialog for adding or editing secrets
class SecretDialog {
  /// Show dialog to add or edit a secret
  ///
  /// When [existingKey] is null, the dialog is in "add" mode.
  /// When [existingKey] is provided, the dialog is in "edit" mode.
  static Future<void> show(
    BuildContext context, {
    required Function(String key, String value) onSave,
    String? existingKey,
    String? existingValue,
  }) async {
    final isEditMode = existingKey != null;

    await showShadDialog(
      context: context,
      builder: (context) => _SecretDialogForm(
        title: isEditMode ? 'Edit Secret' : 'Add Secret',
        initialKey: existingKey,
        initialValue: existingValue ?? '',
        onSave: onSave,
      ),
    );
  }
}

/// Internal form widget for the secret dialog
class _SecretDialogForm extends StatefulWidget {
  final String title;
  final String? initialKey;
  final String initialValue;
  final Function(String key, String value) onSave;

  const _SecretDialogForm({
    required this.title,
    this.initialKey,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<_SecretDialogForm> createState() => _SecretDialogFormState();
}

class _SecretDialogFormState extends State<_SecretDialogForm> {
  late final TextEditingController _keyController;
  late final TextEditingController _valueController;
  bool _obscureValue = true;

  bool get _isEditMode => widget.initialKey != null;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.initialKey);
    _valueController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadDialog(
      title: Text(widget.title),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ShadButton(onPressed: _save, child: const Text('Save')),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Environment Variable Name', style: theme.textTheme.small),
              const SizedBox(height: 4),
              ShadInput(
                controller: _keyController,
                placeholder: const Text('e.g., API_KEY, DATABASE_URL'),
                enabled: !_isEditMode,
                textCapitalization: TextCapitalization.characters,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Must be uppercase with underscores',
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text('Secret Value', style: theme.textTheme.small),
              const SizedBox(height: 4),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                curve: Curves.easeInOut,
                child: ShadInput(
                  controller: _valueController,
                  placeholder: const Text('Enter the secret value'),
                  obscureText: _obscureValue,
                  minLines: 1,
                  maxLines: _obscureValue ? 1 : null,
                  trailing: ShadButton.ghost(
                    width: 24,
                    height: 24,
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _obscureValue ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 16,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureValue = !_obscureValue;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final key = _keyController.text;
    final value = _valueController.text;

    if (key.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(description: Text('Please enter a variable name')),
      );
      return;
    }

    // Validate environment variable naming: uppercase letters, numbers, underscores
    final envVarPattern = RegExp(r'^[A-Z_][A-Z0-9_]*$');
    if (!envVarPattern.hasMatch(key)) {
      ShadToaster.of(context).show(
        const ShadToast(
          description: Text(
            'Use only uppercase letters, numbers, and underscores',
          ),
        ),
      );
      return;
    }

    if (value.isEmpty) {
      ShadToaster.of(
        context,
      ).show(const ShadToast(description: Text('Please enter a secret value')));
      return;
    }

    widget.onSave(key, value);
    Navigator.of(context).pop();
  }
}
