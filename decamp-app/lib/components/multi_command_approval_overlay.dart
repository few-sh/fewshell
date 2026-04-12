import 'dart:convert';

import 'package:decamp/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/pending_tool_call_approval_provider.dart';
import '../themes/terminal_theme.dart';
import '../utils/ui_utils.dart';

/// Overlay widget that shows multiple tool action approvals in a scrollable list
/// Returns selected actions when approved, empty list when cancelled, null for other dismissals
class MultiCommandApprovalOverlay extends ConsumerStatefulWidget {
  const MultiCommandApprovalOverlay({
    super.key,
    required this.sessionId,
    required this.pendingCalls,
    this.channel,
  });

  final String sessionId;
  final PendingToolCallList pendingCalls;
  final MultiplexedWebSocketChannel? channel;

  /// Show the overlay and await user selection
  static Future<PendingToolCallList?> show(
    BuildContext context,
    PendingToolCallList pendingCalls, {
    required String sessionId,
    MultiplexedWebSocketChannel? channel,
  }) async {
    final result = await showShadSheet<PendingToolCallList>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (context) => MultiCommandApprovalOverlay(
        sessionId: sessionId,
        pendingCalls: pendingCalls,
        channel: channel,
      ),
    );
    // Treat null (X button / swipe dismiss) the same as Cancel
    return result ?? const PendingToolCallList([]);
  }

  /// Test method to show the overlay with placeholder data
  static Future<void> showTest(BuildContext context) async {
    final pendingCalls = PendingToolCallList([
      PendingToolCall.fromApprovalRequestJson({
        'id': '1',
        'name': 'execute_shell_command',
        'arguments': {
          'command': 'df -h',
          'explanation': 'Check available disk space on the server',
          'sudo_required': false,
        },
      }),
      PendingToolCall.fromApprovalRequestJson({
        'id': '2',
        'name': 'execute_shell_command',
        'arguments': {
          'command': 'systemctl restart nginx',
          'explanation': 'Restart the Nginx web server to apply changes',
          'sudo_required': true,
          'secrets': ['NGINX_API_KEY', 'SSL_CERT_PASSWORD'],
        },
      }),
      PendingToolCall.fromApprovalRequestJson({
        'id': '3',
        'name': 'fetch',
        'arguments': {
          'url': 'http://localhost:8080/health',
          'method': 'GET',
          'explanation': 'Check the health status of the local service',
          'secrets': ['HEALTH_CHECK_TOKEN'],
        },
      }),
      PendingToolCall.fromApprovalRequestJson({
        'id': '4',
        'name': 'execute_shell_command',
        'arguments': {
          'command': 'tail -n 50 /var/log/syslog',
          'explanation': 'Read the last 50 lines of the system log',
          'sudo_required': true,
        },
      }).copyWith(isSelected: false),
    ]);

    final result = await show(context, pendingCalls, sessionId: 'test-session');
    if (context.mounted) {
      if (result != null) {
        final encoder = const JsonEncoder.withIndent('  ');
        final resultString = result.items
            .map((call) {
              return 'Tool: ${call.name}\nParams: ${encoder.convert(call.arguments)}';
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
  PendingToolCallApprovalArgs get _args =>
      (sessionId: widget.sessionId, channel: widget.channel);
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(PendingToolCall call) {
    final display = _primaryDisplay(call);
    final controller = _controllers.putIfAbsent(
      call.id,
      () => TextEditingController(text: display),
    );
    _syncControllerText(call.id, fallbackCall: call);
    return controller;
  }

  FocusNode _focusNodeFor(String callId) {
    return _focusNodes.putIfAbsent(callId, () {
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (!focusNode.hasFocus) {
          _syncControllerText(callId);
        }
      });
      return focusNode;
    });
  }

  void _syncControllerText(String callId, {PendingToolCall? fallbackCall}) {
    final controller = _controllers[callId];
    if (controller == null) {
      return;
    }

    final focusNode = _focusNodeFor(callId);
    if (focusNode.hasFocus) {
      return;
    }

    final currentCall = ref
        .read(pendingToolCallApprovalProvider(_args))
        .items
        .where((item) => item.id == callId)
        .cast<PendingToolCall?>()
        .firstWhere((item) => item != null, orElse: () => fallbackCall);
    if (currentCall == null) {
      return;
    }

    final display = _primaryDisplay(currentCall);
    if (controller.text == display) {
      return;
    }

    controller.value = controller.value.copyWith(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
      composing: TextRange.empty,
    );
  }

  String _primaryDisplay(PendingToolCall call) {
    if (call.arguments['command'] != null) {
      return call.arguments['command'].toString();
    }
    if (call.arguments['url'] != null) {
      final method =
          call.arguments['method']?.toString().toUpperCase() ?? 'GET';
      return '$method ${call.arguments['url']}';
    }
    return call.name;
  }

  bool _requiresPrivileges(PendingToolCall call) {
    return call.arguments['sudo_required'] as bool? ?? false;
  }

  String _explanation(PendingToolCall call) {
    return call.arguments['explanation']?.toString() ?? '';
  }

  void _handleApprove() {
    final pending = ref.read(pendingToolCallApprovalProvider(_args));
    final approvedCalls = pending.copyWith(items: pending.selectedOnly);

    if (approvedCalls.items.isEmpty) {
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

    Navigator.of(context).pop(approvedCalls);
  }

  void _handleCancel() {
    // Return empty list to signal user cancellation (not session mismatch)
    Navigator.of(context).pop(const PendingToolCallList([]));
  }

  void _toggleSelectAll(bool value) {
    ref
        .read(pendingToolCallApprovalProvider(_args).notifier)
        .toggleSelectAll(value);
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingToolCallApprovalProvider(_args));
    final notifier = ref.read(pendingToolCallApprovalProvider(_args).notifier);
    // Use replicated state; fall back to request payload if replication hasn't arrived yet
    final items = pending.items.isNotEmpty
        ? pending.items
        : widget.pendingCalls.items;
    final theme = ShadTheme.of(context);
    final terminalTheme = Theme.of(context).extension<TerminalTheme>();
    final allSelected = pending.allSelected;
    final projectId = ref.watch(currentProjectIdProvider);
    final keychain = ref.watch(keychainServiceProvider);
    final selectedCount = pending.selectedCount;
    final privilegedCount = items
        .where((call) => _requiresPrivileges(call))
        .length;

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
              'Review and approve actions ($selectedCount of ${items.length} selected)',
            ),
            if (privilegedCount > 0) ...[
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
                    '$privilegedCount ${privilegedCount == 1 ? 'action requires' : 'actions require'} elevated privileges',
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
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final call = items[index];
                        final controller = _controllerFor(call);
                        final focusNode = _focusNodeFor(call.id);

                        // Combine available secrets with any pre-selected ones that might not be in keychain
                        final actionSecrets =
                            (call.arguments['secrets'] as List?)
                                ?.cast<String>() ??
                            [];
                        final allOptions = {
                          ...availableSecrets,
                          ...actionSecrets,
                        }.toList()..sort();

                        return GestureDetector(
                          onTap: () {
                            notifier.setSelected(call.id, !call.isSelected);
                            FocusScope.of(context).unfocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.border,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _requiresPrivileges(call)
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
                                  value: call.isSelected,
                                  onChanged: (value) {
                                    notifier.setSelected(call.id, value);
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
                                          if (_requiresPrivileges(call)) ...[
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
                                          if (call.arguments['command'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              child: Text(
                                                _requiresPrivileges(call)
                                                    ? 'sudo \$ '
                                                    : '\$ ',
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 14,
                                                  color:
                                                      _requiresPrivileges(call)
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
                                                readOnly: call.name == 'fetch',
                                                contextMenuBuilder:
                                                    adaptiveContextMenuBuilder,
                                                controller: controller,
                                                focusNode: focusNode,
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
                                                  if (call.arguments
                                                      .containsKey('command')) {
                                                    notifier.setCommand(
                                                      call.id,
                                                      value,
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_explanation(call).isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _explanation(call),
                                          style: theme.textTheme.muted,
                                        ),
                                      ],
                                      if (call.name ==
                                          'execute_shell_command') ...[
                                        const SizedBox(height: 8),
                                        ShadSwitch(
                                          value: _requiresPrivileges(call),
                                          onChanged: (value) {
                                            notifier.setSudoRequired(
                                              call.id,
                                              value,
                                            );
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
                                              initialValues: actionSecrets
                                                  .toSet(),
                                              onChanged: (selected) {
                                                notifier.setSecrets(
                                                  call.id,
                                                  selected.toSet(),
                                                );
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
                            'Run ${selectedCount > 1 ? '$selectedCount Actions' : 'Action'}',
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
