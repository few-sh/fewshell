import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../themes/terminal_theme.dart';
import '../utils/ui_utils.dart';
import '../providers/project_provider.dart';
import '../providers/secret_provider.dart';

/// Overlay widget that shows multiple tool action approvals in a scrollable list
/// Returns selected actions when approved, null when cancelled
class MultiCommandApprovalOverlay extends ConsumerStatefulWidget {
  final List<ToolAction> actions;

  const MultiCommandApprovalOverlay({super.key, required this.actions});

  /// Show the overlay and await user selection
  static Future<List<ToolAction>?> show(
    BuildContext context,
    List<ToolAction> actions,
  ) async {
    return await showShadSheet<List<ToolAction>>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (context) => MultiCommandApprovalOverlay(actions: actions),
    );
  }

  /// Test method to show the overlay with placeholder data
  static Future<void> showTest(BuildContext context) async {
    final actions = [
      ToolAction(
        id: '1',
        toolName: 'execute_shell_command',
        params: {
          'command': 'df -h',
          'explanation': 'Check available disk space on the server',
          'sudo_required': false,
        },
        isSelected: true,
      ),
      ToolAction(
        id: '2',
        toolName: 'execute_shell_command',
        params: {
          'command': 'systemctl restart nginx',
          'explanation': 'Restart the Nginx web server to apply changes',
          'sudo_required': true,
          'secrets': ['NGINX_API_KEY', 'SSL_CERT_PASSWORD'],
        },
        isSelected: true,
      ),
      ToolAction(
        id: '3',
        toolName: 'fetch',
        params: {
          'url': 'http://localhost:8080/health',
          'method': 'GET',
          'explanation': 'Check the health status of the local service',
          'secrets': ['HEALTH_CHECK_TOKEN'],
        },
        isSelected: true,
      ),
      ToolAction(
        id: '4',
        toolName: 'execute_shell_command',
        params: {
          'command': 'tail -n 50 /var/log/syslog',
          'explanation': 'Read the last 50 lines of the system log',
          'sudo_required': true,
        },
        isSelected: false,
      ),
    ];

    final result = await show(context, actions);
    if (context.mounted) {
      if (result != null) {
        final encoder = const JsonEncoder.withIndent('  ');
        final resultString = result
            .map((action) {
              return 'Tool: ${action.toolName}\nParams: ${encoder.convert(action.params)}';
            })
            .join('\n\n');

        showShadDialog(
          context: context,
          builder: (context) => ShadDialog(
            title: const Text('Approved Actions'),
            actions: [
              ShadButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            child: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(child: SelectableText(resultString)),
            ),
          ),
        );
      } else {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Cancelled'),
            description: Text('Operation cancelled'),
          ),
        );
      }
    }
  }

  @override
  ConsumerState<MultiCommandApprovalOverlay> createState() =>
      _MultiCommandApprovalOverlayState();
}

