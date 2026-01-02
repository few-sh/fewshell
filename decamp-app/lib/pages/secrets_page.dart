import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../themes/shad_layout_theme.dart';
import '../providers/secret_provider.dart';
import '../providers/project_provider.dart';
import '../components/secret_dialog.dart';
import '../components/project_title_bar.dart';
import '../components/confirmation_dialog.dart';
import '../components/empty_placeholder.dart';

/// Secrets management page with User Secrets and Project Secrets tabs
class SecretsPage extends ConsumerStatefulWidget {
  const SecretsPage({super.key});

  @override
  ConsumerState<SecretsPage> createState() => _SecretsPageState();
}

class _SecretsPageState extends ConsumerState<SecretsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const ProjectTitleBar(title: 'Secrets'),
        leading: ShadButton.ghost(
          child: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Stationary tab bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    Theme.of(
                      context,
                    ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                    800,
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.mutedForeground,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                tabs: const [
                  Tab(text: 'User Secrets'),
                  Tab(text: 'Project Secrets'),
                ],
              ),
            ),
          ),
          // Scrollable content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildUserSecretsTab(), _buildProjectSecretsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSecretsTab() {
    return FutureBuilder<Map<String, Secret>>(
      future: ref.watch(keychainServiceProvider).listGlobalSecretObjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading secrets: ${snapshot.error}'),
          );
        }

        final secrets = snapshot.data ?? {};

        return Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      Theme.of(
                        context,
                      ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                      800,
                ),
                child: _buildSecurityInfoBanner(),
              ),
            ),
            Expanded(
              child: secrets.isEmpty
                  ? Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              Theme.of(context)
                                  .extension<ShadLayoutTheme>()
                                  ?.centeredContentMaxWidth ??
                              800,
                        ),
                        child: _buildEmptyState('No user secrets yet'),
                      ),
                    )
                  : _buildSecretsList(secrets, isGlobal: true),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      Theme.of(
                        context,
                      ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                      800,
                ),
                child: _buildAddButton(
                  label: 'Add User Secret',
                  onPressed: () => _showAddSecretDialog(isGlobal: true),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProjectSecretsTab() {
    final currentProjectId = ref.watch(currentProjectIdProvider);

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  Theme.of(
                    context,
                  ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                  800,
            ),
            child: _buildSecurityInfoBanner(),
          ),
        ),
        Expanded(
          child: currentProjectId == null
              ? Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          Theme.of(context)
                              .extension<ShadLayoutTheme>()
                              ?.centeredContentMaxWidth ??
                          800,
                    ),
                    child: _buildEmptyState('Please select a project'),
                  ),
                )
              : ref
                    .watch(projectSecretsProvider(currentProjectId))
                    .when(
                      data: (secrets) {
                        return secrets.isEmpty
                            ? Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        Theme.of(context)
                                            .extension<ShadLayoutTheme>()
                                            ?.centeredContentMaxWidth ??
                                        800,
                                  ),
                                  child: _buildEmptyState(
                                    'No project secrets yet',
                                  ),
                                ),
                              )
                            : _buildSecretsList(
                                secrets,
                                isGlobal: false,
                                projectId: currentProjectId,
                              );
                      },
                      error: (error, stack) =>
                          Center(child: Text('Error loading secrets: $error')),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                    ),
        ),
        if (currentProjectId != null)
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    Theme.of(
                      context,
                    ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                    800,
              ),
              child: _buildAddButton(
                label: 'Add Project Secret',
                onPressed: () => _showAddSecretDialog(
                  isGlobal: false,
                  projectId: currentProjectId,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSecretsList(
    Map<String, Secret> secrets, {
    required bool isGlobal,
    String? projectId,
  }) {
    final sortedKeys = secrets.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final secret = secrets[key]!;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  Theme.of(
                    context,
                  ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
                  800,
            ),
            child: _buildSecretCard(
              key: key,
              secret: secret,
              isGlobal: isGlobal,
              projectId: projectId,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecretCard({
    required String key,
    required Secret secret,
    required bool isGlobal,
    String? projectId,
  }) {
    final theme = ShadTheme.of(context);
    bool isObscured = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShadCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        key,
                        style: theme.textTheme.h4.copyWith(
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    ShadButton.ghost(
                      width: 32,
                      height: 32,
                      padding: EdgeInsets.zero,
                      child: const Icon(LucideIcons.pencil, size: 16),
                      onPressed: () => _showEditSecretDialog(
                        key: key,
                        secret: secret,
                        isGlobal: isGlobal,
                        projectId: projectId,
                      ),
                    ),
                    ShadButton.ghost(
                      width: 32,
                      height: 32,
                      padding: EdgeInsets.zero,
                      child: const Icon(LucideIcons.trash2, size: 16),
                      onPressed: () => _confirmDeleteSecret(
                        key: key,
                        isGlobal: isGlobal,
                        projectId: projectId,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topLeft,
                        curve: Curves.easeInOut,
                        child: Text(
                          isObscured ? '••••••••••••••••' : secret.value,
                          style: theme.textTheme.p.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.mutedForeground,
                          ),
                          maxLines: isObscured ? 1 : null,
                          overflow: isObscured ? TextOverflow.ellipsis : null,
                        ),
                      ),
                    ),
                    ShadButton.ghost(
                      width: 32,
                      height: 32,
                      padding: EdgeInsets.zero,
                      child: Icon(
                        isObscured ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          isObscured = !isObscured;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ShadSwitch(
                  value: secret.isVisibleToLlm,
                  onChanged: (value) => _toggleVisibility(
                    key: key,
                    secret: secret,
                    isVisible: value,
                    isGlobal: isGlobal,
                    projectId: projectId,
                  ),
                  label: const Text('Visible to AI'),
                  sublabel: const Text('Include this secret in the AI context'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return EmptyPlaceholder(
      icon: LucideIcons.key,
      title: 'No Secrets',
      subtitle: message,
    );
  }

  Widget _buildSecurityInfoBanner() {
    final theme = ShadTheme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.shieldCheck,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• All secrets are stored using secure system keychain',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Secrets are always redacted from the LLM',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerRight,
      child: ShadButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plus, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSecretDialog({
    required bool isGlobal,
    String? projectId,
  }) async {
    await SecretDialog.show(
      context,
      title: isGlobal ? 'Add User Secret' : 'Add Project Secret',
      onSave: (key, value, isVisibleToLlm) async {
        try {
          final secret = Secret(value: value, isVisibleToLlm: isVisibleToLlm);
          if (isGlobal) {
            await ref
                .read(keychainServiceProvider)
                .saveGlobalSecret(key, secret);
          } else {
            if (projectId != null) {
              await ref
                  .read(keychainServiceProvider)
                  .saveProjectSecret(projectId, key, secret);
            }
          }

          if (mounted) {
            ShadToaster.of(
              context,
            ).show(ShadToast(description: Text('Added secret: $key')));
            setState(() {}); // Refresh the list
          }
        } catch (e) {
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast(
                description: Text('Error adding secret: $e'),
                action: ShadButton.destructive(
                  child: const Text('Dismiss'),
                  onPressed: () => ShadToaster.of(context).hide(),
                ),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _showEditSecretDialog({
    required String key,
    required Secret secret,
    required bool isGlobal,
    String? projectId,
  }) async {
    await SecretDialog.show(
      context,
      existingKey: key,
      existingValue: secret.value,
      initialIsVisibleToLlm: secret.isVisibleToLlm,
      onSave: (_, newValue, isVisibleToLlm) async {
        try {
          final newSecret = secret.copyWith(
            value: newValue,
            isVisibleToLlm: isVisibleToLlm,
          );
          if (isGlobal) {
            await ref
                .read(keychainServiceProvider)
                .saveGlobalSecret(key, newSecret);
          } else {
            if (projectId != null) {
              await ref
                  .read(keychainServiceProvider)
                  .saveProjectSecret(projectId, key, newSecret);
            }
          }

          if (mounted) {
            ShadToaster.of(
              context,
            ).show(ShadToast(description: Text('Updated secret: $key')));
            setState(() {}); // Refresh the list
          }
        } catch (e) {
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast(
                description: Text('Error updating secret: $e'),
                action: ShadButton.destructive(
                  child: const Text('Dismiss'),
                  onPressed: () => ShadToaster.of(context).hide(),
                ),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _toggleVisibility({
    required String key,
    required Secret secret,
    required bool isVisible,
    required bool isGlobal,
    String? projectId,
  }) async {
    try {
      final newSecret = secret.copyWith(isVisibleToLlm: isVisible);
      if (isGlobal) {
        await ref
            .read(keychainServiceProvider)
            .saveGlobalSecret(key, newSecret);
      } else {
        if (projectId != null) {
          await ref
              .read(keychainServiceProvider)
              .saveProjectSecret(projectId, key, newSecret);
        }
      }
      if (mounted) {
        setState(() {}); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error updating visibility: $e'),
            action: ShadButton.destructive(
              child: const Text('Dismiss'),
              onPressed: () => ShadToaster.of(context).hide(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteSecret({
    required String key,
    required bool isGlobal,
    String? projectId,
  }) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Secret',
      content: 'Are you sure you want to delete "$key"?',
      confirmLabel: 'Delete',
    );

    if (confirmed == true) {
      try {
        if (isGlobal) {
          await ref.read(keychainServiceProvider).deleteGlobalSecret(key);
        } else {
          if (projectId != null) {
            await ref
                .read(keychainServiceProvider)
                .deleteProjectSecret(projectId, key);
          }
        }

        if (mounted) {
          ShadToaster.of(
            context,
          ).show(ShadToast(description: Text('Deleted secret: $key')));
          setState(() {}); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ShadToaster.of(context).show(
            ShadToast(
              description: Text('Error deleting secret: $e'),
              action: ShadButton.destructive(
                child: const Text('Dismiss'),
                onPressed: () => ShadToaster.of(context).hide(),
              ),
            ),
          );
        }
      }
    }
  }
}
