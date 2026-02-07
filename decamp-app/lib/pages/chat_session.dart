import 'package:decamp/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/ssh_prompt_dialog.dart';
import 'package:decamp/components/main_drawer.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/execution_progress_overlay.dart';
import 'package:decamp/components/chat_list.dart';
import 'package:decamp/components/chat_input.dart';
import 'package:decamp/components/search_controls.dart';
import 'package:decamp/components/search_match_navigator.dart';
import 'package:decamp/components/project_title_bar.dart';
import 'package:decamp/utils/search_utils.dart';
import 'package:decamp/pages/sessions_history.dart';
import 'package:decamp/components/no_llm_configured_overlay.dart';
import 'package:decamp/services/sync_service.dart';
import 'package:decamp/components/sync_indicator.dart';
import 'package:logging/logging.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatSession extends ConsumerStatefulWidget {
  const ChatSession({super.key});

  @override
  ConsumerState<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends ConsumerState<ChatSession> {
  static final _log = Logger('ChatSession');

  bool _previousKeyboardVisible = false;
  bool _forceAppBarVisible = false;
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

  void _handleAbort() {
    final currentSessionId = ref.read(currentSessionIdProvider);
    final chatController = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );

    final currentProject = ref.read(currentProjectProvider);
    MultiplexedWebSocketChannel? syncChannel;
    if (currentProject != null) {
      syncChannel = ref.read(syncServiceProvider).getChannel(currentProject.id);
    }

    chatController.abortCommand(syncChannel);
  }

  // FIXME: This logic is duplicated with SessionController.createNewSession
  // and also does not belong here.
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

    // Handle /summarize command
    final summarizeRegex = RegExp(r'^/summarize(\s+(.*))?$');
    final summarizeMatch = summarizeRegex.firstMatch(content.trim());
    if (summarizeMatch != null) {
      final arg = summarizeMatch.group(2)?.trim().toLowerCase();
      final hideMessages = arg != 'nohide';
      final controller = ref.read(
        chatControllerProvider(currentSessionId).notifier,
      );
      await controller.summarize(hideMessages: hideMessages);
      return;
    }

    // Get the controller
    final controller = ref.read(
      chatControllerProvider(currentSessionId).notifier,
    );

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

    // Watch active model
    final activeModelAsync = ref.watch(activeModelIdentifierProvider);
    final activeModel = activeModelAsync.valueOrNull;

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
    final chatState = ref.watch(chatControllerProvider(currentSessionId));
    // Use session lock as single source of truth for loading state
    final isLoading =
        ref.watch(currentSessionLockProvider).valueOrNull ?? false;

    final chatController = ref.watch(
      chatControllerProvider(currentSessionId).notifier,
    );
    final messagesAsync = ref.watch(currentSessionMessagesProvider);

    final deviceTokenAsync = ref.watch(deviceTokenProvider);
    final messageSubscribersAsync = ref.watch(
      messageSubscribersBySessionAndDeviceProvider((
        currentSessionId ?? '',
        deviceTokenAsync.valueOrNull ?? '',
      )),
    );

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
    final topPadding = MediaQuery.of(context).padding.top;

    // Track keyboard state changes
    if (keyboardVisible != _previousKeyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _previousKeyboardVisible = keyboardVisible;
            if (!keyboardVisible) {
              _forceAppBarVisible = false;
            }
          });
        }
      });
    }

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        _inputFocusNode.unfocus();
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
            (keyboardVisible && !_forceAppBarVisible)
                ? 0
                : kToolbarHeight + topPadding,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: (keyboardVisible && !_forceAppBarVisible)
                ? 0
                : kToolbarHeight + topPadding,
            child: AppBar(
              title: ProjectTitleBar(
                title: currentProjectName,
                leading: (currentProject?.serverUrl != null)
                    ? const SyncIndicator()
                    : null,
              ),
              centerTitle: false,
              backgroundColor: ShadTheme.of(context).colorScheme.card,
              actions: [
                ShadButton.ghost(
                  width: 40,
                  height: 40,
                  padding: EdgeInsets.zero,
                  onPressed: hasProject ? _activateSearch : null,
                  child: const Icon(LucideIcons.search),
                ),
                ShadButton.ghost(
                  width: 40,
                  height: 40,
                  padding: EdgeInsets.zero,
                  onPressed: hasProject ? _createNewSession : null,
                  child: const Icon(LucideIcons.plus),
                ),
                ShadButton.ghost(
                  width: 40,
                  height: 40,
                  padding: EdgeInsets.zero,
                  onPressed: _showSessionHistory,
                  child: const Icon(LucideIcons.history),
                ),
              ],
            ),
          ),
        ),
        drawer: const MainDrawer(),
        body: SafeArea(
          top: !keyboardVisible,
          child: Stack(
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
                            isLoading: isLoading,
                            streamingMessageStream:
                                chatController.streamingMessageStream,
                            searchMatches: _searchMatches,
                            currentMatchIndex: _searchMatches.isNotEmpty
                                ? _currentMatchIndex
                                : null,
                            searchNavigatorHeight:
                                _isSearchActive && _searchQuery.isNotEmpty
                                ? _searchNavigatorHeight + 16
                                : 0,
                            messageSubscribers:
                                messageSubscribersAsync.valueOrNull,
                          ),
                          loading: () => Center(
                            child: CircularProgressIndicator(
                              color: ShadTheme.of(context).colorScheme.primary,
                            ),
                          ),
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
                      onAbort: isLoading ? _handleAbort : null,
                      isLoading: isLoading,
                      enabled: hasProject,
                      focusNode: _inputFocusNode,
                      hintText: activeModel != null
                          ? 'Send to $activeModel'
                          : 'No LLM Model selected.',
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

              // Reveal control
              if (keyboardVisible && !_forceAppBarVisible)
                Positioned(
                  top: topPadding,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _forceAppBarVisible = true),
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity! > 0) {
                        setState(() => _forceAppBarVisible = true);
                      }
                    },
                    child: Center(
                      child: CustomPaint(
                        size: const Size(200, 20),
                        painter: RevealTabPainter(
                          color: ShadTheme.of(context).colorScheme.accent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RevealTabPainter extends CustomPainter {
  final Color color;

  RevealTabPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final visualHeight = size.height * 0.4;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, 0); // Top left
    path.lineTo(visualHeight, visualHeight); // Bottom left
    path.lineTo(size.width - visualHeight, visualHeight); // Bottom right
    path.lineTo(size.width, 0); // Top right
    // path.close();

    canvas.drawPath(path, paint);

    // Optional: Add a small handle line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width / 2 - 10, visualHeight / 2),
      Offset(size.width / 2 + 10, visualHeight / 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
