import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/project_provider.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Settings'),
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
        _buildAIModelsSection(),
        const SizedBox(height: 24),
        _buildThemeSection(),
      ],
    );
  }

  Widget _buildProjectSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProjectSelector(),
        const SizedBox(height: 24),
        _buildAIModelsSection(),
        const SizedBox(height: 24),
        _buildThemeSection(),
      ],
    );
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

                return DropdownButtonFormField<String>(
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
                      ref.read(currentProjectIdProvider.notifier).state = value;
                    }
                  },
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

  Widget _buildAIModelsSection() {
    final theme = Theme.of(context);

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
              onPressed: _showAddModelDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Model'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Placeholder model cards
        _buildModelCard(
          name: 'GPT-4 Turbo',
          url: 'https://api.openai.com/v1',
          apiKeyMasked: '••••••••••sk-1234',
          onEdit: () => _showEditModelDialog('GPT-4 Turbo'),
          onDelete: () => _showDeleteConfirmation('GPT-4 Turbo'),
        ),
        const SizedBox(height: 12),
        _buildModelCard(
          name: 'Claude 3.5 Sonnet',
          url: 'https://api.anthropic.com',
          apiKeyMasked: '••••••••••sk-ant-5678',
          onEdit: () => _showEditModelDialog('Claude 3.5 Sonnet'),
          onDelete: () => _showDeleteConfirmation('Claude 3.5 Sonnet'),
        ),
      ],
    );
  }

  Widget _buildModelCard({
    required String name,
    required String url,
    required String apiKeyMasked,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);

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
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
            Row(
              children: [
                Icon(
                  Icons.link,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    url,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  apiKeyMasked,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
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

  void _showAddModelDialog() {
    showDialog(
      context: context,
      builder: (context) => _AIModelDialog(
        title: 'Add AI Model',
        onSave: (identifier, url, apiKey) {
          // TODO: Save to provider
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Added model: $identifier')));
        },
      ),
    );
  }

  void _showEditModelDialog(String modelName) {
    showDialog(
      context: context,
      builder: (context) => _AIModelDialog(
        title: 'Edit AI Model',
        initialIdentifier: modelName,
        initialUrl: 'https://api.openai.com/v1',
        initialApiKey: 'sk-placeholder',
        onSave: (identifier, url, apiKey) {
          // TODO: Update in provider
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Updated model: $identifier')));
        },
      ),
    );
  }

  void _showDeleteConfirmation(String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete AI Model'),
        content: Text('Are you sure you want to delete "$modelName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Delete from provider
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted model: $modelName')),
              );
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

/// Dialog for adding/editing AI models
class _AIModelDialog extends StatefulWidget {
  final String title;
  final String? initialIdentifier;
  final String? initialUrl;
  final String? initialApiKey;
  final Function(String identifier, String url, String apiKey) onSave;

  const _AIModelDialog({
    required this.title,
    required this.onSave,
    this.initialIdentifier,
    this.initialUrl,
    this.initialApiKey,
  });

  @override
  State<_AIModelDialog> createState() => _AIModelDialogState();
}

class _AIModelDialogState extends State<_AIModelDialog> {
  late final TextEditingController _identifierController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  final _formKey = GlobalKey<FormState>();
  bool _obscureApiKey = true;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: widget.initialIdentifier,
    );
    _urlController = TextEditingController(text: widget.initialUrl);
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: 'Model Identifier',
                  hintText: 'e.g., gpt-4-turbo, claude-3-5-sonnet',
                  prefixIcon: Icon(Icons.info),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a model identifier';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'API URL',
                  hintText: 'https://api.example.com/v1',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an API URL';
                  }
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return 'URL must start with http:// or https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Enter your API key',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                ),
                obscureText: _obscureApiKey,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an API key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: Text(
                    _isTestingConnection ? 'Testing...' : 'Test Connection',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    // TODO: Implement actual connection test
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection test successful! (Placeholder)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        _identifierController.text,
        _urlController.text,
        _apiKeyController.text,
      );
      Navigator.of(context).pop();
    }
  }
}
