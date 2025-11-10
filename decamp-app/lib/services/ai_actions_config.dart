import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import 'shell_service.dart';
import '../models/ssh_settings.dart';
import '../providers/ssh_settings_provider.dart';

/// Provider for AI action configuration
/// Now requires a project ID to access SSH settings and shell service
final aiActionsConfigProvider = Provider.family<AiActionConfig, String?>((
  ref,
  projectId,
) {
  developer.log(
    'aiActionsConfigProvider called with projectId: $projectId',
    name: 'AiActionsConfig',
  );

  final shellService = ref.watch(shellServiceProvider(projectId));
  final sshSettings = projectId != null
      ? ref.watch(projectSshSettingsProvider(projectId))
      : null;

  developer.log(
    'SSH settings loaded: ${sshSettings != null ? "exists (enabled=${sshSettings.enabled})" : "null"}',
    name: 'AiActionsConfig',
  );

  return createAiActionsConfig(shellService, sshSettings, ref, projectId);
});

/// Create the AI actions configuration
AiActionConfig createAiActionsConfig(
  ShellService shellService,
  SshSettings? sshSettings,
  ProviderRef ref,
  String? projectId,
) {
  return AiActionConfig(
    actions: [
      // Shell command execution action
      AiAction(
        name: 'execute_shell_command',
        description:
            'Execute a shell command on the server or infrastructure. '
            'Use this to run commands like checking logs, restarting services, '
            'checking disk space, process status, etc.',
        parameters: [
          ActionParameter.string(
            name: 'command',
            description:
                'The shell command to execute (e.g., "ps aux | grep nginx")',
            required: true,
            validator: (value) {
              if (value == null || value.toString().isEmpty) {
                return 'Command cannot be empty';
              }
              // Validate the command
              return shellService.validateCommand(value.toString());
            },
          ),
          ActionParameter.string(
            name: 'explanation',
            description:
                'Brief explanation of what this command does and why it\'s needed',
            required: true,
          ),
        ],
        // No confirmation dialog - we handle approval with custom overlay
        confirmationConfig: null,
        // Custom rendering for action status
        render: (context, status, params, {result, error}) {
          final command = params['command'] as String?;
          final explanation = params['explanation'] as String?;

          switch (status) {
            case ActionStatus.waitingForConfirmation:
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.terminal,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Shell Command Request',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (explanation != null) ...[
                        Text(
                          explanation,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          command ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Waiting for confirmation...',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );

            case ActionStatus.executing:
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Executing Command...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          command ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

            case ActionStatus.completed:
              final stdout = result?.data['stdout'] as String? ?? '';
              final stderr = result?.data['stderr'] as String? ?? '';
              final exitCode = result?.data['exitCode'] as int? ?? 0;
              final isStub = result?.data['executed'] == false;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: exitCode == 0
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            exitCode == 0 ? Icons.check_circle : Icons.error,
                            color: exitCode == 0
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            exitCode == 0
                                ? 'Command Completed'
                                : 'Command Failed',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          command ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isStub) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'STUB MODE: Command not actually executed',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Output:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stdout.isEmpty && stderr.isEmpty
                              ? '(no output)'
                              : stdout,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                      if (stderr.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Errors:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            stderr,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Exit code: $exitCode',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );

            case ActionStatus.failed:
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Command Failed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          command ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Error: ${error ?? "Unknown error"}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              );

            case ActionStatus.cancelled:
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cancel,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Command Cancelled',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          command ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'User cancelled the command execution.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );

            default:
              return const SizedBox.shrink();
          }
        },
        // Handler for executing the shell command
        handler: (params) async {
          final command = params['command'] as String;

          try {
            developer.log(
              'Executing shell command: $command',
              name: 'AiActionsConfig',
            );

            // Read fresh SSH settings from provider to avoid stale data
            final currentSshSettings = projectId != null
                ? ref.read(projectSshSettingsProvider(projectId))
                : null;

            developer.log(
              'SSH Settings: enabled=${currentSshSettings?.enabled}, host=${currentSshSettings?.host}',
              name: 'AiActionsConfig',
            );
            developer.log(
              'Shell service connected: ${shellService.isConnected}',
              name: 'AiActionsConfig',
            );

            // Ensure SSH connection is established
            if (!shellService.isConnected) {
              if (projectId == null) {
                developer.log(
                  'No project selected - cannot execute commands',
                  name: 'AiActionsConfig',
                );
                return ActionResult.createFailure(
                  'No project selected. Please create or select a project first.',
                );
              }

              if (currentSshSettings == null || !currentSshSettings.enabled) {
                developer.log(
                  'No SSH connection: sshSettings=${currentSshSettings != null}, enabled=${currentSshSettings?.enabled}',
                  name: 'AiActionsConfig',
                );
                return ActionResult.createFailure(
                  'No SSH connection configured. Please configure SSH settings in project settings.',
                );
              }

              // Attempt to connect
              developer.log(
                'Attempting to connect to SSH...',
                name: 'AiActionsConfig',
              );
              final connected = await shellService.connect(currentSshSettings);
              if (!connected) {
                developer.log('SSH connection failed', name: 'AiActionsConfig');
                return ActionResult.createFailure(
                  'Failed to connect to SSH server. Please check your SSH settings.',
                );
              }
              developer.log(
                'SSH connection successful',
                name: 'AiActionsConfig',
              );
            }

            // Execute the command
            final result = await shellService.executeCommand(command);

            if (result['executed'] == true) {
              return ActionResult.createSuccess(result);
            } else {
              return ActionResult.createFailure(
                result['stderr'] ?? 'Command execution failed',
              );
            }
          } catch (e) {
            return ActionResult.createFailure('Failed to execute command: $e');
          }
        },
      ),
    ],
  );
}
