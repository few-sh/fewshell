import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/providers/shell_service_provider.dart';
import 'package:decamp/components/ssh_prompt_dialog.dart';
import 'package:decamp/components/main_drawer.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
// import 'package:decamp/components/execution_progress_overlay.dart';
import 'package:decamp/components/chat_list.dart';
import 'package:decamp/components/chat_input.dart';
import 'package:decamp/components/search_controls.dart';
import 'package:decamp/components/search_match_navigator.dart';
import 'package:decamp/components/project_title_bar.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/providers/message_provider.dart';
import 'package:decamp/providers/chat_controller_provider.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/providers/user_provider.dart';
import 'package:decamp/utils/search_utils.dart';
import 'package:decamp/pages/sessions_history.dart';
import 'package:decamp/components/no_llm_configured_overlay.dart';
import 'package:decamp/services/sync_service.dart';
import 'package:decamp/components/sync_indicator.dart';
import 'package:logging/logging.dart';

class ChatSession extends ConsumerStatefulWidget {
  const ChatSession({super.key});

  @override
  ConsumerState<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends ConsumerState<ChatSession> {
  static final _log = Logger('ChatSession');

  bool _previousKeyboardVisible = false;
  final FocusNode _inputFocusNode = FocusNode();

  // Search state
  bool _isSearchActive = false;
  String _searchQuery = '';
  List<SearchMatch> _searchMatches = [];
  int _currentMatchIndex = 0;
  final GlobalKey _searchNavigatorKey = GlobalKey();
  double _searchNavigatorHeight = 0;

  @override
  void dispose() {
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _activateSearch() {
    setState(() {
      _isSearchActive = true;
    });
  }

  void _deactivateSearch() {
    setState(() {
      _isSearchActive = false;
      _searchQuery = '';
      _searchMatches = [];
      _currentMatchIndex = 0;
    });
  }

  void _updateSearch(String query, List<dynamic> messages) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchMatches = [];
        _currentMatchIndex = 0;
      } else {
        _searchMatches = SearchUtils.findMatches(query, messages.cast());
        _currentMatchIndex = 0;
      }
    });
    _measureSearchNavigator();
  }

  void _measureSearchNavigator() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox =
          _searchNavigatorKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && mounted) {
        final height = renderBox.size.height;
        if (height != _searchNavigatorHeight) {
          setState(() {
            _searchNavigatorHeight = height;
          });
        }
      }
    });
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _searchMatches.length) %
          _searchMatches.length;
    });
  }

  /// Create a new chat session
  Future<void> _createNewSession() async {
    final currentProject = ref.read(currentProjectProvider);
    if (currentProject == null) return;

    // Check if current session has messages
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId != null) {
      final messageDao = ref.read(databaseProvider).messageDao;
      final messages = await messageDao.getMessagesBySession(currentSessionId);

      // If current session is empty, don't create a new one
      if (messages.isEmpty) {
        return;
      }
    }

    // Create new session
    final sessionDao = ref.read(databaseProvider).sessionDao;
    final projectDao = ref.read(databaseProvider).projectDao;

    final newSessionId = await sessionDao.createSessionWithId(
      projectId: currentProject.id,
    );

    // Update project's last session date
    await projectDao.updateLastSessionDate(currentProject.id, DateTime.now());

    // Switch to the new session
    ref.read(currentSessionIdProvider.notifier).select(newSessionId);
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
      _log.warning('No session selected');
      return;
    }

    _log.info('📤 Sending message');

    // Handle /ping command
    final pingRegex = RegExp(r'^/ping(\s+(.*))?$');
    final match = pingRegex.firstMatch(content.trim());
    if (match != null) {
      final message = match.group(2) ?? 'ping';
      ref.read(syncServiceProvider).sendPing(message);

      // Add a system message to chat to indicate ping was sent
      final messageDao = ref.read(databaseProvider).messageDao;
      await messageDao.insertMessageWithId(
        sessionId: currentSessionId,
        userId: 'system',
        userName: 'System',
        content: 'Sent ping: $message',
        isVisibleToLlm: false,
      );
      return;
    }

    // Get the controller
    final controller = ref.read(chatControllerProvider(currentSessionId));

    // Get sync channel
    final syncChannel = ref.read(syncServiceProvider).projectChannel;

    // Get current username
    final userName = ref.read(userProvider);

    // Send to AI (controller will handle saving user message and response)
    await controller.sendMessage(
      content: content,
      userName: userName,
      sessionId: currentSessionId,
      requestApproval: (actions) {
        if (!mounted) return Future.value(null);
        return MultiCommandApprovalOverlay.show(context, actions);
      },
      onNoConfig: () {
        if (mounted) NoLlmConfiguredOverlay.show(context);
      },
      syncChannel: syncChannel,
    );
  }

  /// Handle editing a message
  Future<void> _handleEditMessage(String messageId, String newContent) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) return;

    _log.info('✏️ Editing message: $messageId');

    final controller = ref.read(chatControllerProvider(currentSessionId));

    // Get sync channel
    final syncChannel = ref.read(syncServiceProvider).projectChannel;

    await controller.editMessage(
      messageId: messageId,
      newContent: newContent,
      sessionId: currentSessionId,
      requestApproval: (actions) {
        if (!mounted) return Future.value(null);
        return MultiCommandApprovalOverlay.show(context, actions);
      },
      syncChannel: syncChannel,
    );
  }

  /// Handle resending a message
  Future<void> _handleResendMessage(String messageId) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) return;

    _log.info('🔄 Resending message: $messageId');

    final controller = ref.read(chatControllerProvider(currentSessionId));

    // Get sync channel
    final syncChannel = ref.read(syncServiceProvider).projectChannel;

    await controller.resendMessage(
      messageId: messageId,
      sessionId: currentSessionId,
      requestApproval: (actions) {
        if (!mounted) return Future.value(null);
        return MultiCommandApprovalOverlay.show(context, actions);
      },
      syncChannel: syncChannel,
    );
  }

  /// Handle branching a session at a specific message
  Future<void> _handleBranchSession(String messageId) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) return;

    _log.info('🌿 Branching session at message: $messageId');

    final controller = ref.read(chatControllerProvider(currentSessionId));

    final newSessionId = await controller.branchSession(
      messageId: messageId,
      sessionId: currentSessionId,
    );

    // Switch to the new session
    ref.read(currentSessionIdProvider.notifier).select(newSessionId);

    _log.info('✅ Switched to new session: $newSessionId');
  }

  /// Handle SSH interactive prompts (e.g. 2FA, password)
  Future<String> _handleSshPrompt(String prompt, bool echo) async {
    if (!mounted) {
      throw Exception('Chat session unmounted');
    }
    return showSshPrompt(context, prompt, echo);
  }

  @override
  Widget build(BuildContext context) {
    // Watch current state
    final currentProject = ref.watch(currentProjectProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);

    // Inject SSH prompt callback
    if (currentProject != null) {
      final shellServiceProv = shellServiceProvider(currentProject.id);
      ref.listen(shellServiceProv, (_, shellService) {
        shellService.onUserPrompt = _handleSshPrompt;
      });
      ref.read(shellServiceProv).onUserPrompt = _handleSshPrompt;
    }

    // Unfocus when session or project changes
    ref.listen(currentSessionIdProvider, (previous, next) {
      if (previous != next) _inputFocusNode.unfocus();
    });

    ref.listen(currentProjectProvider, (previous, next) {
      if (previous?.id != next?.id) _inputFocusNode.unfocus();
    });

    // Watch chat state and messages
    // final chatState = ref.watch(chatControllerProvider(currentSessionId));
    final chatController = ref.watch(chatControllerProvider(currentSessionId));
    final messagesAsync = ref.watch(currentSessionMessagesProvider);
    final isLastMessageInProgress =
        ref.watch(isLastMessageInProgressProvider).value ?? false;

    // Refresh search results when messages change
    ref.listen(currentSessionMessagesProvider, (previous, next) {
      if (_isSearchActive && _searchQuery.isNotEmpty) {
        next.whenData((messages) {
          _updateSearch(_searchQuery, messages);
        });
      }
    });

    final currentProjectName = currentProject?.name ?? 'No Project';
    final hasProject = currentProject != null;

    // Detect keyboard visibility
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    // Track keyboard state changes
    if (keyboardVisible != _previousKeyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _previousKeyboardVisible = keyboardVisible;
          });
        }
      });
    }

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        _inputFocusNode.unfocus();
      },
      child: SafeArea(
        top: !keyboardVisible,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(
              keyboardVisible ? 0 : kToolbarHeight,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: keyboardVisible ? 0 : kToolbarHeight,
              child: AppBar(
                title: ProjectTitleBar(
                  title: currentProjectName,
                  leading: (currentProject?.serverUrl != null)
                      ? const SyncIndicator()
                      : null,
                ),
                centerTitle: false,
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search',
                    onPressed: hasProject ? _activateSearch : null,
                  ),
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
            ),
          ),
          drawer: const MainDrawer(),
          body: Stack(
            children: [
              // Main chat UI
              Column(
                children: [
                  // Message list
                  Expanded(
                    child: Stack(
                      children: [
                        messagesAsync.when(
                          data: (messages) => ChatList(
                            messages: messages,
                            isLoading: isLastMessageInProgress,
                            streamingMessageStream:
                                chatController.streamingMessageStream,
                            onEditMessage: _handleEditMessage,
                            onResendMessage: _handleResendMessage,
                            onBranchSession: _handleBranchSession,
                            searchMatches: _searchMatches,
                            currentMatchIndex: _searchMatches.isNotEmpty
                                ? _currentMatchIndex
                                : null,
                            searchNavigatorHeight:
                                _isSearchActive && _searchQuery.isNotEmpty
                                ? _searchNavigatorHeight + 16
                                : 0,
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stack) => Center(
                            // TODO: Log this error to our logging service
                            child: Text('Error loading messages: $error'),
                          ),
                        ),
                        // Search navigator overlay
                        if (_isSearchActive && _searchQuery.isNotEmpty)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: SearchMatchNavigator(
                                key: _searchNavigatorKey,
                                currentMatch: _currentMatchIndex + 1,
                                totalMatches: _searchMatches.length,
                                onPrevious: _previousMatch,
                                onNext: _nextMatch,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Search controls (when active) or Input field
                  if (_isSearchActive)
                    SearchControls(
                      onSearchChanged: (query) {
                        final messages = messagesAsync.valueOrNull ?? [];
                        _updateSearch(query, messages);
                      },
                      onClose: _deactivateSearch,
                      initialQuery: _searchQuery,
                    )
                  else
                    ChatInput(
                      onSend: _handleSendMessage,
                      enabled: !isLastMessageInProgress && hasProject,
                      focusNode: _inputFocusNode,
                    ),
                ],
              ),

              // Execution progress overlay
              // TODO: Re-implement execution progress without ChatState
              // if (chatState.isExecuting)
              //   ExecutionProgressOverlay(
              //     currentCommand: chatState.executionProgress!.currentCommand,
              //     totalCommands: chatState.executionProgress!.totalCommands,
              //     commandName: chatState.executionProgress!.commandName,
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}
