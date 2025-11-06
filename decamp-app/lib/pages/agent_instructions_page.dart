import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/agent_instruction.dart';
import '../models/llm_api_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/llm_settings_provider.dart';
import '../providers/project_provider.dart';

/// Agent Instructions page with User and Project settings tabs
class AgentInstructionsPage extends ConsumerStatefulWidget {
  const AgentInstructionsPage({super.key});

  @override
  ConsumerState<AgentInstructionsPage> createState() =>
      _AgentInstructionsPageState();
}

class _AgentInstructionsPageState extends ConsumerState<AgentInstructionsPage>
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
        title: const Text('Agent Instructions'),
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
              tabs: const [
                Tab(text: 'User Settings'),
                Tab(text: 'Project Settings'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_UserSettingsTab(), _ProjectSettingsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// User Settings Tab - Global/User-level agent instructions
class _UserSettingsTab extends ConsumerStatefulWidget {
  const _UserSettingsTab();

  @override
  ConsumerState<_UserSettingsTab> createState() => _UserSettingsTabState();
}

class _UserSettingsTabState extends ConsumerState<_UserSettingsTab> {
  late TextEditingController _defaultController;
  final Map<String, TextEditingController> _modelControllers = {};
  bool _showPreview = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _defaultController = TextEditingController();
  }

  @override
  void dispose() {
    _defaultController.dispose();
    for (var controller in _modelControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadSettings() {
    final settings = ref.read(globalSettingsProvider);
    final instruction = settings.agentInstruction;

    _defaultController.text = instruction?.defaultInstruction ?? '';

    // Clear and rebuild model controllers
    for (var controller in _modelControllers.values) {
      controller.dispose();
    }
    _modelControllers.clear();

    if (instruction != null) {
      for (var entry in instruction.modelOverrides.entries) {
        _modelControllers[entry.key] = TextEditingController(text: entry.value);
      }
    }
    _hasChanges = false;
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveSettings() async {
    final settings = ref.read(globalSettingsProvider);
    final settingsNotifier = ref.read(globalSettingsProvider.notifier);

    final modelOverrides = <String, String>{};
    for (var entry in _modelControllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        modelOverrides[entry.key] = entry.value.text;
      }
    }

    final now = DateTime.now();
    final newInstruction = AgentInstruction(
      defaultInstruction: _defaultController.text,
      modelOverrides: modelOverrides,
      createdAt: settings.agentInstruction?.createdAt ?? now,
      updatedAt: now,
    );

    await settingsNotifier.updateSettings(
      settings.copyWith(agentInstruction: newInstruction, updatedAt: now),
    );

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User-level instructions saved')),
      );
    }
  }

  void _addModelOverride(String modelIdentifier) {
    if (!_modelControllers.containsKey(modelIdentifier)) {
      setState(() {
        _modelControllers[modelIdentifier] = TextEditingController();
        _hasChanges = true;
      });
    }
  }

  void _removeModelOverride(String modelIdentifier) {
    setState(() {
      _modelControllers[modelIdentifier]?.dispose();
      _modelControllers.remove(modelIdentifier);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(globalSettingsProvider);
    final llmSettings = ref.watch(globalLlmSettingsProvider);

    // Load settings when they change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defaultController.text.isEmpty &&
          settings.agentInstruction != null) {
        _loadSettings();
      }
    });

    return Column(
      children: [
        // Preview/Edit toggle and Save button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Configure default instructions for all AI models',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              IconButton(
                icon: Icon(_showPreview ? Icons.edit : Icons.preview),
                tooltip: _showPreview ? 'Edit' : 'Preview',
                onPressed: () => setState(() => _showPreview = !_showPreview),
              ),
              ElevatedButton.icon(
                onPressed: _hasChanges ? _saveSettings : null,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Default Instruction Section
              _InstructionSection(
                title: 'Default Instruction',
                subtitle: 'Applies to all models unless overridden',
                controller: _defaultController,
                showPreview: _showPreview,
                onChanged: _markChanged,
              ),
              const SizedBox(height: 24),

              // Model-Specific Overrides
              Card(
                child: ExpansionTile(
                  title: const Text('Model-Specific Overrides'),
                  subtitle: Text(
                    _modelControllers.isEmpty
                        ? 'No overrides configured'
                        : '${_modelControllers.length} override(s) configured',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // List existing overrides
                          ..._modelControllers.entries.map((entry) {
                            return _ModelOverrideSection(
                              modelIdentifier: entry.key,
                              controller: entry.value,
                              showPreview: _showPreview,
                              onChanged: _markChanged,
                              onRemove: () => _removeModelOverride(entry.key),
                            );
                          }),

                          // Add new override button
                          const SizedBox(height: 16),
                          _AddModelOverrideButton(
                            existingIdentifiers: _modelControllers.keys.toSet(),
                            availableLlms: llmSettings,
                            onAdd: _addModelOverride,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Project Settings Tab - Project-level agent instructions
class _ProjectSettingsTab extends ConsumerStatefulWidget {
  const _ProjectSettingsTab();

  @override
  ConsumerState<_ProjectSettingsTab> createState() =>
      _ProjectSettingsTabState();
}

class _ProjectSettingsTabState extends ConsumerState<_ProjectSettingsTab> {
  late TextEditingController _defaultController;
  final Map<String, TextEditingController> _modelControllers = {};
  bool _showPreview = false;
  bool _hasChanges = false;
  bool _includeUserInstructions = false;

  @override
  void initState() {
    super.initState();
    _defaultController = TextEditingController();
  }

  @override
  void dispose() {
    _defaultController.dispose();
    for (var controller in _modelControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadSettings(String projectId) {
    final settings = ref.read(projectSettingsProvider(projectId));
    final instruction = settings?.agentInstruction;

    _defaultController.text = instruction?.defaultInstruction ?? '';
    _includeUserInstructions = settings?.includeUserInstructions ?? false;

    // Clear and rebuild model controllers
    for (var controller in _modelControllers.values) {
      controller.dispose();
    }
    _modelControllers.clear();

    if (instruction != null) {
      for (var entry in instruction.modelOverrides.entries) {
        _modelControllers[entry.key] = TextEditingController(text: entry.value);
      }
    }
    _hasChanges = false;
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveSettings(String projectId) async {
    final settings = ref.read(projectSettingsProvider(projectId));
    final settingsNotifier = ref.read(
      projectSettingsProvider(projectId).notifier,
    );

    if (settings == null) return;

    final modelOverrides = <String, String>{};
    for (var entry in _modelControllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        modelOverrides[entry.key] = entry.value.text;
      }
    }

    final now = DateTime.now();
    final newInstruction = AgentInstruction(
      defaultInstruction: _defaultController.text,
      modelOverrides: modelOverrides,
      createdAt: settings.agentInstruction?.createdAt ?? now,
      updatedAt: now,
    );

    await settingsNotifier.updateSettings(
      settings.copyWith(
        agentInstruction: newInstruction,
        includeUserInstructions: _includeUserInstructions,
        updatedAt: now,
      ),
    );

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project-level instructions saved')),
      );
    }
  }

  void _addModelOverride(String modelIdentifier) {
    if (!_modelControllers.containsKey(modelIdentifier)) {
      setState(() {
        _modelControllers[modelIdentifier] = TextEditingController();
        _hasChanges = true;
      });
    }
  }

  void _removeModelOverride(String modelIdentifier) {
    setState(() {
      _modelControllers[modelIdentifier]?.dispose();
      _modelControllers.remove(modelIdentifier);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentProject = ref.watch(currentProjectProvider);

    if (currentProject == null) {
      return const Center(
        child: Text('No project selected. Please select a project first.'),
      );
    }

    final projectId = currentProject.id;
    final settings = ref.watch(projectSettingsProvider(projectId));
    final llmSettings = ref.watch(projectLlmSettingsProvider(projectId));

    // Load settings when they change (only if we haven't loaded yet or don't have unsaved changes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defaultController.text.isEmpty &&
          settings?.agentInstruction != null) {
        _loadSettings(projectId);
      }
    });

    return Column(
      children: [
        // Preview/Edit toggle and Save button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Configure project-specific instructions',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              IconButton(
                icon: Icon(_showPreview ? Icons.edit : Icons.preview),
                tooltip: _showPreview ? 'Edit' : 'Preview',
                onPressed: () => setState(() => _showPreview = !_showPreview),
              ),
              ElevatedButton.icon(
                onPressed: _hasChanges ? () => _saveSettings(projectId) : null,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Include User Instructions Checkbox
              CheckboxListTile(
                title: const Text('Include User-Level Instructions'),
                subtitle: const Text(
                  'Prepend user-level instructions to project instructions',
                ),
                value: _includeUserInstructions,
                onChanged: (value) {
                  setState(() {
                    _includeUserInstructions = value ?? false;
                    _hasChanges = true;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Default Instruction Section
              _InstructionSection(
                title: 'Default Project Instruction',
                subtitle:
                    'Applies to all models in this project unless overridden',
                controller: _defaultController,
                showPreview: _showPreview,
                onChanged: _markChanged,
              ),
              const SizedBox(height: 24),

              // Model-Specific Overrides
              Card(
                child: ExpansionTile(
                  title: const Text('Model-Specific Overrides'),
                  subtitle: Text(
                    _modelControllers.isEmpty
                        ? 'No overrides configured'
                        : '${_modelControllers.length} override(s) configured',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // List existing overrides
                          ..._modelControllers.entries.map((entry) {
                            return _ModelOverrideSection(
                              modelIdentifier: entry.key,
                              controller: entry.value,
                              showPreview: _showPreview,
                              onChanged: _markChanged,
                              onRemove: () => _removeModelOverride(entry.key),
                            );
                          }),

                          // Add new override button
                          const SizedBox(height: 16),
                          _AddModelOverrideButton(
                            existingIdentifiers: _modelControllers.keys.toSet(),
                            availableLlms: llmSettings,
                            onAdd: _addModelOverride,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget for displaying and editing an instruction section
class _InstructionSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final bool showPreview;
  final VoidCallback onChanged;

  const _InstructionSection({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.showPreview,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        if (showPreview)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(minHeight: 200),
            child: controller.text.isEmpty
                ? Text(
                    'No instruction provided',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  )
                : MarkdownBody(data: controller.text),
          )
        else
          TextField(
            controller: controller,
            maxLines: null,
            minLines: 8,
            decoration: InputDecoration(
              hintText: 'Enter instruction in markdown format...',
              border: const OutlineInputBorder(),
              helperText: 'Supports markdown formatting',
            ),
            onChanged: (_) => onChanged(),
          ),
      ],
    );
  }
}

/// Widget for a model-specific override section
class _ModelOverrideSection extends StatelessWidget {
  final String modelIdentifier;
  final TextEditingController controller;
  final bool showPreview;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ModelOverrideSection({
    required this.modelIdentifier,
    required this.controller,
    required this.showPreview,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    modelIdentifier,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove override',
                  onPressed: onRemove,
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showPreview)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(minHeight: 150),
                child: controller.text.isEmpty
                    ? Text(
                        'No override instruction provided',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      )
                    : MarkdownBody(data: controller.text),
              )
            else
              TextField(
                controller: controller,
                maxLines: null,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter model-specific instruction...',
                  border: OutlineInputBorder(),
                  helperText: 'Supports markdown formatting',
                ),
                onChanged: (_) => onChanged(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Button to add a new model override
class _AddModelOverrideButton extends StatelessWidget {
  final Set<String> existingIdentifiers;
  final List<LlmApiSettings> availableLlms;
  final Function(String) onAdd;

  const _AddModelOverrideButton({
    required this.existingIdentifiers,
    required this.availableLlms,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showAddDialog(context),
      icon: const Icon(Icons.add),
      label: const Text('Add Model Override'),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final availableModels = availableLlms
        .where((llm) => !existingIdentifiers.contains(llm.identifier))
        .toList();

    if (availableModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All configured models already have overrides'),
        ),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableModels.map((llm) {
            return ListTile(
              title: Text(llm.identifier),
              subtitle: Text(llm.apiType.name),
              onTap: () => Navigator.of(context).pop(llm.identifier),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      onAdd(result);
    }
  }
}
