import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
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

    await showDialog(
      context: context,
      builder: (context) => _AIModelDialogForm(
        ref: ref,
        title: isEditMode ? 'Edit AI Model' : 'Add AI Model',
        isGlobal: isGlobal,
        initialIdentifier: existingSettings?.identifier,
        initialApiType: existingSettings?.apiType,
        initialUrl: existingSettings?.baseUrl,
        initialApiKey: apiKey ?? '',
        initialMaxTokens: existingSettings?.maxTokens,
        initialTemperature: existingSettings?.temperature,
        initialEnabled: existingSettings?.enabled,
        onSave:
            (
              identifier,
              apiType,
              url,
              apiKey, {
              customHeaders,
              maxTokens,
              temperature,
              enabled,
            }) async {
              await _saveModelSettings(
                context,
                ref,
                isGlobal: isGlobal,
                isEditMode: isEditMode,
                identifier: identifier,
                apiType: apiType,
                url: url,
                apiKey: apiKey,
                customHeaders: customHeaders,
                maxTokens: maxTokens,
                temperature: temperature,
                enabled: enabled,
                originalIdentifier: existingSettings?.identifier,
              );
            },
      ),
    );
  }

  /// Save model settings (add or update)
  static Future<void> _saveModelSettings(
    BuildContext context,
    WidgetRef ref, {
    required bool isGlobal,
    required bool isEditMode,
    required String identifier,
    String? originalIdentifier,
    required LlmApiType apiType,
    required String url,
    required String apiKey,
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool? enabled,
  }) async {
    try {
      if (isGlobal) {
        final notifier = ref.read(globalLlmSettingsProvider.notifier);
        if (isEditMode) {
          await notifier.updateLlmSettings(
            identifier: identifier,
            originalIdentifier: originalIdentifier,
            apiType: apiType,
            baseUrl: url,
            apiKey: apiKey.isNotEmpty ? apiKey : null,
            customHeaders: customHeaders,
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
            customHeaders: customHeaders,
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
          if (isEditMode) {
            await notifier.updateLlmSettings(
              identifier: identifier,
              originalIdentifier: originalIdentifier,
              apiType: apiType,
              baseUrl: url,
              apiKey: apiKey.isNotEmpty ? apiKey : null,
              customHeaders: customHeaders,
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
              customHeaders: customHeaders,
              maxTokens: maxTokens,
              temperature: temperature,
            );
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? 'Updated model: $identifier'
                  : 'Added model: $identifier',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? 'Error updating model: $e'
                  : 'Error adding model: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Internal form widget for the AI model dialog
class _AIModelDialogForm extends StatefulWidget {
  final WidgetRef ref;
  final String title;
  final bool isGlobal;
  final String? initialIdentifier;
  final LlmApiType? initialApiType;
  final String? initialUrl;
  final String? initialApiKey;
  final int? initialMaxTokens;
  final double? initialTemperature;
  final bool? initialEnabled;
  final Function(
    String identifier,
    LlmApiType apiType,
    String url,
    String apiKey, {
    String? customHeaders,
    int? maxTokens,
    double? temperature,
    bool? enabled,
  })
  onSave;

  const _AIModelDialogForm({
    required this.ref,
    required this.title,
    required this.isGlobal,
    this.initialIdentifier,
    this.initialApiType,
    this.initialUrl,
    this.initialApiKey,
    this.initialMaxTokens,
    this.initialTemperature,
    this.initialEnabled,
    required this.onSave,
  });

  @override
  State<_AIModelDialogForm> createState() => _AIModelDialogFormState();
}

class _AIModelDialogFormState extends State<_AIModelDialogForm> {
  late final TextEditingController _identifierController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _temperatureController;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
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
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // API Type dropdown (moved to top)
                DropdownButtonFormField<LlmApiType>(
                  value: _selectedApiType,
                  decoration: const InputDecoration(
                    labelText: 'API Type',
                    isDense: true,
                  ),
                  items: LlmApiType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.displayName,
                        overflow: TextOverflow.visible,
                        softWrap: true,
                      ),
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
                ),
                const SizedBox(height: 12),
                // Model Identifier dropdown (searchable)
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

                        return TextFormField(
                          controller: fieldTextEditingController,
                          focusNode: fieldFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Model Identifier',
                            hintText: 'Start typing to search...',
                            isDense: true,
                          ),
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.none,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a model identifier';
                            }
                            return null;
                          },
                        );
                      },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'API URL',
                    hintText: 'https://api.example.com/v1',
                    isDense: true,
                  ),
                  minLines: 1,
                  maxLines: null,
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: _isEditMode
                        ? 'Leave blank to keep current key'
                        : 'Enter your API key',
                    isDense: true,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureApiKey = !_obscureApiKey;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  minLines: 1,
                  maxLines: _obscureApiKey ? 1 : null,
                  obscureText: _obscureApiKey,
                  validator: (value) {
                    // API key is required for new models but optional for edits
                    if (!_isEditMode && (value == null || value.isEmpty)) {
                      return 'Please enter an API key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _maxTokensController,
                        decoration: const InputDecoration(
                          labelText: 'Max Tokens',
                          hintText: 'Optional',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final number = int.tryParse(value);
                            if (number == null || number <= 0) {
                              return 'Invalid number';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _temperatureController,
                        decoration: const InputDecoration(
                          labelText: 'Temperature',
                          hintText: '0.0 - 2.0',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final number = double.tryParse(value);
                            if (number == null || number < 0 || number > 2) {
                              return '0.0 - 2.0';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (_isEditMode) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text(
                      'Enabled',
                      overflow: TextOverflow.visible,
                    ),
                    subtitle: const Text(
                      'Allow this model to be used',
                      overflow: TextOverflow.visible,
                    ),
                    value: _enabled,
                    onChanged: (value) {
                      setState(() {
                        _enabled = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
                const SizedBox(height: 12),
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
                        : const Icon(Icons.network_check, size: 20),
                    label: Text(
                      _isTestingConnection ? 'Testing...' : 'Test Connection',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // Display test result message
                if (_testResultMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _testResultSuccess == true
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testResultSuccess == true
                            ? Colors.green
                            : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testResultSuccess == true
                              ? Icons.check_circle
                              : Icons.error,
                          color: _testResultSuccess == true
                              ? Colors.green
                              : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testResultMessage!,
                            style: TextStyle(
                              color: _testResultSuccess == true
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.visible,
                            softWrap: true,
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
      final llmService = widget.ref.read(llmServiceProvider);
      final errorMessage = await llmService.testConnection(
        config: testSettings,
        apiKey: apiKey,
      );

      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testResultSuccess = errorMessage == null;
          _testResultMessage = errorMessage ?? 'Connection successful!';
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testResultSuccess = false;
          _testResultMessage = 'Unexpected error: ${e.toString()}';
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    // Wait for the widget tree to rebuild with the new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        _identifierController.text,
        _selectedApiType,
        _urlController.text,
        _apiKeyController.text,
        maxTokens: int.tryParse(_maxTokensController.text),
        temperature: double.tryParse(_temperatureController.text),
        enabled: _isEditMode ? _enabled : null,
      );
      Navigator.of(context).pop();
    }
  }
}
