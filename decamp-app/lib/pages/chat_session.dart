import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:decamp/components/main_drawer.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/execution_progress_overlay.dart';
import 'package:decamp/components/rich_message_content.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/providers/message_provider.dart';
import 'package:decamp/providers/chat_controller.dart';
import 'package:decamp/pages/projects_page.dart';
import 'package:decamp/pages/sessions_history.dart';
import 'package:decamp/services/ai_actions_config.dart';
import 'dart:developer' as developer;

class ChatSession extends ConsumerStatefulWidget {
  const ChatSession({super.key});

  @override
  ConsumerState<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends ConsumerState<ChatSession> {
  // Controller for managing chat messages
  final _controller = ChatMessagesController();

  // Define users
  // Define users
  final _currentUser = ChatUser(id: 'user', firstName: 'You');
  final _aiUser = ChatUser(id: 'ai', firstName: 'Ops Agent');

  // Context for AiActionProvider (captured from Builder)
  BuildContext? _actionContext;

  // Track synced message IDs to avoid recreating existing messages (UI layer concern)
  final Set<String> _syncedMessageIds = {};

  // Track last synced session to avoid duplicate syncs (UI layer concern)
  String? _lastSyncedSessionId;

  @override
  void initState() {
    super.initState();
    // Controller handles model identifier and state
    // Initial message sync will happen in first build via listeners
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================================
  // NEW: Controller-based message handling (Phase 1 - parallel implementation)
  // ============================================================================

  /// NEW: Handle sending messages using ChatController
  /// This will eventually replace _handleSendMessage
  Future<void> _handleSendMessageWithController(ChatMessage message) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) {
      developer.log('No session selected', name: 'ChatSession.New');
      return;
    }

    developer.log(
      '🎯 NEW: Sending message via controller',
      name: 'ChatSession.New',
    );

    // Get the controller
    final controller = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );

    // Build conversation history from DATABASE, not from UI controller
    // The UI controller might not have the latest messages yet due to async sync
    final messages = await ref.read(currentSessionMessagesProvider.future);

    developer.log(
      '📚 History has ${messages.length} messages (from database)',
      name: 'ChatSession.New',
    );

    final isFirstMessage = messages.isEmpty;

