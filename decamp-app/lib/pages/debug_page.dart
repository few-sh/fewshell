import 'package:decamp/providers/providers.dart';
import 'package:decamp/providers/ssh_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:decamp/components/ssh_settings_dialog.dart';

import 'package:decamp/pages/agent_instructions_page.dart';
import 'package:decamp/pages/chat_session.dart';
import 'package:decamp/pages/feedback_page.dart';
import 'package:decamp/pages/main_settings.dart';
import 'package:decamp/pages/project_setup_page.dart';
import 'package:decamp/pages/projects_page.dart';
import 'package:decamp/pages/qr_scanner_page.dart';
import 'package:decamp/pages/secrets_page.dart';
import 'package:decamp/pages/sessions_history.dart';
import 'package:decamp/pages/snippets_page.dart';
import 'package:decamp/themes/shad_layout_theme.dart';

// Components
import 'package:decamp/components/empty_placeholder.dart';
import 'package:decamp/components/main_drawer.dart';
import 'package:decamp/components/new_snippet_card.dart';
import 'package:decamp/components/no_llm_configured_overlay.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/project_setup_view.dart';
import 'package:decamp/components/sync_indicator.dart';
import 'package:decamp/components/user_badge.dart';
import 'package:decamp/components/connect_to_agent_server.dart';
import 'package:decamp/components/notification_debug_widget.dart';

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class DebugPage extends ConsumerWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Page')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  Theme.of(
                    context,
                  ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                  800,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pages',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildPageButton(
                  context,
                  'Agent Instructions',
                  const AgentInstructionsPage(),
                ),
                _buildPageButton(context, 'Chat Session', const ChatSession()),
                _buildPageButton(context, 'Feedback', const FeedbackPage()),
                _buildPageButton(
                  context,
                  'Main Settings',
                  const MainSettingsPage(),
                ),
                _buildPageButton(
                  context,
                  'Project Setup',
                  const ProjectSetupPage(),
                ),
                _buildPageButton(context, 'Projects', const ProjectsPage()),
                _buildPageButton(context, 'QR Scanner', const QrScannerPage()),
                _buildPageButton(context, 'Secrets', const SecretsPage()),
                _buildPageButton(
                  context,
                  'Sessions History',
                  const SessionsHistoryPage(),
                ),
                _buildPageButton(context, 'Snippets', const SnippetsPage()),

                const SizedBox(height: 20),
                const Text(
                  'Components (Viewers)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Add buttons for components here.
                // Many components require specific props, so we might need to wrap them or provide dummy data.
                // For now, I'll add a few that are likely to be standalone or easy to mock.
                _buildComponentButton(
                  context,
                  'Main Drawer',
                  const Scaffold(
                    drawer: MainDrawer(),
                    body: Center(child: Text('Open Drawer')),
                  ),
                ),
                _buildComponentButton(
                  context,
                  'User Badge',
                  const Center(child: UserBadge()),
                ),
                _buildComponentButton(
                  context,
                  'Empty Placeholder',
                  const EmptyPlaceholder(
                    icon: LucideIcons.info,
                    title: 'Debug Placeholder',
                    subtitle: 'This is a debug placeholder component',
                  ),
                ),
                const SizedBox(height: 10),
                ShadButton.outline(
                  child: const Text('SSH Settings Dialog (Debug)'),
                  onPressed: () => _openSshSettingsDialog(context, ref),
                ),
                _buildComponentButton(
                  context,
                  'Sync Indicator',
                  const Center(child: SyncIndicator()),
                ),
                _buildComponentButton(
                  context,
                  'Project Setup View',
                  const ProjectSetupView(),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ShadButton.outline(
                    child: const Text('New Snippet Dialog'),
                    onPressed: () {
                      showNewSnippetDialog(context);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ShadButton.outline(
                    child: const Text('No LLM Configured Overlay'),
                    onPressed: () {
                      NoLlmConfiguredOverlay.show(context);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ShadButton.outline(
                    child: const Text('Multi Command Approval Overlay'),
                    onPressed: () {
                      MultiCommandApprovalOverlay.showTest(context);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ShadButton.outline(
                    child: const Text('Connect Global Dialog'),
                    onPressed: () =>
                        ConnectToAgentServerDialog.show(context, ref),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ShadButton.outline(
                    child: const Text('Open/Copy Document Directory'),
                    onPressed: () => _handleDocumentDirectory(context),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ShadButton.outline(
                    child: const Text('Open/Copy Project Directory'),
                    onPressed: () => _handleProjectDirectory(context, ref),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Push Notifications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const NotificationDebugWidget(),

                const SizedBox(height: 20),

                // Add more as needed/possible
                const SizedBox(height: 20),
                _buildDebugInfoCard(ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton(BuildContext context, String label, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ShadButton(
        child: Text(label),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
      ),
    );
  }

  Widget _buildComponentButton(
    BuildContext context,
    String label,
    Widget component,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ShadButton.outline(
        child: Text(label),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: Text(label)),
                body: component,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSshSettingsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    const debugProjectId = 'debug_project_id';
    final mockNotifier = MockProjectSshSettingsNotifier();

    await SshSettingsDialog.show(
      context,
      ref,
      projectId: debugProjectId,
      existingSettings: SshSettings(
        host: 'debug.example.com',
        port: 2222,
        username: 'debug_user',
        authMethod: SshAuthMethod.password,
        passwordSecretId: 'mock_password_id',
        enabled: true,
      ),
      password: 'mock_password_value',
      overrides: [
        projectSshSettingsProvider(
          debugProjectId,
        ).overrideWith((ref) => mockNotifier),
      ],
    );
  }

  Future<void> _handleDocumentDirectory(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    if (Platform.isIOS) {
      await Clipboard.setData(ClipboardData(text: dir.path));
      if (context.mounted) {
        ShadToaster.of(context).show(
          const ShadToast(
            description: Text('Document directory path copied to clipboard'),
          ),
        );
      }
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      if (Platform.isMacOS) {
        await Process.run('open', [dir.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [dir.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir.path]);
      }
      if (context.mounted) {
        ShadToaster.of(context).show(
          const ShadToast(description: Text('Opening document directory...')),
        );
      }
    }
  }

  Future<void> _handleProjectDirectory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final projectId = ref.watch(currentProjectIdProvider);
    if (projectId == null) {
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(const ShadToast(description: Text('No project selected')));
      }
      return;
    }
    final baseDir = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${baseDir.path}/projects/$projectId');
    if (Platform.isIOS) {
      await Clipboard.setData(ClipboardData(text: projectDir.path));
      if (context.mounted) {
        ShadToaster.of(context).show(
          const ShadToast(
            description: Text('Project directory path copied to clipboard'),
          ),
        );
      }
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      if (Platform.isMacOS) {
        await Process.run('open', [projectDir.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [projectDir.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [projectDir.path]);
      }
      if (context.mounted) {
        ShadToaster.of(context).show(
          const ShadToast(description: Text('Opening project directory...')),
        );
      }
    }
  }

  Widget _buildDebugInfoCard(WidgetRef ref) {
    final project = ref.watch(currentProjectProvider);
    final session = ref.watch(currentSessionProvider);
    final nodeId = ref.watch(nodeIdProvider);
    final globalSettings = ref.watch(globalSettingsProvider);
    final projectSettings = project != null
        ? ref.watch(projectSettingsProvider(project.id))
        : null;

    const jsonEncoder = JsonEncoder.withIndent('  ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Debug Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SelectableText('Node ID: $nodeId'),
            const Divider(),
            const Text(
              'Current Project:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              project != null ? jsonEncoder.convert(project.toJson()) : 'None',
            ),
            const Divider(),
            const Text(
              'Current Session:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              session != null ? jsonEncoder.convert(session.toJson()) : 'None',
            ),
            const Divider(),
            const Text(
              'Global Settings:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(jsonEncoder.convert(globalSettings.toJson())),
            const Divider(),
            const Text(
              'Project Settings:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              projectSettings != null
                  ? jsonEncoder.convert(projectSettings.toJson())
                  : 'None',
            ),
          ],
        ),
      ),
    );
  }
}

class MockProjectSshSettingsNotifier extends StateNotifier<SshSettings?>
    implements ProjectSshSettingsNotifier {
  MockProjectSshSettingsNotifier() : super(null);

  @override
  Future<void> createSshSettings({
    required String host,
    required int port,
    required String username,
    required SshAuthMethod authMethod,
    String? password,
    String? privateKey,
    String? passphrase,
    String? sudoPassword,
  }) async {
    debugPrint('Mock createSshSettings: $host:$port, $username');
  }

  @override
  Future<void> updateSshSettings({
    String? host,
    int? port,
    String? username,
    SshAuthMethod? authMethod,
    String? password,
    String? privateKey,
    String? passphrase,
    String? sudoPassword,
    bool? enabled,
  }) async {
    debugPrint('Mock updateSshSettings: $host:$port');
  }

  @override
  Future<String?> getSecret(String secretId) async {
    return 'mock_secret_value';
  }

  @override
  Future<void> deleteSshSettings() async {
    debugPrint('Mock deleteSshSettings');
  }
}
