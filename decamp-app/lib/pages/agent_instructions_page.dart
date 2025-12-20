import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/settings_provider.dart';
import '../providers/llm_settings_provider.dart';
import '../providers/llm_service_provider.dart';
import '../providers/project_provider.dart';
import '../components/project_title_bar.dart';

/// Agent Instructions page with User and Project settings tabs
class AgentInstructionsPage extends ConsumerStatefulWidget {
  const AgentInstructionsPage({super.key});

  @override
  ConsumerState<AgentInstructionsPage> createState() =>
      _AgentInstructionsPageState();
}

class _AgentInstructionsPageState extends ConsumerState<AgentInstructionsPage> {
  String _currentTab = 'project';

  @override
  Widget build(BuildContext context) {
    final currentProject = ref.watch(currentProjectProvider);
    final theme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const ProjectTitleBar(title: 'Agent Instructions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: theme.radius,
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _currentTab == 'user'
                        ? ShadButton(
                            shadows: [
                              BoxShadow(
                                color: theme.colorScheme.background.withValues(
                                  alpha: 0.1,
                                ),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                            backgroundColor: theme.colorScheme.background,
                            foregroundColor: theme.colorScheme.foreground,
                            hoverBackgroundColor: theme.colorScheme.background,
                            onPressed: () {},
                            child: const Text('User Settings'),
                          )
                        : ShadButton.ghost(
                            onPressed: () =>
                                setState(() => _currentTab = 'user'),
                            child: const Text('User Settings'),
                          ),
                  ),
                  Expanded(
                    child: _currentTab == 'project'
                        ? ShadButton(
                            shadows: [
                              BoxShadow(
                                color: theme.colorScheme.background.withValues(
                                  alpha: 0.1,
                                ),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                            backgroundColor: theme.colorScheme.background,
                            foregroundColor: theme.colorScheme.foreground,
                            hoverBackgroundColor: theme.colorScheme.background,
                            onPressed: () {},
                            child: const Text('Project Settings'),
                          )
                        : ShadButton.ghost(
                            onPressed: () =>
                                setState(() => _currentTab = 'project'),
                            child: const Text('Project Settings'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: IndexedStack(
                index: _currentTab == 'user' ? 0 : 1,
                children: [
                  const _UserSettingsTab(),
                  currentProject != null
                      ? _ProjectSettingsTab(
                          projectId: currentProject.id,
                          key: ValueKey(currentProject.id),
                        )
                      : const Center(
                          child: Text(
                            'No project selected. Please select a project first.',
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
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
    try {
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
        ShadToaster.of(context).show(
          const ShadToast(description: Text('User-level instructions saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text('Error saving instructions: $e'),
          ),
        );
      }
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
                  style: ShadTheme.of(context).textTheme.muted,
                ),
              ),
              ShadIconButton.ghost(
                icon: Icon(_showPreview ? LucideIcons.pencil : LucideIcons.eye),
                onPressed: () => setState(() => _showPreview = !_showPreview),
              ),
              ShadButton(
                onPressed: _hasChanges ? _saveSettings : null,
                leading: const Icon(LucideIcons.save),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
        const ShadSeparator.horizontal(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Template variables info
              const _TemplateVariablesInfo(),
              const SizedBox(height: 16),

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
              ShadAccordion<String>.multiple(
                children: [
                  ShadAccordionItem(
                    value: 'overrides',
                    title: const Text('Model-Specific Overrides'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_modelControllers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              'No overrides configured',
                              style: ShadTheme.of(context).textTheme.muted,
                            ),
                          )
                        else
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
            ],
          ),
        ),
      ],
    );
  }
}

/// Project Settings Tab - Project-level agent instructions
class _ProjectSettingsTab extends ConsumerStatefulWidget {
  final String projectId;

  const _ProjectSettingsTab({required this.projectId, super.key});

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
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _defaultController = TextEditingController();

    // Try to load settings immediately if available
    final settings = ref.read(projectSettingsProvider(widget.projectId));
    if (settings != null) {
      _loadSettings(settings);
      _settingsLoaded = true;
    }
  }

  @override
  void dispose() {
    _defaultController.dispose();
    for (var controller in _modelControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadSettings(ProjectSettings settings) {
    final instruction = settings.agentInstruction;

    _defaultController.text = instruction?.defaultInstruction ?? '';
    _includeUserInstructions = settings.includeUserInstructions;

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
    try {
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
        ShadToaster.of(context).show(
          const ShadToast(
            description: Text('Project-level instructions saved'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text('Error saving project instructions: $e'),
          ),
        );
      }
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
    final projectId = widget.projectId;
    final llmSettings = ref.watch(projectLlmSettingsProvider(projectId));

    // Listen for settings updates (e.g. when they finish loading)
    ref.listen<ProjectSettings?>(projectSettingsProvider(projectId), (
      previous,
      next,
    ) {
      if (!_settingsLoaded && next != null) {
        _loadSettings(next);
        setState(() => _settingsLoaded = true);
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
                  style: ShadTheme.of(context).textTheme.muted,
                ),
              ),
              ShadIconButton.ghost(
                icon: Icon(_showPreview ? LucideIcons.pencil : LucideIcons.eye),
                onPressed: () => setState(() => _showPreview = !_showPreview),
              ),
              ShadButton(
                onPressed: _hasChanges ? () => _saveSettings(projectId) : null,
                leading: const Icon(LucideIcons.save),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
        const ShadSeparator.horizontal(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Include User Instructions Checkbox
              ShadCheckbox(
                value: _includeUserInstructions,
                onChanged: (value) {
                  setState(() {
                    _includeUserInstructions = value;
                    _hasChanges = true;
                  });
                },
                label: const Text('Include User-Level Instructions'),
                sublabel: const Text(
                  'Prepend user-level instructions to project instructions',
                ),
              ),
              const SizedBox(height: 16),

              // Template variables info
              const _TemplateVariablesInfo(),
              const SizedBox(height: 16),

              // Default Project Instruction Section
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
              ShadAccordion<String>.multiple(
                children: [
                  ShadAccordionItem(
                    value: 'overrides',
                    title: const Text('Model-Specific Overrides'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_modelControllers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              'No overrides configured',
                              style: ShadTheme.of(context).textTheme.muted,
                            ),
                          )
                        else
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
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget for displaying and editing an instruction section
class _InstructionSection extends ConsumerStatefulWidget {
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
  ConsumerState<_InstructionSection> createState() =>
      _InstructionSectionState();
}

class _InstructionSectionState extends ConsumerState<_InstructionSection> {
  bool _renderJinja = false;
  String? _processedText;
  bool _isLoading = false;

  Future<void> _loadContext() async {
    if (_processedText != null) return;

    setState(() => _isLoading = true);

    try {
      final llmService = ref.read(llmServiceProvider);
      final processed = await llmService.processTemplate(
        widget.controller.text,
      );

      if (mounted) {
        setState(() {
          _processedText = processed;
        });
      }
    } catch (e) {
      debugPrint('Error loading preview context: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: theme.textTheme.h4),
        const SizedBox(height: 4),
        Text(widget.subtitle, style: theme.textTheme.muted),
        const SizedBox(height: 12),
        if (widget.showPreview) ...[
          Row(
            children: [
              ShadCheckbox(
                value: _renderJinja,
                onChanged: (value) {
                  setState(() {
                    _renderJinja = value;
                    if (!_renderJinja) {
                      _processedText = null;
                    }
                  });
                  if (_renderJinja) {
                    _loadContext();
                  }
                },
                label: const Text('Render Jinja in preview'),
              ),
              if (_isLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.border),
              borderRadius: theme.radius,
            ),
            constraints: const BoxConstraints(minHeight: 200),
            child: widget.controller.text.isEmpty
                ? Text(
                    'No instruction provided',
                    style: theme.textTheme.muted.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : SelectionArea(
                    child: GptMarkdown(
                      _renderJinja
                          ? (_processedText ?? widget.controller.text)
                          : widget.controller.text,
                    ),
                  ),
          ),
        ] else
          ShadTextarea(
            controller: widget.controller,
            placeholder: const Text('Enter instruction in markdown format...'),
            onChanged: (_) {
              if (_processedText != null) {
                setState(() => _processedText = null);
                if (_renderJinja) {
                  _loadContext();
                }
              }
              widget.onChanged();
            },
          ),
      ],
    );
  }
}

/// Widget for a model-specific override section
class _ModelOverrideSection extends ConsumerStatefulWidget {
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
  ConsumerState<_ModelOverrideSection> createState() =>
      _ModelOverrideSectionState();
}

class _ModelOverrideSectionState extends ConsumerState<_ModelOverrideSection> {
  bool _renderJinja = false;
  String? _processedText;
  bool _isLoading = false;

  Future<void> _loadContext() async {
    if (_processedText != null) return;

    setState(() => _isLoading = true);

    try {
      final llmService = ref.read(llmServiceProvider);
      final processed = await llmService.processTemplate(
        widget.controller.text,
      );

      if (mounted) {
        setState(() {
          _processedText = processed;
        });
      }
    } catch (e) {
      debugPrint('Error loading preview context: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.modelIdentifier,
                  style: theme.textTheme.large,
                ),
              ),
              ShadIconButton.destructive(
                icon: const Icon(LucideIcons.trash),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.showPreview) ...[
            Row(
              children: [
                ShadCheckbox(
                  value: _renderJinja,
                  onChanged: (value) {
                    setState(() {
                      _renderJinja = value;
                      // Reset processed text when toggling off so we re-fetch if toggled on again
                      // or if text changed (though we don't track text changes here easily without listener)
                      if (!_renderJinja) {
                        _processedText = null;
                      }
                    });
                    if (_renderJinja) {
                      _loadContext();
                    }
                  },
                  label: const Text('Render Jinja in preview'),
                ),
                if (_isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.border),
                borderRadius: theme.radius,
              ),
              constraints: const BoxConstraints(minHeight: 150),
              child: widget.controller.text.isEmpty
                  ? Text(
                      'No override instruction provided',
                      style: theme.textTheme.muted.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : SelectionArea(
                      child: GptMarkdown(
                        _renderJinja
                            ? (_processedText ?? widget.controller.text)
                            : widget.controller.text,
                      ),
                    ),
            ),
          ] else
            ShadTextarea(
              controller: widget.controller,
              placeholder: const Text('Enter model-specific instruction...'),
              onChanged: (_) {
                // Invalidate processed text when content changes
                if (_processedText != null) {
                  setState(() => _processedText = null);
                  if (_renderJinja) {
                    _loadContext();
                  }
                }
                widget.onChanged();
              },
            ),
        ],
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
    return ShadButton.outline(
      onPressed: () => _showAddDialog(context),
      leading: const Icon(LucideIcons.plus),
      child: const Text('Add Model Override'),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final availableModels = availableLlms
        .where((llm) => !existingIdentifiers.contains(llm.identifier))
        .toList();

    if (availableModels.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(
          description: Text('All configured models already have overrides'),
        ),
      );
      return;
    }

    final result = await showShadDialog<String>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Select Model'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableModels.map((llm) {
              return ShadButton.ghost(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(llm.identifier),
                    Text(
                      llm.apiType.name,
                      style: ShadTheme.of(context).textTheme.muted,
                    ),
                  ],
                ),
                onPressed: () => Navigator.of(context).pop(llm.identifier),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (result != null) {
      onAdd(result);
    }
  }
}

/// Info banner explaining available template variables
class _TemplateVariablesInfo extends StatelessWidget {
  const _TemplateVariablesInfo();

  @override
  Widget build(BuildContext context) {
    return ShadAlert(
      icon: const Icon(LucideIcons.info),
      title: const Text('Template Variables'),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const Text(
            'Use {{ SECRETS|join(", ") }} to automatically insert a comma-separated list of all secret names.',
          ),
          const SizedBox(height: 4),
          const Text(
            'Use {{ USER_SNIPPETS }} and {{ PROJECT_SNIPPETS }} to access snippets. Each snippet has: name, content, description, tags, position, createdAt, updatedAt.',
          ),
          const SizedBox(height: 4),
          Text(
            r'Use \{{ to escape and show literal braces.',
            style: ShadTheme.of(context).textTheme.muted,
          ),
        ],
      ),
    );
  }
}
