import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/components/main_drawer.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/execution_progress_overlay.dart';
import 'package:decamp/components/chat_list.dart';
import 'package:decamp/components/chat_input.dart';
import 'package:decamp/components/search_controls.dart';
import 'package:decamp/components/search_match_navigator.dart';
import 'package:decamp/components/project_title_bar.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/providers/session_provider.dart';
import 'package:decamp/providers/message_provider.dart';
import 'package:decamp/providers/chat_controller.dart';
import 'package:decamp/providers/database_provider.dart';
import 'package:decamp/utils/search_utils.dart';
import 'package:decamp/pages/sessions_history.dart';
import 'dart:developer' as developer;

class ChatSession extends ConsumerStatefulWidget {
  const ChatSession({super.key});

  @override
  ConsumerState<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends ConsumerState<ChatSession> {
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
    ref.read(currentSessionIdProvider.notifier).state = newSessionId;
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

    // Send to AI (controller will handle saving user message and response)
    await controller.sendMessage(
      content: content,
      sessionId: currentSessionId,
      requestApproval: (actions) =>
          MultiCommandApprovalOverlay.show(context, actions),
    );
  }

  /// Handle editing a message
  Future<void> _handleEditMessage(String messageId, String newContent) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) return;

    developer.log('✏️ Editing message: $messageId', name: 'ChatSession');

    final controller = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );

    await controller.editMessage(
      messageId: messageId,
      newContent: newContent,
      sessionId: currentSessionId,
      requestApproval: (actions) =>
          MultiCommandApprovalOverlay.show(context, actions),
    );
  }

  /// Handle resending a message
  Future<void> _handleResendMessage(String messageId) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) return;

    developer.log('🔄 Resending message: $messageId', name: 'ChatSession');

    final controller = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );

    await controller.resendMessage(
      messageId: messageId,
      sessionId: currentSessionId,
      requestApproval: (actions) =>
          MultiCommandApprovalOverlay.show(context, actions),
    );
  }

  /// Handle branching a session at a specific message
  Future<void> _handleBranchSession(String messageId) async {
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) return;

    developer.log(
      '🌿 Branching session at message: $messageId',
      name: 'ChatSession',
    );

    final controller = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );

    final newSessionId = await controller.branchSession(
      messageId: messageId,
      sessionId: currentSessionId,
    );

    // Switch to the new session
    ref.read(currentSessionIdProvider.notifier).state = newSessionId;

    developer.log(
      '✅ Switched to new session: $newSessionId',
      name: 'ChatSession',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Activate auto-session selection
    ref.watch(sessionAutoSelectorProvider);

    // Watch current state
    final currentProject = ref.watch(currentProjectProvider);
    final currentSessionId = ref.watch(currentSessionIdProvider);

    // Unfocus when session or project changes
    ref.listen(currentSessionIdProvider, (previous, next) {
      if (previous != next) _inputFocusNode.unfocus();
    });

    ref.listen(currentProjectProvider, (previous, next) {
      if (previous?.id != next?.id) _inputFocusNode.unfocus();
    });

    // Watch chat state and messages
    final chatState = ref.watch(chatControllerProvider(currentSessionId));
    final messagesAsync = ref.watch(currentSessionMessagesProvider);

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
                title: ProjectTitleBar(title: currentProjectName),
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
                            isLoading: chatState.isLoading,
                            streamingMessageId: chatState.streamingMessageId,
                            streamingText: chatState.streamingText,
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
                      enabled: !chatState.isLoading && hasProject,
                      focusNode: _inputFocusNode,
                    ),
                ],
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
      ),
    );
  }
}
