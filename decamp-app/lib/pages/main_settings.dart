import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/project_provider.dart';
import '../providers/llm_settings_provider.dart';
import '../models/llm_api_settings.dart';
import '../utils/text_pattern_matcher.dart';
import 'ocr_scanner_page.dart';

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
        _buildProjectSelector(),
        const SizedBox(height: 24),
        _buildAIModelsSection(isGlobal: false),
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
                    settings.identifier,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
                    settings.baseUrl,
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
                  '••••••••••${settings.identifier.substring(0, settings.identifier.length > 4 ? 4 : settings.identifier.length)}',
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

  void _showAddModelDialog({required bool isGlobal}) {
    showDialog(
      context: context,
      builder: (context) => _AIModelDialog(
        title: 'Add AI Model',
        isGlobal: isGlobal,
        onSave:
            (
              identifier,
              url,
              apiKey, {
              customHeaders,
              maxTokens,
              temperature,
              enabled,
            }) async {
              try {
                if (isGlobal) {
                  await ref
                      .read(globalLlmSettingsProvider.notifier)
                      .addLlmSettings(
                        identifier: identifier,
                        baseUrl: url,
                        apiKey: apiKey,
                        customHeaders: customHeaders,
                        maxTokens: maxTokens,
                        temperature: temperature,
                      );
                } else {
                  final projectId = ref.read(currentProjectIdProvider);
                  if (projectId != null) {
                    await ref
                        .read(projectLlmSettingsProvider(projectId).notifier)
                        .addLlmSettings(
                          identifier: identifier,
                          baseUrl: url,
                          apiKey: apiKey,
                          customHeaders: customHeaders,
                          maxTokens: maxTokens,
                          temperature: temperature,
                        );
                  }
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added model: $identifier')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding model: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
      ),
    );
  }

  void _showEditModelDialog({
    required LlmApiSettings settings,
    required bool isGlobal,
  }) async {
    // Fetch the API key from keychain
    String? apiKey;
    if (isGlobal) {
      apiKey = await ref
          .read(globalLlmSettingsProvider.notifier)
          .getApiKey(settings.identifier);
    } else {
      final projectId = ref.read(currentProjectIdProvider);
      if (projectId != null) {
        apiKey = await ref
            .read(projectLlmSettingsProvider(projectId).notifier)
            .getApiKey(settings.identifier);
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _AIModelDialog(
        title: 'Edit AI Model',
        isGlobal: isGlobal,
        initialIdentifier: settings.identifier,
        initialUrl: settings.baseUrl,
        initialApiKey: apiKey ?? '',
        initialEnabled: settings.enabled,
        onSave:
            (
              identifier,
              url,
              apiKey, {
              customHeaders,
              maxTokens,
              temperature,
              enabled,
            }) async {
              try {
                if (isGlobal) {
                  await ref
                      .read(globalLlmSettingsProvider.notifier)
                      .updateLlmSettings(
                        identifier: identifier,
                        baseUrl: url,
                        apiKey: apiKey.isNotEmpty ? apiKey : null,
                        customHeaders: customHeaders,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        enabled: enabled,
                      );
                } else {
                  final projectId = ref.read(currentProjectIdProvider);
                  if (projectId != null) {
                    await ref
                        .read(projectLlmSettingsProvider(projectId).notifier)
                        .updateLlmSettings(
                          identifier: identifier,
                          baseUrl: url,
                          apiKey: apiKey.isNotEmpty ? apiKey : null,
                          customHeaders: customHeaders,
                          maxTokens: maxTokens,
                          temperature: temperature,
                          enabled: enabled,
                        );
                  }
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated model: $identifier')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating model: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
      ),
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

/// Dialog for adding/editing AI models
class _AIModelDialog extends StatefulWidget {
  final String title;
  final bool isGlobal;
  final String? initialIdentifier;
  final String? initialUrl;
  final String? initialApiKey;
  final bool? initialEnabled;
  final Function(
    String identifier,
    String url,
    String apiKey, {
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool? enabled,
  })
  onSave;

  const _AIModelDialog({
    required this.title,
    required this.isGlobal,
    required this.onSave,
    this.initialIdentifier,
    this.initialUrl,
    this.initialApiKey,
    this.initialEnabled,
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
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: widget.initialIdentifier,
    );
    _urlController = TextEditingController(text: widget.initialUrl);
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
    _enabled = widget.initialEnabled ?? true;
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
                enabled: widget.initialIdentifier == null,
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
                decoration: InputDecoration(
                  labelText: 'API URL',
                  hintText: 'https://api.example.com/v1',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _scanUrl,
                    tooltip: 'Scan URL with camera',
                  ),
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
                  hintText: widget.initialApiKey != null
                      ? 'Leave blank to keep current key'
                      : 'Enter your API key',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _scanApiKey,
                        tooltip: 'Scan API key with camera',
                      ),
                      IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureApiKey = !_obscureApiKey;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                obscureText: _obscureApiKey,
                validator: (value) {
                  // API key is required for new models but optional for edits
                  if (widget.initialApiKey == null &&
                      (value == null || value.isEmpty)) {
                    return 'Please enter an API key';
                  }
                  return null;
                },
              ),
              if (widget.initialIdentifier != null) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enabled'),
                  subtitle: const Text('Allow this model to be used'),
                  value: _enabled,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
              ],
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
        enabled: widget.initialIdentifier != null ? _enabled : null,
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _scanApiKey() async {
    final scannedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const OcrScannerPage(scanType: ScanType.apiKey),
      ),
    );

    if (scannedText != null && mounted) {
      setState(() {
        _apiKeyController.text = scannedText;
      });
    }
  }

  Future<void> _scanUrl() async {
    final scannedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const OcrScannerPage(scanType: ScanType.url),
      ),
    );

    if (scannedText != null && mounted) {
      setState(() {
        _urlController.text = scannedText;
      });
    }
  }
}
