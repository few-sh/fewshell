import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/llm_api_settings.dart';
import '../providers/llm_settings_provider.dart';
import '../providers/project_provider.dart';
import '../pages/ocr_scanner_page.dart';
import '../utils/text_pattern_matcher.dart';
import '../services/llm_service.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  bool _obscureApiKey = true;
  bool _isTestingConnection = false;
  String? _testResultMessage;
  bool? _testResultSuccess;
  late bool _enabled;
  late LlmApiType _selectedApiType;

  bool get _isEditMode => widget.initialIdentifier != null;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: widget.initialIdentifier,
    );
    _urlController = TextEditingController(text: widget.initialUrl);
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
    _enabled = widget.initialEnabled ?? true;
    _selectedApiType = widget.initialApiType ?? LlmApiType.openai;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
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
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: 'Model Identifier',
                  hintText: 'e.g., gpt-4-turbo, claude-3-5-sonnet',
                  isDense: true,
                ),
                enabled: !_isEditMode,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a model identifier';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LlmApiType>(
                value: _selectedApiType,
                decoration: const InputDecoration(
                  labelText: 'API Type',
                  isDense: true,
                ),
                items: LlmApiType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedApiType = value;
                      // Update URL to default for selected API type if it's empty or unchanged
                      if (_urlController.text.isEmpty ||
                          _urlController.text ==
                              _selectedApiType.defaultBaseUrl) {
                        _urlController.text = value.defaultBaseUrl;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'API URL',
                  hintText: 'https://api.example.com/v1',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 20),
                    onPressed: _scanUrl,
                    tooltip: 'Scan URL with camera',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                        icon: const Icon(Icons.camera_alt, size: 20),
                        onPressed: _scanApiKey,
                        tooltip: 'Scan API key with camera',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
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
                maxLines: _obscureApiKey ? 1 : 3,
                obscureText: _obscureApiKey,
                validator: (value) {
                  // API key is required for new models but optional for edits
                  if (!_isEditMode && (value == null || value.isEmpty)) {
                    return 'Please enter an API key';
                  }
                  return null;
                },
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Enabled'),
                  subtitle: const Text('Allow this model to be used'),
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
        enabled: _isEditMode ? _enabled : null,
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
