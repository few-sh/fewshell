import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/secret_provider.dart';
import '../providers/project_selection_provider.dart';
import '../components/secret_dialog.dart';
import '../components/project_title_bar.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const ProjectTitleBar(title: 'Secrets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Stationary tab bar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
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
    return FutureBuilder<Map<String, String>>(
      future: ref.watch(keychainServiceProvider).listGlobalSecrets(),
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
            _buildSecurityInfoBanner(),
            Expanded(
              child: secrets.isEmpty
                  ? _buildEmptyState('No user secrets yet')
                  : _buildSecretsList(secrets, isGlobal: true),
            ),
            _buildAddButton(
              onPressed: () => _showAddSecretDialog(isGlobal: true),
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
        _buildSecurityInfoBanner(),
        Expanded(
          child: currentProjectId == null
              ? _buildEmptyState('Please select a project')
              : FutureBuilder<Map<String, String>>(
                  future: ref
                      .watch(keychainServiceProvider)
                      .listProjectSecrets(currentProjectId),
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

                    return secrets.isEmpty
                        ? _buildEmptyState('No project secrets yet')
                        : _buildSecretsList(
                            secrets,
                            isGlobal: false,
                            projectId: currentProjectId,
                          );
                  },
                ),
        ),
        if (currentProjectId != null)
          _buildAddButton(
            onPressed: () => _showAddSecretDialog(
              isGlobal: false,
              projectId: currentProjectId,
            ),
          ),
      ],
    );
  }

  Widget _buildProjectSelector(
    List<dynamic> projects,
    String? currentProjectId,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Project',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (projects.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No projects yet. Create a project from the main drawer.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: currentProjectId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                hint: const Text('Select a project'),
                items: projects.map((project) {
                  return DropdownMenuItem<String>(
                    value: project.id,
                    child: Text(project.name),
                  );
                }).toList(),
                onChanged: (projectId) {
                  if (projectId != null) {
                    ref.read(currentProjectIdProvider.notifier).state =
                        projectId;
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecretsList(
    Map<String, String> secrets, {
    required bool isGlobal,
    String? projectId,
  }) {
    final sortedKeys = secrets.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final value = secrets[key]!;

        return _buildSecretCard(
          key: key,
          value: value,
          isGlobal: isGlobal,
          projectId: projectId,
        );
      },
    );
  }

  Widget _buildSecretCard({
    required String key,
    required String value,
    required bool isGlobal,
    String? projectId,
  }) {
    final theme = Theme.of(context);
    bool isObscured = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        key,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditSecretDialog(
                        key: key,
                        value: value,
                        isGlobal: isGlobal,
                        projectId: projectId,
                      ),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _confirmDeleteSecret(
                        key: key,
                        isGlobal: isGlobal,
                        projectId: projectId,
                      ),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isObscured ? '••••••••••••••••' : value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        maxLines: isObscured ? 1 : null,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isObscured ? Icons.visibility : Icons.visibility_off,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          isObscured = !isObscured;
                        });
                      },
                      tooltip: isObscured ? 'Show' : 'Hide',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.key_off,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfoBanner() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• All secrets are stored using secure system keychain',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Secrets are always redacted from the LLM',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: const Text('Add Secret'),
      ),
    );
  }

  Future<void> _showAddSecretDialog({
    required bool isGlobal,
    String? projectId,
  }) async {
    await SecretDialog.show(
      context,
      onSave: (key, value) async {
        try {
          if (isGlobal) {
            await ref
                .read(keychainServiceProvider)
                .saveGlobalSecret(key, value);
          } else {
            if (projectId != null) {
              await ref
                  .read(keychainServiceProvider)
                  .saveProjectSecret(projectId, key, value);
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Added secret: $key')));
            setState(() {}); // Refresh the list
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error adding secret: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _showEditSecretDialog({
    required String key,
    required String value,
    required bool isGlobal,
    String? projectId,
  }) async {
    await SecretDialog.show(
      context,
      existingKey: key,
      existingValue: value,
      onSave: (_, newValue) async {
        try {
          if (isGlobal) {
            await ref
                .read(keychainServiceProvider)
                .saveGlobalSecret(key, newValue);
          } else {
            if (projectId != null) {
              await ref
                  .read(keychainServiceProvider)
                  .saveProjectSecret(projectId, key, newValue);
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Updated secret: $key')));
            setState(() {}); // Refresh the list
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating secret: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _confirmDeleteSecret({
    required String key,
    required bool isGlobal,
    String? projectId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Secret'),
        content: Text('Are you sure you want to delete "$key"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Deleted secret: $key')));
          setState(() {}); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting secret: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
