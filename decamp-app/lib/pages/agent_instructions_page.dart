import 'package:decamp/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../components/project_title_bar.dart';
import '../components/agent_instruction_preview_modal.dart';
import '../themes/shad_layout_theme.dart';
import '../utils/ui_utils.dart';

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
  final GlobalKey<UserSettingsTabState> _userTabKey = GlobalKey();
  final GlobalKey<ProjectSettingsTabState> _projectTabKey = GlobalKey();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    // Update hasChanges based on the new tab
    // We need to schedule this because we might be in the middle of a build or animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateHasChanges();
      }
    });
  }

  void _updateHasChanges() {
    setState(() {
      if (_tabController.index == 0) {
        _hasChanges = _userTabKey.currentState?.hasChanges ?? false;
      } else {
        _hasChanges = _projectTabKey.currentState?.hasChanges ?? false;
      }
    });
  }

  void _handleTabChanges(bool hasChanges) {
    // This is called by the child tab when its state changes.
    // We need to schedule this because it might be called during the child's build/initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateHasChanges();
      }
    });
  }

  void _handleSave() {
    if (_tabController.index == 0) {
      _userTabKey.currentState?.saveSettings();
    } else {
      _projectTabKey.currentState?.saveSettings();
    }
  }

  void _handlePreview() {
    if (_tabController.index == 0) {
      _userTabKey.currentState?.previewSettings();
    } else {
      _projectTabKey.currentState?.previewSettings();
    }
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    return showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Unsaved Changes'),
        description: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          ShadButton.outline(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ShadButton(
            child: const Text('Leave'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProject = ref.watch(currentProjectProvider);
    final theme = ShadTheme.of(context);
    final layoutTheme = Theme.of(context).extension<ShadLayoutTheme>();
    final pagePadding = layoutTheme?.pagePadding ?? const EdgeInsets.all(16);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await _showExitConfirmationDialog(context);
        if (shouldPop == true) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: const ProjectTitleBar(title: 'Agent Instructions'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: Column(
            children: [
              // Preview and Save buttons
              Padding(
                padding: pagePadding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: layoutTheme?.centeredContentMaxWidth ?? 800,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShadButton.outline(
                          leading: const Icon(LucideIcons.eye),
                          onPressed: _handlePreview,
                          child: const Text('Preview'),
                        ),
                        const SizedBox(width: 8),
                        ShadButton(
                          enabled: _hasChanges,
                          onPressed: _handleSave,
                          leading: const Icon(LucideIcons.save),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.foreground,
                unselectedLabelColor: theme.colorScheme.mutedForeground,
                indicatorColor: theme.colorScheme.primary,
                onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                tabs: const [
                  Tab(text: 'User Settings'),
                  Tab(text: 'Project Settings'),
                ],
              ),

              const ShadSeparator.horizontal(),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    UserSettingsTab(
                      key: _userTabKey,
                      onChanged: _handleTabChanges,
                    ),
                    currentProject != null
                        ? ProjectSettingsTab(
                            key: _projectTabKey,
                            projectId: currentProject.id,
                            onChanged: _handleTabChanges,
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
      ),
    );
  }
}

/// User Settings Tab - Global/User-level agent instructions
class UserSettingsTab extends ConsumerStatefulWidget {
  final ValueChanged<bool> onChanged;

  const UserSettingsTab({required this.onChanged, super.key});

  @override
  ConsumerState<UserSettingsTab> createState() => UserSettingsTabState();
}

class UserSettingsTabState extends ConsumerState<UserSettingsTab>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _defaultController;
  final Map<String, TextEditingController> _modelControllers = {};
  bool _hasChanges = false;
  AgentInstruction? _originalInstruction;
  bool _settingsLoaded = false;

  bool get hasChanges => _hasChanges;

  @override
  bool get wantKeepAlive => true;

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
    _originalInstruction = instruction;

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
    widget.onChanged(_hasChanges);
  }

  void _checkForChanges() {
    final defaultChanged =
        _defaultController.text !=
        (_originalInstruction?.defaultInstruction ?? '');

    bool overridesChanged = false;
    final originalOverrides = _originalInstruction?.modelOverrides ?? {};

    if (_modelControllers.length != originalOverrides.length) {
      overridesChanged = true;
    } else {
      for (var entry in _modelControllers.entries) {
        if (entry.value.text != (originalOverrides[entry.key] ?? '')) {
          overridesChanged = true;
          break;
        }
      }
    }

    final hasChanges = defaultChanged || overridesChanged;
    if (_hasChanges != hasChanges) {
      setState(() => _hasChanges = hasChanges);
      widget.onChanged(_hasChanges);
    }
  }

  Future<void> saveSettings() async {
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

      _originalInstruction = newInstruction;
      setState(() => _hasChanges = false);
      widget.onChanged(_hasChanges);

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

  void previewSettings() {
    AgentInstructionPreviewModal.show(context, _defaultController.text);
  }

  void _addModelOverride(String modelIdentifier) {
    if (!_modelControllers.containsKey(modelIdentifier)) {
      setState(() {
        _modelControllers[modelIdentifier] = TextEditingController();
        _checkForChanges();
      });
    }
  }

  void _removeModelOverride(String modelIdentifier) {
    setState(() {
      _modelControllers[modelIdentifier]?.dispose();
      _modelControllers.remove(modelIdentifier);
      _checkForChanges();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = ref.watch(globalSettingsProvider);
    final llmSettings = ref.watch(globalLlmSettingsProvider);
    final layoutTheme = Theme.of(context).extension<ShadLayoutTheme>();
    final pagePadding = layoutTheme?.pagePadding ?? const EdgeInsets.all(16);

    // Load settings when they change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_settingsLoaded && settings.agentInstruction != null) {
        _loadSettings();
        setState(() => _settingsLoaded = true);
      }
    });

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: pagePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: layoutTheme?.centeredContentMaxWidth ?? 800,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Template variables info
                const _TemplateVariablesInfo(),
                const SizedBox(height: 16),

                // Default Instruction Section
                _InstructionSection(
                  title: 'Default Instruction',
                  subtitle: 'Applies to all models unless overridden',
                  controller: _defaultController,
                  onChanged: _checkForChanges,
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
                                onChanged: _checkForChanges,
                                onRemove: () => _removeModelOverride(entry.key),
                                onPreview: () =>
                                    AgentInstructionPreviewModal.show(
                                      context,
                                      entry.value.text,
                                    ),
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
        ),
      ],
    );
  }
}

/// Project Settings Tab - Project-level agent instructions
class ProjectSettingsTab extends ConsumerStatefulWidget {
  final String projectId;
  final ValueChanged<bool> onChanged;

  const ProjectSettingsTab({
    required this.projectId,
    required this.onChanged,
    super.key,
  });

  @override
  ConsumerState<ProjectSettingsTab> createState() => ProjectSettingsTabState();
}

class ProjectSettingsTabState extends ConsumerState<ProjectSettingsTab>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _defaultController;
  final Map<String, TextEditingController> _modelControllers = {};
  bool _hasChanges = false;
  bool _includeUserInstructions = false;
  bool _settingsLoaded = false;
  ProjectSettings? _originalSettings;

  bool get hasChanges => _hasChanges;

  @override
  bool get wantKeepAlive => true;

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
  void didUpdateWidget(ProjectSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _settingsLoaded = false;
      final settings = ref.read(projectSettingsProvider(widget.projectId));
      if (settings != null) {
        _loadSettings(settings);
        _settingsLoaded = true;
      }
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
    _originalSettings = settings;
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
    widget.onChanged(_hasChanges);
  }

  void _checkForChanges() {
    final originalInstruction = _originalSettings?.agentInstruction;

    final defaultChanged =
        _defaultController.text !=
        (originalInstruction?.defaultInstruction ?? '');

    final includeUserInstructionsChanged =
        _includeUserInstructions !=
        (_originalSettings?.includeUserInstructions ?? false);

    bool overridesChanged = false;
    final originalOverrides = originalInstruction?.modelOverrides ?? {};

    if (_modelControllers.length != originalOverrides.length) {
      overridesChanged = true;
    } else {
      for (var entry in _modelControllers.entries) {
        if (entry.value.text != (originalOverrides[entry.key] ?? '')) {
          overridesChanged = true;
          break;
        }
      }
    }

    final hasChanges =
        defaultChanged || includeUserInstructionsChanged || overridesChanged;
    if (_hasChanges != hasChanges) {
      setState(() => _hasChanges = hasChanges);
      widget.onChanged(_hasChanges);
    }
  }

  Future<void> saveSettings() async {
    try {
      final settings = ref.read(projectSettingsProvider(widget.projectId));
      final settingsNotifier = ref.read(
        projectSettingsProvider(widget.projectId).notifier,
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

      final newSettings = settings.copyWith(
        agentInstruction: newInstruction,
        includeUserInstructions: _includeUserInstructions,
        updatedAt: now,
      );

      await settingsNotifier.updateSettings(newSettings);

      _originalSettings = newSettings;
      setState(() => _hasChanges = false);
      widget.onChanged(_hasChanges);

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

  void previewSettings() {
    AgentInstructionPreviewModal.show(
      context,
      _getPreviewInstruction(null, _defaultController.text),
    );
  }

  void _addModelOverride(String modelIdentifier) {
    if (!_modelControllers.containsKey(modelIdentifier)) {
      setState(() {
        _modelControllers[modelIdentifier] = TextEditingController();
        _checkForChanges();
      });
    }
  }

  void _removeModelOverride(String modelIdentifier) {
    setState(() {
      _modelControllers[modelIdentifier]?.dispose();
      _modelControllers.remove(modelIdentifier);
      _checkForChanges();
    });
  }

  String _getPreviewInstruction(String? modelIdentifier, String currentInput) {
    if (!_includeUserInstructions) {
      return currentInput;
    }

    final globalSettings = ref.read(globalSettingsProvider);
    final userInstruction = globalSettings.agentInstruction;
    if (userInstruction == null) return currentInput;

    String? userPart;
    if (modelIdentifier != null) {
      userPart =
          userInstruction.modelOverrides[modelIdentifier] ??
          userInstruction.defaultInstruction;
    } else {
      userPart = userInstruction.defaultInstruction;
    }

    if (userPart.isEmpty) {
      return currentInput;
    }

    return '$userPart\n\n$currentInput';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final projectId = widget.projectId;
    final llmSettings = ref.watch(projectLlmSettingsProvider(projectId));
    final layoutTheme = Theme.of(context).extension<ShadLayoutTheme>();
    final pagePadding = layoutTheme?.pagePadding ?? const EdgeInsets.all(16);

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

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: pagePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: layoutTheme?.centeredContentMaxWidth ?? 800,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Include User Instructions Switch
                ShadSwitch(
                  value: _includeUserInstructions,
                  onChanged: (value) {
                    setState(() {
                      _includeUserInstructions = value;
                      _checkForChanges();
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
                  onChanged: _checkForChanges,
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
                                onChanged: _checkForChanges,
                                onRemove: () => _removeModelOverride(entry.key),
                                onPreview: () =>
                                    AgentInstructionPreviewModal.show(
                                      context,
                                      _getPreviewInstruction(
                                        entry.key,
                                        entry.value.text,
                                      ),
                                    ),
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
  final VoidCallback onChanged;

  const _InstructionSection({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.onChanged,
  });

  @override
  ConsumerState<_InstructionSection> createState() =>
      _InstructionSectionState();
}

class _InstructionSectionState extends ConsumerState<_InstructionSection> {
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
        ShadInput(
          contextMenuBuilder: adaptiveContextMenuBuilder,
          controller: widget.controller,
          placeholder: const Text('Enter instruction in markdown format...'),
          autocorrect: false,
          minLines: 4,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          onChanged: (_) {
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
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onPreview;

  const _ModelOverrideSection({
    required this.modelIdentifier,
    required this.controller,
    required this.onChanged,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  ConsumerState<_ModelOverrideSection> createState() =>
      _ModelOverrideSectionState();
}

class _ModelOverrideSectionState extends ConsumerState<_ModelOverrideSection> {
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
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
              ShadIconButton.outline(
                icon: const Icon(LucideIcons.eye),
                onPressed: widget.onPreview,
              ),
              ShadIconButton.destructive(
                icon: const Icon(LucideIcons.trash),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ShadInput(
            contextMenuBuilder: adaptiveContextMenuBuilder,
            controller: widget.controller,
            placeholder: const Text('Enter model-specific instruction...'),
            autocorrect: false,
            minLines: 4,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            onChanged: (_) {
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
      description: SelectionArea(
        contextMenuBuilder: (context, selectableRegionState) {
          try {
            return AdaptiveTextSelectionToolbar.selectableRegion(
              selectableRegionState: selectableRegionState,
            );
          } catch (e) {
            return const SizedBox.shrink();
          }
        },
        child: Column(
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
      ),
    );
  }
}
