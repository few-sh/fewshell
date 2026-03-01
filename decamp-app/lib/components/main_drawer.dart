import 'package:decamp/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:decamp/pages/projects_page.dart';
import 'package:decamp/pages/main_settings.dart';
import 'package:decamp/pages/agent_instructions_page.dart';
import 'package:decamp/pages/secrets_page.dart';
import 'package:decamp/pages/snippets_page.dart';
import 'package:decamp/pages/saved_prompts_page.dart';
import 'package:decamp/components/user_badge.dart';

import 'package:decamp/pages/feedback_page.dart';
import 'package:decamp/pages/debug_page.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    final currentProjectName = currentProject?.name ?? 'No Project';
    final hasProject = currentProject != null;
    final theme = ShadTheme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.background,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  color: theme.colorScheme.card,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const UserBadge(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: hasProject
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ProjectsPage(),
                                          ),
                                        );
                                      },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              currentProjectName,
                                              style: theme.textTheme.h4
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        if (!hasProject) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            LucideIcons.plus,
                                            size: 20,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hasProject
                                          ? (currentProject.description ?? '')
                                          : 'Tap to create a project',
                                      style: theme.textTheme.muted.copyWith(
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ShadButton.ghost(
                              width: 40,
                              height: 40,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProjectsPage(),
                                  ),
                                );
                              },
                              child: const Icon(LucideIcons.arrowLeftRight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _DrawerItem(
                  icon: LucideIcons.messageSquare,
                  label: 'Quick Prompts',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SavedPromptsPage(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: LucideIcons.code,
                  label: 'Snippets',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SnippetsPage(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: LucideIcons.key,
                  label: 'Secrets',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SecretsPage(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: LucideIcons.fileText,
                  label: 'Agent Instructions',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AgentInstructionsPage(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: LucideIcons.settings,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainSettingsPage(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: LucideIcons.messageSquare,
                  label: 'Feedback',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeedbackPage(),
                      ),
                    );
                  },
                ),
                if (kDebugMode)
                  _DrawerItem(
                    icon: LucideIcons.bug,
                    label: 'Debug',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DebugPage(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Copyright 2026 Fewshot Corp',
                    style: theme.textTheme.muted.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Consumer(
                    builder: (context, ref, child) {
                      final packageInfo = ref.watch(packageInfoProvider);
                      return packageInfo.when(
                        data: (info) => Text(
                          'Version ${info.version} (${info.buildNumber})',
                          style: theme.textTheme.muted.copyWith(fontSize: 11),
                        ),
                        loading: () => const SizedBox(
                          height: 10,
                          width: 50,
                        ), // Placeholder
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: ShadButton.ghost(
        width: double.infinity,
        mainAxisAlignment: MainAxisAlignment.start,
        leading: Icon(icon, size: 18),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
