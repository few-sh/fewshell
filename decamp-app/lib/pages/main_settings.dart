import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'qr_scanner_page.dart';
import '../providers/theme_provider.dart';
import '../providers/project_provider.dart';
import '../providers/llm_settings_provider.dart';
import '../providers/ssh_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../models/llm_api_settings.dart';
import '../models/ssh_settings.dart';
import '../components/ai_model_dialog.dart';
import '../components/ssh_settings_dialog.dart';
import '../components/project_title_bar.dart';

/// Main settings page with User and Project settings tabs
class MainSettingsPage extends ConsumerStatefulWidget {
  const MainSettingsPage({super.key});

  @override
  ConsumerState<MainSettingsPage> createState() => _MainSettingsPageState();
}

class _MainSettingsPageState extends ConsumerState<MainSettingsPage>
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
        title: const ProjectTitleBar(title: 'Settings'),
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
                Tab(text: 'User Settings'),
                Tab(text: 'Project Settings'),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildUserSettings(), _buildProjectSettings()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAIModelsSection(isGlobal: true),
        const SizedBox(height: 24),
        _buildThemeSection(),
      ],
    );
  }

  Widget _buildProjectSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAIModelsSection(isGlobal: false),
        const SizedBox(height: 24),
        _buildRemoteShellSection(),
      ],
    );
  }

  Future<void> _scanAndConfigureProject(String? projectId) async {
    if (projectId == null) return _showSnack('Please select a project first');

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );

    if (result == null) return;

    try {
      final data = jsonDecode(result) as Map<String, dynamic>;

      if (data['l'] != null && data['k'] != null) {
        await _configureLlm(projectId, data['l'], data['k']);
      }

      if (data['i'] != null && data['s'] != null) {
        await _configureSsh(projectId, data['i'], data['s']);
      }

      if (mounted) _showSnack('Project configured successfully');
    } catch (e) {
      if (mounted) _showSnack('Error configuring project: $e');
    }
  }

  Future<void> _configureLlm(
    String projectId,
    String providerCode,
    String apiKey,
  ) async {
    final apiType = LlmApiType.fromCode(providerCode);
    if (apiType == null) return;

    final modelId = apiType.defaultModelId;
    final baseUrl = apiType.defaultBaseUrl;

    final llmNotifier = ref.read(
      projectLlmSettingsProvider(projectId).notifier,
    );
    final currentModels = ref.read(projectLlmSettingsProvider(projectId));
    final exists = currentModels.any((m) => m.identifier == modelId);

    if (exists) {
      await llmNotifier.updateLlmSettings(
        identifier: modelId,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );
    } else {
      await llmNotifier.addLlmSettings(
        identifier: modelId,
        apiType: apiType,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );
    }
  }

  Future<void> _configureSsh(
    String projectId,
    String userHost,
    String privateKey,
  ) async {
    var formattedKey = privateKey;
    if (!formattedKey.contains('-----BEGIN')) {
      formattedKey =
          '-----BEGIN OPENSSH PRIVATE KEY-----\n$formattedKey\n-----END OPENSSH PRIVATE KEY-----';
    }

    final parts = userHost.split('@');
    if (parts.length != 2) {
      throw FormatException(
        'Invalid SSH host format: $userHost. Expected user@host',
      );
    }

    final username = parts[0];
    final host = parts[1];

    final sshNotifier = ref.read(
      projectSshSettingsProvider(projectId).notifier,
    );
    final currentSsh = ref.read(projectSshSettingsProvider(projectId));

    if (currentSsh == null) {
      await sshNotifier.createSshSettings(
        host: host,
        port: 22,
        username: username,
        authMethod: SshAuthMethod.privateKey,
        privateKey: formattedKey,
      );
    } else {
      await sshNotifier.updateSshSettings(
        host: host,
        username: username,
        authMethod: SshAuthMethod.privateKey,
        privateKey: formattedKey,
      );
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProjectSelector() {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(projectsStreamProvider);
    final currentProjectId = ref.watch(currentProjectIdProvider);

    return Card(
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
            projectsAsync.when(
              data: (projects) {
                if (projects.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
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
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.folder),
                        ),
                        hint: const Text('Select a project'),
                        value: currentProjectId,
                        items: projects.map((project) {
                          return DropdownMenuItem<String>(
                            value: project.id,
                            child: Text(project.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(currentProjectIdProvider.notifier).state =
                                value;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () =>
                          _scanAndConfigureProject(currentProjectId),
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Scan Project Config',
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Error loading projects: $error',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIModelsSection({required bool isGlobal}) {
    final theme = Theme.of(context);

    // Get the appropriate provider based on scope
    final llmSettings = isGlobal
        ? ref.watch(globalLlmSettingsProvider)
        : (ref.watch(currentProjectIdProvider) != null
              ? ref.watch(
                  projectLlmSettingsProvider(
                    ref.watch(currentProjectIdProvider)!,
                  ),
                )
              : <LlmApiSettings>[]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Models',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showAddModelDialog(isGlobal: isGlobal),
              icon: const Icon(Icons.add),
              label: const Text('Add Model'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Show message if no project selected in project settings
        if (!isGlobal && ref.watch(currentProjectIdProvider) == null)
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
                    'Select a project to configure project-specific AI models.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (llmSettings.isEmpty)
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
                    'No AI models configured yet. Click "Add Model" to get started.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...llmSettings.map(
            (settings) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildModelCard(
                settings: settings,
                isGlobal: isGlobal,
                onEdit: () => _showEditModelDialog(
                  settings: settings,
                  isGlobal: isGlobal,
                ),
                onDelete: () => _showDeleteConfirmation(
                  settings: settings,
                  isGlobal: isGlobal,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModelCard({
    required LlmApiSettings settings,
    required bool isGlobal,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);

    // Get the current default identifier
    final String? currentDefault;
    if (isGlobal) {
      currentDefault = ref.watch(globalSettingsProvider).defaultLlmIdentifier;
    } else {
      final currentProjectId = ref.watch(currentProjectIdProvider);
      currentDefault = currentProjectId != null
          ? ref
                .watch(projectSettingsProvider(currentProjectId))
                ?.defaultLlmIdentifier
          : null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _setDefaultModel(
                      settings.identifier,
                      isGlobal: isGlobal,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(
                          value: settings.identifier,
                          groupValue: currentDefault,
                          onChanged: (value) {
                            if (value != null) {
                              _setDefaultModel(value, isGlobal: isGlobal);
                            }
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        Flexible(
                          child: Text(
                            settings.identifier,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!settings.enabled)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: const Text('Disabled'),
                          backgroundColor: theme.colorScheme.errorContainer,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: onEdit,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(
                left: 48,
              ), // Align with text after radio
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          settings.baseUrl,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.key,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '••••••••••${settings.identifier.substring(0, settings.identifier.length > 4 ? 4 : settings.identifier.length)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.8,
                          ),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteShellSection() {
    final theme = Theme.of(context);
    final currentProjectId = ref.watch(currentProjectIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Remote Shell',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Show message if no project selected
        if (currentProjectId == null)
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
                    'Select a project to configure remote shell connection.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          _buildSshSettingsCard(currentProjectId),
      ],
    );
  }

  Widget _buildSshSettingsCard(String projectId) {
    final theme = Theme.of(context);
    final sshSettings = ref.watch(projectSshSettingsProvider(projectId));

    if (sshSettings == null) {
      // No SSH configuration yet
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No remote shell configured yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showSshSettingsDialog(projectId: projectId),
                icon: const Icon(Icons.add),
                label: const Text('Configure Connection'),
              ),
            ),
          ],
        ),
      );
    }

    // SSH configuration exists
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${sshSettings.username}@${sshSettings.host}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!sshSettings.enabled)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: const Text('Disabled'),
                          backgroundColor: theme.colorScheme.errorContainer,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showSshSettingsDialog(
                        projectId: projectId,
                        existingSettings: sshSettings,
                      ),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          _showDeleteSshConfirmation(projectId: projectId),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.dns,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  '${sshSettings.host}:${sshSettings.port}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  sshSettings.authMethod == SshAuthMethod.password
                      ? Icons.password
                      : Icons.key,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  sshSettings.authMethod == SshAuthMethod.password
                      ? 'Password Authentication'
                      : 'Private Key Authentication',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSshSettingsDialog({
    required String projectId,
    SshSettings? existingSettings,
  }) {
    SshSettingsDialog.show(
      context,
      ref,
      projectId: projectId,
      existingSettings: existingSettings,
    );
  }

  void _showDeleteSshConfirmation({required String projectId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Remote Shell Configuration'),
        content: const Text(
          'Are you sure you want to delete the remote shell configuration? '
          'This will also delete all associated credentials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(projectSshSettingsProvider(projectId).notifier)
                    .deleteSshSettings();

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Remote shell configuration deleted'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting configuration: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
    final theme = Theme.of(context);
    final currentThemeMode = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildThemeCard(
                title: 'Light',
                icon: Icons.light_mode,
                isSelected: currentThemeMode == ThemeMode.light,
                onTap: () {
                  ref
                      .read(themeProvider.notifier)
                      .setThemeMode(ThemeMode.light);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildThemeCard(
                title: 'Dark',
                icon: Icons.dark_mode,
                isSelected: currentThemeMode == ThemeMode.dark,
                onTap: () {
                  ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildThemeCard(
                title: 'System',
                icon: Icons.brightness_auto,
                isSelected: currentThemeMode == ThemeMode.system,
                onTap: () {
                  ref
                      .read(themeProvider.notifier)
                      .setThemeMode(ThemeMode.system);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDefaultModel(String identifier, {required bool isGlobal}) {
    if (isGlobal) {
      ref.read(globalLlmSettingsProvider.notifier).setDefaultLlm(identifier);
    } else {
      final currentProjectId = ref.read(currentProjectIdProvider);
      if (currentProjectId != null) {
        ref
            .read(projectLlmSettingsProvider(currentProjectId).notifier)
            .setDefaultLlm(identifier);
      }
    }
  }

  void _showAddModelDialog({required bool isGlobal}) {
    AIModelDialog.show(context, ref, isGlobal: isGlobal);
  }

  void _showEditModelDialog({
    required LlmApiSettings settings,
    required bool isGlobal,
  }) {
    AIModelDialog.show(
      context,
      ref,
      isGlobal: isGlobal,
      existingSettings: settings,
    );
  }

  void _showDeleteConfirmation({
    required LlmApiSettings settings,
    required bool isGlobal,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete AI Model'),
        content: Text(
          'Are you sure you want to delete "${settings.identifier}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                if (isGlobal) {
                  await ref
                      .read(globalLlmSettingsProvider.notifier)
                      .deleteLlmSettings(settings.identifier);
                } else {
                  final projectId = ref.read(currentProjectIdProvider);
                  if (projectId != null) {
                    await ref
                        .read(projectLlmSettingsProvider(projectId).notifier)
                        .deleteLlmSettings(settings.identifier);
                  }
                }

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted model: ${settings.identifier}'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting model: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
