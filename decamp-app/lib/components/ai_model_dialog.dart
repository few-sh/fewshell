import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:async/async.dart';
import '../utils/ui_utils.dart';
import '../providers/llm_settings_provider.dart';
import '../providers/project_provider.dart';
import '../providers/llm_service_provider.dart';

/// Reusable dialog for adding or editing AI model configurations
class AIModelDialog {
  /// Show dialog to add or edit an AI model
  ///
  /// When [existingSettings] is null, the dialog is in "add" mode.
  /// When [existingSettings] is provided, the dialog is in "edit" mode.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required bool isGlobal,
    LlmApiSettings? existingSettings,
  }) async {
    final isEditMode = existingSettings != null;

    // Fetch API key for edit mode
    String? apiKey;
    if (isEditMode) {
      if (isGlobal) {
        apiKey = await ref
            .read(globalLlmSettingsProvider.notifier)
            .getApiKey(existingSettings.identifier);
      } else {
        final projectId = ref.read(currentProjectIdProvider);
        if (projectId != null) {
          apiKey = await ref
              .read(projectLlmSettingsProvider(projectId).notifier)
              .getApiKey(existingSettings.identifier);
        }
      }
    }

    if (!context.mounted) return;

    await showShadDialog(
      context: context,
      builder: (context) => _AIModelDialogForm(
        title: isEditMode ? 'Edit AI Model' : 'Add AI Model',
        isGlobal: isGlobal,
        initialIdentifier: existingSettings?.identifier,
        initialApiType: existingSettings?.apiType,
        initialUrl: existingSettings?.baseUrl,
        initialApiKey: apiKey ?? '',
        initialMaxTokens: existingSettings?.maxTokens,
        initialTemperature: existingSettings?.temperature,
        initialEnabled: existingSettings?.enabled,
      ),
    );
  }
}

/// Internal form widget for the AI model dialog
class _AIModelDialogForm extends ConsumerStatefulWidget {
  final String title;
  final bool isGlobal;
  final String? initialIdentifier;
  final LlmApiType? initialApiType;
  final String? initialUrl;
  final String? initialApiKey;
  final int? initialMaxTokens;
  final double? initialTemperature;
  final bool? initialEnabled;

  const _AIModelDialogForm({
    required this.title,
    required this.isGlobal,
    this.initialIdentifier,
    this.initialApiType,
    this.initialUrl,
    this.initialApiKey,
    this.initialMaxTokens,
    this.initialTemperature,
    this.initialEnabled,
  });

  @override
  ConsumerState<_AIModelDialogForm> createState() => _AIModelDialogFormState();
}

class _AIModelDialogFormState extends ConsumerState<_AIModelDialogForm> {
  late final TextEditingController _identifierController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _temperatureController;
  final _scrollController = ScrollController();
  final _testResultKey = GlobalKey();
  CancelableOperation<String?>? _testOperation;
  bool _obscureApiKey = true;
  bool _isTestingConnection = false;
  String? _testResultMessage;
  bool? _testResultSuccess;
  late bool _enabled;
  late LlmApiType _selectedApiType;

  bool get _isEditMode => widget.initialIdentifier != null;