class _MultiCommandApprovalOverlayState
    extends ConsumerState<MultiCommandApprovalOverlay> {
  late List<TextEditingController> _controllers;
  final Map<String, Set<String>> _selectedSecrets = {};

  @override
  void initState() {
    super.initState();
    _controllers = widget.actions.map((action) {
      return TextEditingController(text: action.primaryDisplay);
    }).toList();

    // Initialize selected secrets from action params
    for (final action in widget.actions) {
      final secrets = (action.params['secrets'] as List?)?.cast<String>() ?? [];
      _selectedSecrets[action.id] = secrets.toSet();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleApprove() {
    final selectedActions = widget.actions
        .where((action) => action.isSelected)
        .map((action) {
          final selected = _selectedSecrets[action.id] ?? {};

          // Create a deep copy of params to avoid side effects
          final newParams = Map<String, dynamic>.from(action.params);
          newParams['secrets'] = selected.toList();

          return ToolAction(
            id: action.id,
            toolName: action.toolName,
            params: newParams,
            isSelected: action.isSelected,
          );
        })
        .toList();

    if (selectedActions.isEmpty) {
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Error'),
            description: Text('Please select at least one action'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    Navigator.of(context).pop(selectedActions);
  }

  void _handleCancel() {
    Navigator.of(context).pop(null);
  }

  void _toggleSelectAll(bool value) {
    if (!mounted) return;
    setState(() {
      for (final action in widget.actions) {
        action.isSelected = value;
      }
    });
  }

  int get _selectedCount => widget.actions.where((a) => a.isSelected).length;
  int get _privilegedCount =>
      widget.actions.where((a) => a.requiresPrivileges).length;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final terminalTheme = Theme.of(context).extension<TerminalTheme>();
    final allSelected = widget.actions.every((a) => a.isSelected);
    final projectId = ref.watch(currentProjectIdProvider);
    final keychain = ref.watch(keychainServiceProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ShadSheet(
        title: Row(
          children: [
            Icon(
              LucideIcons.wrench,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('Tool Execution Request'),
          ],
        ),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review and approve actions ($_selectedCount of ${widget.actions.length} selected)',
            ),
            if (_privilegedCount > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    LucideIcons.shieldAlert,
                    size: 16,
                    color: theme.colorScheme.destructive,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_privilegedCount ${_privilegedCount == 1 ? 'action requires' : 'actions require'} elevated privileges',
                    style: TextStyle(
                      color: theme.colorScheme.destructive,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Select All checkbox
                Row(
                  children: [
                    ShadCheckbox(
                      value: allSelected,
                      onChanged: _toggleSelectAll,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _toggleSelectAll(!allSelected),
                      child: const Text(
                        'Select All',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // List of commands
                StreamBuilder<List<String>>(
                  stream: keychain.watchVisibleSecretKeys(projectId: projectId),
                  builder: (context, snapshot) {
                    final availableSecrets = snapshot.data ?? [];

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.actions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final action = widget.actions[index];
                        final controller = _controllers[index];

                        // Combine available secrets with any pre-selected ones that might not be in keychain
                        final actionSecrets =
                            (action.params['secrets'] as List?)
                                ?.cast<String>() ??
                            [];
                        final allOptions = {
                          ...availableSecrets,
                          ...actionSecrets,
                        }.toList()..sort();

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              action.isSelected = !action.isSelected;
                              FocusScope.of(context).unfocus();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.border,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: action.requiresPrivileges
                                  ? theme.colorScheme.destructive.withValues(
                                      alpha: 0.05,
                                    )
                                  : theme.colorScheme.secondary.withValues(
                                      alpha: 0.1,
                                    ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShadCheckbox(
                                  value: action.isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      action.isSelected = value;
                                    });
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (action.requiresPrivileges) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              child: Icon(
                                                LucideIcons.shieldAlert,
                                                size: 16,
                                                color: theme
                                                    .colorScheme
                                                    .destructive,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          if (action.params['command'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              child: Text(
                                                action.requiresPrivileges
                                                    ? 'sudo \$ '
                                                    : '\$ ',
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 14,
                                                  color:
                                                      action.requiresPrivileges
                                                      ? theme
                                                            .colorScheme
                                                            .destructive
                                                      : theme
                                                            .colorScheme
                                                            .primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    terminalTheme
                                                        ?.backgroundColor ??
                                                    Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      terminalTheme
                                                          ?.borderColor ??
                                                      Colors.grey,
                                                  width: 1,
                                                ),
                                              ),
                                              child: ShadInput(
                                                readOnly:
                                                    action.toolName == 'fetch',
                                                contextMenuBuilder:
                                                    adaptiveContextMenuBuilder,
                                                controller: controller,
                                                autocorrect: false,
                                                minLines: 1,
                                                maxLines: null,
                                                decoration:
                                                    const ShadDecoration(
                                                      border: ShadBorder.none,
                                                    ),
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 14,
                                                  color:
                                                      terminalTheme
                                                          ?.textColor ??
                                                      Colors
                                                          .greenAccent
                                                          .shade400,
                                                  height: 1.5,
                                                ),
                                                onChanged: (value) {
                                                  if (action.params.containsKey(
                                                    'command',
                                                  )) {
                                                    action.params['command'] =
                                                        value;
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (action.explanation.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          action.explanation,
                                          style: theme.textTheme.muted,
                                        ),
                                      ],
                                      if (action.toolName ==
                                          'execute_shell_command') ...[
                                        const SizedBox(height: 8),
                                        ShadSwitch(
                                          value: action.requiresPrivileges,
                                          onChanged: (value) {
                                            setState(() {
                                              action.params['sudo_required'] =
                                                  value;
                                            });
                                          },
                                          label: const Text('Run as sudo'),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.key, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ShadSelect<String>.multiple(
                                              minWidth: 200,
                                              placeholder: const Text(
                                                'Add Secrets',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              closeOnSelect: false,
                                              initialValues:
                                                  _selectedSecrets[action.id] ??
                                                  {},
                                              onChanged: (selected) {
                                                setState(() {
                                                  _selectedSecrets[action.id] =
                                                      selected.toSet();
                                                });
                                              },
                                              options: allOptions
                                                  .map(
                                                    (secret) => ShadOption(
                                                      value: secret,
                                                      child: Text(
                                                        secret,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              selectedOptionsBuilder:
                                                  (context, values) {
                                                    return Text(
                                                      values.isEmpty
                                                          ? 'No secrets selected'
                                                          : values.join(', '),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShadButton.outline(
                      onPressed: _handleCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ShadButton(
                      onPressed: _handleApprove,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.play, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Run ${_selectedCount > 1 ? '$_selectedCount Actions' : 'Action'}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
