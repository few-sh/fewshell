import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/components/main_drawer.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/execution_progress_overlay.dart';
import 'package:decamp/components/chat_list.dart';
import 'package:decamp/components/chat_input.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/providers/message_provider.dart';
import 'package:decamp/providers/chat_controller.dart';
import 'package:decamp/pages/projects_page.dart';
import 'package:decamp/pages/sessions_history.dart';
import 'package:decamp/services/shell_service.dart';
import 'package:decamp/repositories/chat_repository.dart';
import 'dart:developer' as developer;

class ChatSession extends ConsumerStatefulWidget {
  const ChatSession({super.key});

  @override
  ConsumerState<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends ConsumerState<ChatSession> {
  /// Create a new chat session
  Future<void> _createNewSession() async {
    final currentProject = ref.read(currentProjectProvider);
    if (currentProject == null) return;

    await ref
        .read(sessionActionsProvider)
        .createNewSessionAndSwitch(projectId: currentProject.id);
  }

  /// Show session history page
  void _showSessionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SessionsHistoryPage()),
    );
  }

  /// Handle sending a message
  Future<void> _handleSendMessage(String content) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) {
      developer.log('No session selected', name: 'ChatSession');
      return;
    }

    developer.log('📤 Sending message', name: 'ChatSession');

    // Get the controller
    final controller = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );

    // Get message history from database
    final messagesAsync = ref.read(currentSessionMessagesProvider);
    final messages = messagesAsync.when(
      data: (msgs) => msgs,
      loading: () => [],
      error: (_, __) => [],
    );

    final isFirstMessage = messages.isEmpty;

    // First save the user's message to database
    final repository = ref.read(chatRepositoryProvider);
    await repository.saveUserMessage(
      sessionId: currentSessionId,
      content: content,
    );

    // Then send to AI (controller will handle streaming and saving response)
    await controller.sendMessage(
      content: content,
      sessionId: currentSessionId,
      dbMessages: messages,
      isFirstMessage: isFirstMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Activate the session manager
    ref.watch(sessionManagerProvider);

    // Watch current state
    final currentProject = ref.watch(currentProjectProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);

    // Watch chat state and messages
    final chatState = ref.watch(chatControllerProvider(currentSessionId));
    final chatController = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );
    final messagesAsync = ref.watch(currentSessionMessagesProvider);

    final currentProjectName = currentProject?.name ?? 'No Project';
    final hasProject = currentProject != null;

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: hasProject
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProjectsPage(),
                      ),
                    );
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentProjectName),
                if (!hasProject) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ],
            ),
          ),
          centerTitle: false,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Session',
              onPressed: hasProject ? _createNewSession : null,
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Session History',
              onPressed: _showSessionHistory,
            ),
          ],
        ),
        drawer: const MainDrawer(),
        body: Stack(
          children: [
            // Main chat UI
            Column(
              children: [
                // Message list
                Expanded(
                  child: messagesAsync.when(
                    data: (messages) => ChatList(
                      messages: messages,
                      isLoading: chatState.isLoading,
                      streamingMessageId: chatState.streamingMessageId,
                      streamingText: chatState.streamingText,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('Error loading messages: $error')),
                  ),
                ),
                // Input field
                ChatInput(
                  onSend: _handleSendMessage,
                  enabled: !chatState.isLoading && hasProject,
                ),
              ],
            ),

            // Multi-command approval overlay
            if (chatState.hasPendingActions)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MultiCommandApprovalOverlay(
                  actions: chatState.pendingActions!,
                  onExecute: (selectedActions) async {
                    // Execute via controller with shell service
                    final shellService = ref.read(
                      shellServiceProvider(currentProject?.id),
                    );
                    await chatController.executeActions(
                      selectedActions: selectedActions,
                      allActions: chatState.pendingActions!,
                      sessionId: currentSessionId!,
                      executeAction: (actionName, params) async {
                        // Execute shell command directly
                        if (actionName == 'execute_shell_command') {
                          final command = params['command'] as String;
                          final result = await shellService.executeCommand(
                            command,
                          );

                          return {
                            'success': (result['exitCode'] as int? ?? -1) == 0,
                            'data': result['stdout'] as String? ?? '',
                            'error': result['stderr'] as String?,
                          };
                        }

                        throw Exception('Unknown action: $actionName');
                      },
                    );
                  },
                  onDismiss: () {
                    developer.log(
                      '🧹 Dismissing approval overlay',
                      name: 'ChatSession',
                    );
                    chatController.cancelActions();
                  },
                ),
              ),

            // Execution progress overlay
            if (chatState.isExecuting)
              ExecutionProgressOverlay(
                currentCommand: chatState.executionProgress!.currentCommand,
                totalCommands: chatState.executionProgress!.totalCommands,
                commandName: chatState.executionProgress!.commandName,
              ),
          ],
        ),
      ),
    );
  }
}
