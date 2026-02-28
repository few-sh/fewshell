import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Shows a dialog prompting the user to enter a name for a new project.
///
/// Returns the entered name, or `null` if the user cancels.
Future<String?> showCreateProjectDialog(
  BuildContext context, {
  required String serverNodeId,
}) {
  return showShadDialog<String>(
    context: context,
    builder: (context) =>
        _CreateProjectDialogContent(serverNodeId: serverNodeId),
  );
}

class _CreateProjectDialogContent extends StatefulWidget {
  final String serverNodeId;

  const _CreateProjectDialogContent({required this.serverNodeId});

  @override
  State<_CreateProjectDialogContent> createState() =>
      _CreateProjectDialogContentState();
}

class _CreateProjectDialogContentState
    extends State<_CreateProjectDialogContent> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Project name cannot be empty');
      return;
    }
    // Guard against navigator being locked by a concurrent navigation
    // (e.g. project auto-selected while the dialog is open).
    try {
      Navigator.pop(context, name);
    } catch (_) {
      // Navigator locked — dialog will be dismissed by the framework.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('Create Project'),
      description: const Text(
        'No projects exist for this server yet. '
        'Enter a name to create one.',
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ShadButton(onPressed: _submit, child: const Text('Create')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ShadInput(
            controller: _controller,
            placeholder: const Text('Project name'),
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