  /// Get supported models for the currently selected API type
  List<String> get _supportedModels {
    switch (_selectedApiType) {
      case LlmApiType.openai:
        return kOpenAIModels;
      case LlmApiType.anthropic:
        return kAnthropicModels;
      case LlmApiType.google:
        return kGoogleModels;
      case LlmApiType.deepseek:
        return kDeepSeekModels;
      case LlmApiType.groq:
        return kGroqModels;
      case LlmApiType.xai:
        return kXAIModels;
      case LlmApiType.ollama:
        return kOllamaModels;
      case LlmApiType.openaiCompatible:
        return kOpenAICompatibleModels;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedApiType = widget.initialApiType ?? LlmApiType.openai;

    // Pre-fill model identifier with first supported model if creating new model
    final initialIdentifier =
        widget.initialIdentifier ??
        (_supportedModels.isNotEmpty ? _supportedModels.first : '');

    _identifierController = TextEditingController(text: initialIdentifier);
    _urlController = TextEditingController(text: widget.initialUrl);
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
    _maxTokensController = TextEditingController(
      text: widget.initialMaxTokens?.toString() ?? '',
    );
    _temperatureController = TextEditingController(
      text: widget.initialTemperature?.toString() ?? '0.7',
    );
    _enabled = widget.initialEnabled ?? true;
  }

  @override
  void dispose() {
    _testOperation?.cancel();
    _identifierController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _maxTokensController.dispose();
    _temperatureController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadDialog(
      title: Text(widget.title),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ShadButton(onPressed: _save, child: const Text('Save')),
      ],
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text('API Type', style: theme.textTheme.small),
                const SizedBox(height: 4),
                ShadSelect<LlmApiType>(
                  initialValue: _selectedApiType,
                  selectedOptionBuilder: (context, value) =>
                      Text(value.displayName),
                  options: LlmApiType.values.map((type) {
                    return ShadOption(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedApiType = value;
                        // Update URL to default for selected API type
                        _urlController.text = value.defaultBaseUrl;
                        // Auto-populate model identifier with default model
                        // (unless in edit mode)
                        if (!_isEditMode) {
                          _identifierController.text = value.defaultModelId;
                        }
                      });
                    }
                  },
                  placeholder: const Text('Select API Type'),
                ),
                const SizedBox(height: 12),
                Text('Model Identifier', style: theme.textTheme.small),
                const SizedBox(height: 4),
                Autocomplete<String>(
                  initialValue: TextEditingValue(
                    text: _identifierController.text,
                  ),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _supportedModels;
                    }
                    return _supportedModels.where((String option) {
                      return option.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (String selection) {
                    _identifierController.text = selection;
                  },
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController fieldTextEditingController,
                        FocusNode fieldFocusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        // Sync our controller with the autocomplete's controller
                        if (_identifierController.text !=
                            fieldTextEditingController.text) {
                          fieldTextEditingController.text =
                              _identifierController.text;
                        }
                        // Listen to changes in the autocomplete field
                        fieldTextEditingController.addListener(() {
                          if (_identifierController.text !=
                              fieldTextEditingController.text) {
                            _identifierController.text =
                                fieldTextEditingController.text;
                          }
                        });

                        return ShadInput(
                          contextMenuBuilder: adaptiveContextMenuBuilder,
                          controller: fieldTextEditingController,
                          focusNode: fieldFocusNode,
                          placeholder: const Text('Start typing to search...'),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        child: SizedBox(
                          width: 300,
                          height: 200,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return InkWell(
                                onTap: () {
                                  onSelected(option);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(option),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text('API URL', style: theme.textTheme.small),
                const SizedBox(height: 4),
                ShadInput(
                  contextMenuBuilder: adaptiveContextMenuBuilder,
                  controller: _urlController,
                  placeholder: const Text('https://api.example.com/v1'),
                  autocorrect: false,
                  minLines: 1,
                  maxLines: null,
                ),
                const SizedBox(height: 12),
                Text('API Key', style: theme.textTheme.small),
                const SizedBox(height: 4),
                ShadInput(
                  contextMenuBuilder: adaptiveContextMenuBuilder,
                  controller: _apiKeyController,
                  placeholder: Text(
                    _isEditMode
                        ? 'Leave blank to keep current key'
                        : 'Enter your API key',
                  ),
                  autocorrect: false,
                  obscureText: _obscureApiKey,
                  minLines: 1,
                  maxLines: _obscureApiKey ? 1 : null,
                  trailing: ShadButton.ghost(
                    width: 24,
                    height: 24,
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _obscureApiKey ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 16,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Max Tokens', style: theme.textTheme.small),
                          const SizedBox(height: 4),
                          ShadInput(
                            contextMenuBuilder: adaptiveContextMenuBuilder,
                            controller: _maxTokensController,
                            placeholder: const Text('Optional'),
                            autocorrect: false,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Temperature', style: theme.textTheme.small),
                          const SizedBox(height: 4),
                          ShadInput(
                            contextMenuBuilder: adaptiveContextMenuBuilder,
                            controller: _temperatureController,
                            placeholder: const Text('0.0 - 2.0'),
                            autocorrect: false,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_isEditMode) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enabled', style: theme.textTheme.small),
                            Text(
                              'Allow this model to be used',
                              style: theme.textTheme.muted,
                            ),
                          ],
                        ),
                      ),
                      ShadSwitch(
                        value: _enabled,
                        onChanged: (value) {
                          setState(() {
                            _enabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                ShadButton.outline(
                  onPressed: _isTestingConnection
                      ? _abortTest
                      : _testConnection,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isTestingConnection)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(LucideIcons.network, size: 16),
                      const SizedBox(width: 8),
                      Text(_isTestingConnection ? 'Abort' : 'Test Connection'),
                    ],
                  ),
                ),

                // Display test result message
                if (_testResultMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: _testResultKey,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _testResultSuccess == true
                          ? Colors.green.withValues(alpha: 0.1)
                          : theme.colorScheme.destructive.withValues(
                              alpha: 0.1,
                            ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testResultSuccess == true
                            ? Colors.green
                            : theme.colorScheme.destructive,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testResultSuccess == true
                              ? LucideIcons.circleCheck
                              : LucideIcons.circleAlert,
                          color: _testResultSuccess == true
                              ? Colors.green
                              : theme.colorScheme.destructive,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testResultMessage!,
                            style: TextStyle(
                              color: _testResultSuccess == true
                                  ? Colors.green.shade700
                                  : theme.colorScheme.destructive,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abortTest() async {
    await _testOperation?.cancel();
    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _testResultSuccess = false;
        _testResultMessage = 'Connection test aborted';
      });
      _scrollToBottom();
    }
  }

  Future<void> _testConnection() async {
    if (!_validate()) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _testResultMessage = null;
      _testResultSuccess = null;
    });

    try {
      // Create temporary settings for testing
      final testSettings = LlmApiSettings(
        identifier: _identifierController.text,
        apiType: _selectedApiType,
        baseUrl: _urlController.text,
        maxTokens: int.tryParse(_maxTokensController.text),
        temperature: double.tryParse(_temperatureController.text),
      );

      // Use empty string if no API key provided (for edit mode)
      final apiKey = _apiKeyController.text;
      if (apiKey.isEmpty && !_isEditMode) {
        if (mounted) {
          setState(() {
            _isTestingConnection = false;
            _testResultSuccess = false;
            _testResultMessage = 'API key is required for testing';
          });
          _scrollToBottom();
        }
        return;
      }

      // Get LLM service and test connection
      final llmService = ref.read(llmServiceProvider);
      _testOperation = llmService.testConnection(
        config: testSettings,
        apiKey: apiKey,
      );

      final errorMessage = await _testOperation?.value;

      if (mounted && _isTestingConnection) {
        setState(() {
          _isTestingConnection = false;
          _testResultSuccess = errorMessage == null;
          _testResultMessage = errorMessage ?? 'Connection successful!';
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted && _isTestingConnection) {
        setState(() {
          _isTestingConnection = false;
          _testResultSuccess = false;
          _testResultMessage = 'Unexpected error: ${e.toString()}';
        });
        _scrollToBottom();
      }
    } finally {
      _testOperation = null;
    }
  }

  void _scrollToBottom() {
    // Wait for the widget tree to rebuild with the new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _testResultKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 1.0, // Align to bottom
        );
      }
    });
  }

  bool _validate() {
    if (_identifierController.text.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(description: Text('Please enter a model identifier')),
      );
      return false;
    }
    if (_urlController.text.isEmpty) {
      ShadToaster.of(
        context,
      ).show(const ShadToast(description: Text('Please enter an API URL')));
      return false;
    }
    if (!_urlController.text.startsWith('http://') &&
        !_urlController.text.startsWith('https://')) {
      ShadToaster.of(context).show(
        const ShadToast(
          description: Text('URL must start with http:// or https://'),
        ),
      );
      return false;
    }
    if (!_isEditMode && _apiKeyController.text.isEmpty) {
      ShadToaster.of(
        context,
      ).show(const ShadToast(description: Text('Please enter an API key')));
      return false;
    }
    if (_maxTokensController.text.isNotEmpty) {
      final number = int.tryParse(_maxTokensController.text);
      if (number == null || number <= 0) {
        ShadToaster.of(
          context,
        ).show(const ShadToast(description: Text('Invalid Max Tokens')));
        return false;
      }
    }
    if (_temperatureController.text.isNotEmpty) {
      final number = double.tryParse(_temperatureController.text);
      if (number == null || number < 0 || number > 2) {
        ShadToaster.of(context).show(
          const ShadToast(description: Text('Temperature must be 0.0 - 2.0')),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (_validate()) {
      final identifier = _identifierController.text;
      final apiType = _selectedApiType;
      final url = _urlController.text;
      final apiKey = _apiKeyController.text;
      final maxTokens = int.tryParse(_maxTokensController.text);
      final temperature = double.tryParse(_temperatureController.text);
      final enabled = _isEditMode ? _enabled : null;
      final originalIdentifier = widget.initialIdentifier;

      try {
        if (widget.isGlobal) {
          final notifier = ref.read(globalLlmSettingsProvider.notifier);
          if (_isEditMode) {
            await notifier.updateLlmSettings(
              identifier: identifier,
              originalIdentifier: originalIdentifier,
              apiType: apiType,
              baseUrl: url,
              apiKey: apiKey.isNotEmpty ? apiKey : null,
              customHeaders: null,
              maxTokens: maxTokens,
              temperature: temperature,
              enabled: enabled,
            );
          } else {
            await notifier.addLlmSettings(
              identifier: identifier,
              apiType: apiType,
              baseUrl: url,
              apiKey: apiKey,
              customHeaders: null,
              maxTokens: maxTokens,
              temperature: temperature,
            );
          }
        } else {
          final projectId = ref.read(currentProjectIdProvider);
          if (projectId != null) {
            final notifier = ref.read(
              projectLlmSettingsProvider(projectId).notifier,
            );
            if (_isEditMode) {
              await notifier.updateLlmSettings(
                identifier: identifier,
                originalIdentifier: originalIdentifier,
                apiType: apiType,
                baseUrl: url,
                apiKey: apiKey.isNotEmpty ? apiKey : null,
                customHeaders: null,
                maxTokens: maxTokens,
                temperature: temperature,
                enabled: enabled,
              );
            } else {
              await notifier.addLlmSettings(
                identifier: identifier,
                apiType: apiType,
                baseUrl: url,
                apiKey: apiKey,
                customHeaders: null,
                maxTokens: maxTokens,
                temperature: temperature,
              );
            }
          }
        }

        if (mounted) {
          ShadToaster.of(context).show(
            ShadToast(
              description: Text(
                _isEditMode
                    ? 'Updated model: $identifier'
                    : 'Added model: $identifier',
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ShadToaster.of(context).show(
            ShadToast(
              description: Text(
                _isEditMode
                    ? 'Error updating model: $e'
                    : 'Error adding model: $e',
              ),
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
