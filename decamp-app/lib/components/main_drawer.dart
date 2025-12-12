import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/providers/project_provider.dart';
import 'package:decamp/pages/projects_page.dart';
import 'package:decamp/pages/main_settings.dart';
import 'package:decamp/pages/agent_instructions_page.dart';
import 'package:decamp/pages/secrets_page.dart';
import 'package:decamp/pages/snippets_page.dart';
import 'package:decamp/components/user_badge.dart';
import 'package:decamp/providers/package_info_provider.dart';

class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    final currentProjectName = currentProject?.name ?? 'No Project';
    final hasProject = currentProject != null;

    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const UserBadge(),
                      const SizedBox(height: 8),
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
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!hasProject) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.add_circle_outline,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasProject
                                        ? (currentProject.description ?? '')
                                        : 'Tap to create a project',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.swap_horiz),
                            tooltip: 'Switch Project',
                            iconSize: 28,
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProjectsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Snippets'),
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
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('Secrets'),
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
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Agent Instructions'),
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
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
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
                    'Copyright 2025 Fewshot Corp',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Consumer(
                    builder: (context, ref, child) {
                      final packageInfo = ref.watch(packageInfoProvider);
                      return packageInfo.when(
                        data: (info) => Text(
                          'Version ${info.version}+${info.buildNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (error, stack) => const SizedBox.shrink(),
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
