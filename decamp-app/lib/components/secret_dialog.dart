import 'package:flutter/material.dart';

import '../utils/text_pattern_matcher.dart';

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

    await showDialog(
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
  final _formKey = GlobalKey<FormState>();
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
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'Environment Variable Name',
                  hintText: 'e.g., API_KEY, DATABASE_URL',
                  prefixIcon: Icon(Icons.label),
                  helperText: 'Must be uppercase with underscores',
                ),
                enabled: !_isEditMode,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a variable name';
                  }
                  // Validate environment variable naming: uppercase letters, numbers, underscores
                  final envVarPattern = RegExp(r'^[A-Z_][A-Z0-9_]*$');
                  if (!envVarPattern.hasMatch(value)) {
                    return 'Use only uppercase letters, numbers, and underscores';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: 'Secret Value',
                  hintText: 'Enter the secret value',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureValue
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureValue = !_obscureValue;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                obscureText: _obscureValue,
                maxLines: _obscureValue ? 1 : 5,
                minLines: 1,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a secret value';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(_keyController.text, _valueController.text);
      Navigator.of(context).pop();
    }
  }
}