    try {
      // Delegate to controller
      await controller.sendMessage(
        content: message.text,
        sessionId: currentSessionId,
        dbMessages: messages, // Pass database messages directly
        isFirstMessage: isFirstMessage,
        addMessageToUI: (chatMessage) {
          if (mounted) {
            _controller.addMessage(chatMessage);
          }
        },
        startStreaming: (messageId) {
          if (mounted) {
            developer.log(
              '🎬 START STREAMING: $messageId',
              name: 'ChatSession.Streaming',
            );
            // Add an empty message that will be updated with the same ID
            final streamingMessage = ChatMessage(
              text: '',
              user: _aiUser,
              createdAt: DateTime.now(),
              customProperties: {'id': messageId},
              isMarkdown: true,
            );
            _controller.addMessage(streamingMessage);
            _controller.setStreamingMessage(messageId);

            // Mark this ID as synced to prevent database sync from re-adding it
            _syncedMessageIds.add(messageId);
            developer.log(
              '✅ Message added to controller & synced IDs. Current streaming ID: ${_controller.currentlyStreamingMessageId}',
              name: 'ChatSession.Streaming',
            );
          }
        },
        updateStreamingMessage: (messageId, text) {
          if (mounted) {
            // Update the message with new text
            final updatedMessage = ChatMessage(
              text: text,
              user: _aiUser,
              createdAt: DateTime.now(),
              customProperties: {'id': messageId},
              isMarkdown: true,
            );
            _controller.updateMessage(updatedMessage);
          }
        },
        stopStreaming: (messageId) {
          if (mounted) {
            developer.log(
              '🛑 STOP STREAMING: $messageId (current: ${_controller.currentlyStreamingMessageId})',
              name: 'ChatSession.Streaming',
            );
            _controller.stopStreamingMessage(messageId);
            developer.log(
              '✅ After stop - current streaming ID: ${_controller.currentlyStreamingMessageId}',
              name: 'ChatSession.Streaming',
            );
          }
        },
      );
    } catch (e) {
      developer.log(
        '❌ Error in controller sendMessage: $e',
        name: 'ChatSession.New',
      );
    }
  }

  // ============================================================================
  // END NEW CODE
  // ============================================================================

  /// Sync messages from provider to controller
  /// Only called when messages actually change, not on every build
  Future<void> _syncMessagesFromProvider() async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) {
      _controller.clearMessages();
      _syncedMessageIds.clear();
      return;
    }

    try {
      final messages = await ref.read(currentSessionMessagesProvider.future);

      // Check if this is a new session - if so, use setMessages for bulk load
      if (_lastSyncedSessionId != currentSessionId) {
        _lastSyncedSessionId = currentSessionId;

        // Convert all messages to ChatMessage format (exclude 'tool' messages - they're for LLM only)
        final chatMessages = messages.where((msg) => msg.userId != 'tool').map((
          msg,
        ) {
          return ChatMessage(
            text: msg.content,
            user: msg.userId == 'user' ? _currentUser : _aiUser,
            createdAt: msg.createdAt,
            customProperties: {'id': msg.id},
            isMarkdown: true,
          );
        }).toList();

        // Use setMessages for bulk persistence loading (no animation per message)
        _controller.setMessages(chatMessages);

        developer.log(
          '📦 SET MESSAGES (bulk load): ${chatMessages.length} messages. Current streaming ID: ${_controller.currentlyStreamingMessageId}',
          name: 'ChatSession.Sync',
        );

        // Update synced IDs
        _syncedMessageIds.clear();
        _syncedMessageIds.addAll(messages.map((m) => m.id));
      } else {
        // For incremental updates within same session, only add new messages
        final newMessages = <ChatMessage>[];
        for (final msg in messages) {
          if (!_syncedMessageIds.contains(msg.id)) {
            _syncedMessageIds.add(msg.id);
            // Skip tool messages - they're for LLM conversation only, not UI display
            if (msg.userId != 'tool') {
              newMessages.add(
                ChatMessage(
                  text: msg.content,
                  user: msg.userId == 'user' ? _currentUser : _aiUser,
                  createdAt: msg.createdAt,
                  customProperties: {'id': msg.id},
                  isMarkdown: true,
                ),
              );
            }
          }
        }

        // Use addMessage for real-time new messages (with animation)
        for (final message in newMessages) {
          _controller.addMessage(message);
          developer.log(
            '➕ ADD MESSAGE (incremental): ID=${message.customProperties?['id']}. Current streaming ID: ${_controller.currentlyStreamingMessageId}',
            name: 'ChatSession.Sync',
          );
        }
      }
    } catch (e) {
      developer.log('Error syncing messages: $e', name: 'ChatSession');
    }
  }

  Future<void> _createNewSession() async {
    final currentProject = ref.read(currentProjectProvider);
    if (currentProject == null) return;

    final sessionActions = ref.read(sessionActionsProvider);
    await sessionActions.createNewSessionAndSwitch(
      projectId: currentProject.id,
    );
  }

  void _showSessionHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SessionsHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Activate the session manager (handles all business logic)
    ref.watch(sessionManagerProvider);

    // Watch current state
    final currentProject = ref.watch(currentProjectProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);

    // NEW: Watch chat controller for the current session
    // Controller auto-recreates when sessionId changes (family provider)
    final chatState = ref.watch(chatControllerProvider(currentSessionId));
    final chatController = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );

    // NOTE: ref.listen() in build() is the correct Riverpod pattern
    // It's automatically deduplicated and cleaned up by the framework
    // See: https://riverpod.dev/docs/concepts/reading#using-reflisten-to-react-to-a-provider-change

    // Listen to session changes and sync messages ONLY when session changes
    ref.listen(currentSessionIdProvider, (previous, next) {
      if (previous != next) {
        // Sync runs as side effect, not during build
        Future.microtask(() => _syncMessagesFromProvider());
      }
    });

    // Listen to messages changes and sync ONLY when messages actually change
    ref.listen(currentSessionMessagesProvider, (previous, next) {
      // Compare actual message lists to avoid unnecessary syncs
      final prevData = previous?.asData?.value ?? [];
      final nextData = next.asData?.value ?? [];

      // Only sync if message count changed or we have the current session
      if (prevData.length != nextData.length &&
          _lastSyncedSessionId == currentSessionId) {
        // Sync runs as side effect, not during build
        Future.microtask(() => _syncMessagesFromProvider());
      }
    });

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
            // Main chat widget
            AiActionProvider(
              key: ValueKey('actions_${currentProject?.id}'),
              config: ref.watch(aiActionsConfigProvider(currentProject?.id)),
              // Use a Builder to get the correct context inside AiActionProvider
              child: Builder(
                builder: (actionContext) {
                  // Capture the action context for use in callbacks
                  _actionContext = actionContext;

                  return AiChatWidget(
                    // Required parameters
                    currentUser: _currentUser,
                    aiUser: _aiUser,
                    controller: _controller,
                    onSendMessage: _handleSendMessageWithController,

                    // Loading configuration - use chatState
                    loadingConfig: LoadingConfig(
                      isLoading: chatState.isLoading,
                      showCenteredIndicator: true,
                    ),

                    // Input field customization
                    inputOptions: InputOptions(
                      textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                      ),
                      useOuterContainer: false,
                      autofocus: true,
                      sendOnEnter: true,
                      textInputAction: TextInputAction.send,
                      maxLines: 1,
                    ),

                    // Enable animations and streaming
                    enableAnimation:
                        false, // Disabled to prevent re-animation on scroll
                    enableMarkdownStreaming: true,
                    streamingWordByWord: true,
                    streamingDuration: const Duration(milliseconds: 30),

                    // Message options
                    messageOptions: MessageOptions(
                      showTime: true,
                      showUserName: true,
                      containerMargin: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                      bubbleStyle: BubbleStyle(
                        userBubbleColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        aiBubbleColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        userNameColor: Theme.of(context).colorScheme.primary,
                        aiNameColor: Theme.of(context).colorScheme.secondary,
                        bottomLeftRadius: 22,
                        bottomRightRadius: 22,
                        enableShadow: true,
                      ),
                      // Custom bubble builder for rich content
                      customBubbleBuilder: (context, message, isUser) {
                        // Use theme's text colors directly
                        final theme = Theme.of(context);
                        final terminalTheme = theme.extension<TerminalTheme>();
                        // Use bodyLarge color for both user and AI messages
                        final textColor =
                            theme.textTheme.bodyLarge?.color ??
                            theme.textTheme.bodyMedium?.color;

                        final baseTextStyle = TextStyle(color: textColor);

                        return RichMessageContent(
                          message: message,
                          isUser: isUser,
                          styleSheet: MarkdownStyleSheet(
                            // Base text color for all elements
                            p: baseTextStyle.copyWith(fontSize: 14),
                            h1: baseTextStyle.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: baseTextStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: baseTextStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            h4: baseTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            h5: baseTextStyle.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            h6: baseTextStyle.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            strong: baseTextStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            em: baseTextStyle.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                            del: baseTextStyle.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                            blockquote: textColor != null
                                ? baseTextStyle.copyWith(
                                    color: textColor.withValues(alpha: 0.8),
                                  )
                                : baseTextStyle,
                            listBullet: baseTextStyle,
                            tableHead: baseTextStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            tableBody: baseTextStyle,
                            // Links
                            a: TextStyle(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            // Code styling - use terminal theme
                            code: TextStyle(
                              backgroundColor: terminalTheme?.backgroundColor,
                              color: terminalTheme?.textColor,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            codeblockDecoration: terminalTheme != null
                                ? BoxDecoration(
                                    color: terminalTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: terminalTheme.borderColor,
                                      width: 1,
                                    ),
                                  )
                                : null,
                            codeblockPadding: const EdgeInsets.all(12),
                          ),
                        );
                      },
                    ),

                    // Scroll behavior
                    scrollBehaviorConfig: ScrollBehaviorConfig(
                      autoScrollBehavior: AutoScrollBehavior.onUserMessageOnly,
                      scrollToFirstResponseMessage: true,
                    ),

                    // Layout options
                    maxWidth: 800,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  );
                },
              ),
            ),

            // Multi-command approval overlay
            if (chatState.hasPendingActions)
              Builder(
                builder: (context) {
                  final actions = chatState.pendingActions ?? [];

                  developer.log(
                    '🎨 BUILD: Rendering approval overlay with ${actions.length} actions',
                    name: 'ChatSession',
                  );
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MultiCommandApprovalOverlay(
                      actions: actions,
                      onExecute: (selectedActions) async {
                        // Execute via controller
                        final actionHook = AiActionHook.of(_actionContext!);
                        await chatController.executeActions(
                          selectedActions: selectedActions,
                          allActions: actions,
                          sessionId: currentSessionId!,
                          executeAction: (actionName, params) async {
                            final result = await actionHook.executeAction(
                              actionName,
                              params,
                            );
                            return {
                              'success': result.success,
                              'data': result.data,
                              'error': result.error,
                            };
                          },
                          addMessageToUI: (message) {
                            _controller.addMessage(message);
                            // Immediately stop any auto-streaming the library may have started
                            final messageId =
                                message.customProperties?['id'] as String?;
                            if (messageId != null) {
                              _controller.stopStreamingMessage(messageId);
                              developer.log(
                                '🛑 Auto-stopped streaming for: $messageId',
                                name: 'ChatSession.Streaming',
                              );
                            }
                          },
                          markMessageAsSynced: (messageId) {
                            _syncedMessageIds.add(messageId);
                            developer.log(
                              '✓ Marked as synced (follow-up): $messageId',
                              name: 'ChatSession.Sync',
                            );
                          },
                        );
                      },
                      onDismiss: () {
                        developer.log(
                          '🧹 CLEARING pendingActions from onDismiss',
                          name: 'ChatSession',
                          stackTrace: StackTrace.current,
                        );
                        chatController.cancelActions();
                      },
                    ),
                  );
                },
              ),

            // Execution progress overlay
            if (chatState.isExecuting)
              Builder(
                builder: (context) {
                  final progress = chatState.executionProgress!;
                  developer.log(
                    '⏳ BUILD: Rendering progress overlay - ${progress.currentCommand}/${progress.totalCommands}',
                    name: 'ChatSession',
                  );
                  return ExecutionProgressOverlay(
                    currentCommand: progress.currentCommand,
                    totalCommands: progress.totalCommands,
                    commandName: progress.commandName,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Execute multiple actions sequentially with accumulated results
  /// Now follows the official llm_dart pattern for multi-tool execution
  //   }
}
