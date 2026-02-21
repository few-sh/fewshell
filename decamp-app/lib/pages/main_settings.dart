import 'dart:io';
import 'package:decamp/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../utils/ui_utils.dart';
import '../services/project_importer.dart';
import 'chat_session.dart';
import 'qr_scanner_page.dart';

import '../components/ai_model_dialog.dart';
import '../components/ssh_settings_dialog.dart';
import '../components/project_title_bar.dart';
import '../components/empty_placeholder.dart';
import '../providers/ssh_tunnel_provider.dart';
import '../themes/shad_layout_theme.dart';

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
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const ProjectTitleBar(title: 'Settings'),
          leading: ShadButton.ghost(
            width: 32,
            height: 32,
            padding: EdgeInsets.zero,
            decoration: const ShadDecoration(border: ShadBorder.none),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ChatSession()),
              (route) => false,
            ),
            child: const Icon(LucideIcons.arrowLeft, size: 16),
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
                  labelStyle: theme.textTheme.list.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  tabs: const [
                    Tab(text: 'User Settings'),
                    Tab(text: 'Project Settings'),
                  ],
                ),
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
      ),
    );
  }

  Widget _buildUserSettings() {
    return _buildResponsiveContent([
      _buildAIModelsSection(isGlobal: true),
      const SizedBox(height: 24),
      _buildThemeSection(),
    ]);
  }

  Widget _buildProjectSettings() {
    final currentProject = ref.watch(currentProjectProvider);

    return _buildResponsiveContent([
      if (currentProject != null) ...[
        _buildProjectNameSection(currentProject),
        const SizedBox(height: 24),
        _buildServerUrlSection(currentProject),
        const SizedBox(height: 24),
      ],
      _buildAIModelsSection(isGlobal: false),
      const SizedBox(height: 24),
      _buildRemoteShellSection(),
      if (currentProject != null) ...[
        const SizedBox(height: 24),
        _buildDeleteProjectSection(currentProject),
      ],
    ]);
  }

  Widget _buildResponsiveContent(List<Widget> children) {
    final maxWidth =
        Theme.of(
          context,
        ).extension<ShadLayoutTheme>()?.centeredContentMaxWidth ??
        800;

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: children[index],
            ),
          ),
        );
      },
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
      await ref
          .read(projectImporterProvider)
          .importFromQrCode(result, targetProjectId: projectId);

      // Force refresh of the providers to show newly imported settings
      ref.invalidate(projectLlmSettingsProvider(projectId));
      ref.invalidate(projectSshSettingsProvider(projectId));
      ref.invalidate(projectSettingsProvider(projectId));

      if (mounted) _showSnack('Project configured successfully');
    } catch (e) {
      if (mounted) _showSnack('Error configuring project: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  Widget _buildDeleteProjectSection(ProjectEntity project) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danger Zone',
          style: theme.textTheme.h4.copyWith(
            color: theme.colorScheme.destructive,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ShadCard(
            padding: const EdgeInsets.all(16),
            border: ShadBorder.all(color: theme.colorScheme.destructive),
            backgroundColor: theme.colorScheme.destructive.withValues(
              alpha: 0.1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete Project',
                  style: theme.textTheme.large.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Permanently delete "${project.name}" and all associated data.',
                  style: theme.textTheme.muted,
                ),
                const SizedBox(height: 16),
                ShadButton.destructive(
                  onPressed: () => _showDeleteProjectDialog(
                    context: context,
                    ref: ref,
                    projectId: project.id,
                    projectName: project.name,
                    onDeleted: () {
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.trash2, size: 16),
                      SizedBox(width: 8),
                      Text('Delete Project'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectNameSection(ProjectEntity project) {
    final theme = ShadTheme.of(context);
    final controller = TextEditingController(text: project.name);
    final projectsAsync = ref.watch(projectsStreamProvider);

    Future<void> saveChanges(String value) async {
      final trimmedValue = value.trim();

      // Check if empty
      if (trimmedValue.isEmpty) {
        controller.text = project.name;
        if (mounted) {
          _showSnack('Project name cannot be empty');
        }
        return;
      }

      // Check if unchanged
      if (trimmedValue == project.name) {
        return;
      }

      // Check for duplicates
      final projects = projectsAsync.value ?? [];
      final existingNames = projects
          .where((p) => p.id != project.id)
          .map((p) => p.name)
          .toList();

      if (existingNames.contains(trimmedValue)) {
        controller.text = project.name;
        if (mounted) {
          _showSnack('A project with this name already exists');
        }
        return;
      }

      // Save the change
      await ref
          .read(projectControllerProvider)
          .updateProject(id: project.id, name: trimmedValue);
      if (mounted) {
        _showSnack('Project name updated');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Project Name', style: theme.textTheme.h4),
            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
              ShadButton.outline(
                onPressed: () => _scanAndConfigureProject(project.id),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.qrCode, size: 16),
                    SizedBox(width: 8),
                    Text('Scan Config'),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ShadCard(
          padding: const EdgeInsets.all(16),
          child: ShadInput(
            contextMenuBuilder: adaptiveContextMenuBuilder,
            controller: controller,
            placeholder: const Text('Name'),
            autocorrect: false,
            leading: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(LucideIcons.folder, size: 16),
            ),
            onSubmitted: saveChanges,
          ),
        ),
      ],
    );
  }

  Widget _buildAIModelsSection({required bool isGlobal}) {
    final theme = ShadTheme.of(context);

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

    // FIXME: Sloppy and incorrect way to get current default model.
    // It should reuse and follow the same logic as used in the main app.

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('AI Models', style: theme.textTheme.h4),
            ShadButton(
              onPressed: () => _showAddModelDialog(isGlobal: isGlobal),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 16),
                  SizedBox(width: 8),
                  Text('Add Model'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Show message if no project selected in project settings
        if (!isGlobal && ref.watch(currentProjectIdProvider) == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select a project to configure project-specific AI models.',
                    style: theme.textTheme.muted,
                  ),
                ),
              ],
            ),
          )
        else if (llmSettings.isEmpty)
          const EmptyPlaceholder(
            icon: LucideIcons.info,
            title: 'No AI Models',
            subtitle:
                'No AI models configured yet. Click "Add Model" to get started.',
          )
        else
          ...llmSettings.map(
            (settings) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildModelCard(
                settings: settings,
                isGlobal: isGlobal,
                isSelected: settings.identifier == currentDefault,
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
    required bool isSelected,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final theme = ShadTheme.of(context);

    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      _setDefaultModel(settings.identifier, isGlobal: isGlobal),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? LucideIcons.circleDot : LucideIcons.circle,
                        size: 16,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          settings.identifier,
                          style: theme.textTheme.large.copyWith(
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
                      child: ShadBadge.destructive(
                        child: const Text('Disabled'),
                      ),
                    ),
                  ShadButton.ghost(
                    width: 32,
                    height: 32,
                    padding: EdgeInsets.zero,
                    decoration: const ShadDecoration(border: ShadBorder.none),
                    onPressed: onEdit,
                    child: const Icon(LucideIcons.pencil, size: 16),
                  ),
                  ShadButton.ghost(
                    width: 32,
                    height: 32,
                    padding: EdgeInsets.zero,
                    decoration: const ShadDecoration(border: ShadBorder.none),
                    onPressed: onDelete,
                    foregroundColor: theme.colorScheme.destructive,
                    child: const Icon(LucideIcons.trash2, size: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(
              left: 32,
            ), // Align with text after radio
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.link,
                      size: 16,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.baseUrl,
                        style: theme.textTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      LucideIcons.key,
                      size: 16,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '••••••••••${settings.identifier.substring(0, settings.identifier.length > 4 ? 4 : settings.identifier.length)}',
                      style: theme.textTheme.muted.copyWith(
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
    );
  }

  Widget _buildRemoteShellSection() {
    final theme = ShadTheme.of(context);
    final currentProjectId = ref.watch(currentProjectIdProvider);
    final sshSettings = currentProjectId != null
        ? ref.watch(projectSshSettingsProvider(currentProjectId))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Remote Shell', style: theme.textTheme.h4),
            if (currentProjectId != null && sshSettings == null)
              ShadButton(
                onPressed: () =>
                    _showSshSettingsDialog(projectId: currentProjectId),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 16),
                    SizedBox(width: 8),
                    Text('Configure Connection'),
                  ],
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
              border: Border.all(color: theme.colorScheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select a project to configure remote shell connection.',
                    style: theme.textTheme.muted,
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
    final theme = ShadTheme.of(context);
    final sshSettings = ref.watch(projectSshSettingsProvider(projectId));

    if (sshSettings == null) {
      // No SSH configuration yet
      return const Column(
        children: [
          EmptyPlaceholder(
            icon: LucideIcons.terminal,
            title: 'No Remote Shell',
            subtitle: 'No remote shell configured yet.',
          ),
        ],
      );
    }

    // SSH configuration exists
    return ShadCard(
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
                      LucideIcons.terminal,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${sshSettings.username}@${sshSettings.host}',
                        style: theme.textTheme.large.copyWith(
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
                      child: ShadBadge.destructive(
                        child: const Text('Disabled'),
                      ),
                    ),
                  ShadButton.ghost(
                    width: 32,
                    height: 32,
                    padding: EdgeInsets.zero,
                    decoration: const ShadDecoration(border: ShadBorder.none),
                    onPressed: () => _showSshSettingsDialog(
                      projectId: projectId,
                      existingSettings: sshSettings,
                    ),
                    child: const Icon(LucideIcons.pencil, size: 16),
                  ),
                  ShadButton.ghost(
                    width: 32,
                    height: 32,
                    padding: EdgeInsets.zero,
                    decoration: const ShadDecoration(border: ShadBorder.none),
                    onPressed: () =>
                        _showDeleteSshConfirmation(projectId: projectId),
                    foregroundColor: theme.colorScheme.destructive,
                    child: const Icon(LucideIcons.trash2, size: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                LucideIcons.server,
                size: 16,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                '${sshSettings.host}:${sshSettings.port}',
                style: theme.textTheme.muted,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                sshSettings.authMethod == SshAuthMethod.password
                    ? LucideIcons.lock
                    : LucideIcons.key,
                size: 16,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                sshSettings.authMethod == SshAuthMethod.password
                    ? 'Password Authentication'
                    : 'Private Key Authentication',
                style: theme.textTheme.muted,
              ),
            ],
          ),
        ],
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

  void _showDeleteSshConfirmation({required String projectId}) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Delete Remote Shell Configuration'),
        description: const Text(
          'Are you sure you want to delete the remote shell configuration? This will also delete all associated credentials.',
        ),
        actions: [
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ShadButton.destructive(
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(projectSshSettingsProvider(projectId).notifier)
            .deleteSshSettings();

        if (mounted) {
          ShadToaster.of(context).show(
            const ShadToast(
              description: Text('Remote shell configuration deleted'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ShadToaster.of(context).show(
            ShadToast(
              description: Text('Error deleting configuration: $e'),
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

  Widget _buildThemeSection() {
    final theme = ShadTheme.of(context);
    final currentThemeMode = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme', style: theme.textTheme.h4),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildThemeCard(
                title: 'Light',
                icon: LucideIcons.sun,
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
                icon: LucideIcons.moon,
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
                icon: LucideIcons.monitor,
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
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ShadCard(
        padding: const EdgeInsets.all(16),
        border: isSelected
            ? ShadBorder.all(color: theme.colorScheme.primary, width: 2)
            : null,
        backgroundColor: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.p.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setDefaultModel(
    String identifier, {
    required bool isGlobal,
  }) async {
    try {
      if (isGlobal) {
        await ref
            .read(globalLlmSettingsProvider.notifier)
            .setDefaultLlm(identifier);
      } else {
        final currentProjectId = ref.read(currentProjectIdProvider);
        if (currentProjectId != null) {
          await ref
              .read(projectLlmSettingsProvider(currentProjectId).notifier)
              .setDefaultLlm(identifier);
        }
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error setting default model: $e'),
            action: ShadButton.destructive(
              child: const Text('Dismiss'),
              onPressed: () => ShadToaster.of(context).hide(),
            ),
          ),
        );
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
    showShadDialog(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('Delete AI Model'),
        description: Text(
          'Are you sure you want to delete "${settings.identifier}"?',
        ),
        actions: [
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          ShadButton.destructive(
            child: const Text('Delete'),
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

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ShadToaster.of(dialogContext).show(
                    ShadToast(
                      description: Text(
                        'Deleted model: ${settings.identifier}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ShadToaster.of(dialogContext).show(
                    ShadToast(
                      description: Text('Error deleting model: $e'),
                      action: ShadButton.destructive(
                        child: const Text('Dismiss'),
                        onPressed: () => ShadToaster.of(dialogContext).hide(),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServerUrlSection(ProjectEntity project) {
    final theme = ShadTheme.of(context);
    final connectionInfoAsync = ref.watch(
      projectConnectionInfoProvider(project.id),
    );
    final tunnelId = connectionInfoAsync.whenOrNull(
      data: (info) {
        if (info != null && info['type'] == 'tunnel') {
          return info['tunnelId'] as String?;
        }
        return null;
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SSH Tunnel', style: theme.textTheme.h4),
            if (tunnelId == null)
              ShadButton(
                onPressed: () => _showTunnelDialog(project: project),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 16),
                    SizedBox(width: 8),
                    Text('Configure Tunnel'),
                  ],
                ),
              ),
          ],
        ),
        if (project.serverNodeId != null) ...[
          const SizedBox(height: 4),
          Text(
            'Server: ${project.serverNodeId}',
            style: theme.textTheme.muted.copyWith(fontSize: 11),
          ),
        ],
        const SizedBox(height: 16),
        _buildTunnelCard(project, tunnelId),
      ],
    );
  }

  Widget _buildTunnelCard(ProjectEntity project, String? tunnelId) {
    final theme = ShadTheme.of(context);

    if (tunnelId == null) {
      return const EmptyPlaceholder(
        icon: LucideIcons.network,
        title: 'No SSH Tunnel',
        subtitle: 'Configure an SSH tunnel to connect to a remote agent.',
      );
    }

    final tunnelConfigs = ref.watch(sshTunnelConfigsProvider);
    final settings = tunnelConfigs.whenOrNull(
      data: (configs) => configs[tunnelId],
    );

    if (settings == null) {
      return ShadCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              LucideIcons.circleAlert,
              color: theme.colorScheme.destructive,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tunnel configuration not found. It may have been deleted.',
                style: theme.textTheme.muted,
              ),
            ),
            ShadButton.ghost(
              width: 32,
              height: 32,
              padding: EdgeInsets.zero,
              onPressed: () => _removeTunnel(project),
              foregroundColor: theme.colorScheme.destructive,
              child: const Icon(LucideIcons.trash2, size: 16),
            ),
          ],
        ),
      );
    }

    return ShadCard(
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
                      LucideIcons.network,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${settings.username}@${settings.host}',
                        style: theme.textTheme.large.copyWith(
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
                  ShadButton.ghost(
                    width: 32,
                    height: 32,
                    padding: EdgeInsets.zero,
                    decoration: const ShadDecoration(border: ShadBorder.none),
                    onPressed: () => _showTunnelDialog(
                      project: project,
                      existingTunnelId: tunnelId,
                    ),
                    child: const Icon(LucideIcons.pencil, size: 16),
                  ),
                  ShadButton.ghost(
                    width: 32,
                    height: 32,
                    padding: EdgeInsets.zero,
                    decoration: const ShadDecoration(border: ShadBorder.none),
                    onPressed: () => _removeTunnel(project),
                    foregroundColor: theme.colorScheme.destructive,
                    child: const Icon(LucideIcons.trash2, size: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                LucideIcons.server,
                size: 16,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                '${settings.host}:${settings.port}',
                style: theme.textTheme.muted,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                LucideIcons.key,
                size: 16,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text('Private Key Authentication', style: theme.textTheme.muted),
            ],
          ),
        ],
      ),
    );
  }

  void _showTunnelDialog({
    required ProjectEntity project,
    String? existingTunnelId,
  }) {
    SshSettingsDialog.showTunnel(
      context,
      ref,
      existingTunnelId: existingTunnelId,
      onSaved: (tunnelId) async {
        final mappingStorage = ref.read(connectionMappingStorageProvider);
        await mappingStorage.save(project.id, {
          'type': 'tunnel',
          'tunnelId': tunnelId,
        });
        ref.invalidate(projectConnectionInfoProvider(project.id));
        if (mounted) _showSnack('SSH tunnel configured');
      },
    );
  }

  Future<void> _removeTunnel(ProjectEntity project) async {
    final mappingStorage = ref.read(connectionMappingStorageProvider);
    await mappingStorage.delete(project.id);
    ref.invalidate(projectConnectionInfoProvider(project.id));
    if (mounted) _showSnack('SSH tunnel removed');
  }

  Future<void> _showDeleteProjectDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String projectId,
    required String projectName,
    required VoidCallback onDeleted,
  }) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Delete Project'),
        description: Text(
          'Are you sure you want to delete "$projectName"? This cannot be undone.',
        ),
        actions: [
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ShadButton.destructive(
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(projectControllerProvider).deleteProject(projectId);
      onDeleted();
    }
  }
}
