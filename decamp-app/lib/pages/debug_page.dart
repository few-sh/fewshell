import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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

// Components
import 'package:decamp/components/empty_placeholder.dart';
import 'package:decamp/components/main_drawer.dart';
import 'package:decamp/components/new_snippet_card.dart';
import 'package:decamp/components/no_llm_configured_overlay.dart';
import 'package:decamp/components/multi_command_approval_overlay.dart';
import 'package:decamp/components/project_setup_view.dart';
import 'package:decamp/components/sync_indicator.dart';
import 'package:decamp/components/user_badge.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Page')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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

            // Add more as needed/possible
          ],
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
}
