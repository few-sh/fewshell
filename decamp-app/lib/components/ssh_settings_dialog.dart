import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'ssh_prompt_dialog.dart';
import '../providers/ssh_settings_provider.dart';

/// Reusable dialog for configuring SSH/Remote Shell settings
class SshSettingsDialog {
  /// Show dialog to configure SSH settings
  ///
  /// When [existingSettings] is null, the dialog is in "create" mode.
  /// When [existingSettings] is provided, the dialog is in "edit" mode.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String projectId,
    SshSettings? existingSettings,
  }) async {
    final isEditMode = existingSettings != null;

    // Fetch credentials for edit mode
    String? password;
    String? privateKey;
    String? passphrase;
    String? sudoPassword;

    if (isEditMode) {
      final notifier = ref.read(projectSshSettingsProvider(projectId).notifier);

      if (existingSettings.passwordSecretId != null) {
        password = await notifier.getSecret(existingSettings.passwordSecretId!);
      }
      if (existingSettings.privateKeySecretId != null) {
        privateKey = await notifier.getSecret(
          existingSettings.privateKeySecretId!,
        );
      }
      if (existingSettings.passphraseSecretId != null) {
        passphrase = await notifier.getSecret(
          existingSettings.passphraseSecretId!,
        );
      }
      if (existingSettings.sudoPasswordSecretId != null) {
        sudoPassword = await notifier.getSecret(
          existingSettings.sudoPasswordSecretId!,
        );
      }
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => _SshSettingsDialogForm(
        title: isEditMode ? 'Edit Remote Shell' : 'Configure Remote Shell',
        projectId: projectId,
        initialHost: existingSettings?.host,
        initialPort: existingSettings?.port,
        initialUsername: existingSettings?.username,
        initialAuthMethod: existingSettings?.authMethod,
        initialPassword: password,
        initialPrivateKey: privateKey,
        initialPassphrase: passphrase,
        initialSudoPassword: sudoPassword,
        initialEnabled: existingSettings?.enabled,
        onSave:
            (
              host,
              port,
              username,
              authMethod,
              password,
              privateKey,
              passphrase,
              sudoPassword, {
              enabled,
            }) async {
              await _saveSshSettings(
                context,
                ref,
                projectId: projectId,
                isEditMode: isEditMode,
                host: host,
                port: port,
                username: username,
                authMethod: authMethod,
                password: password,
                privateKey: privateKey,
                passphrase: passphrase,
                sudoPassword: sudoPassword,
                enabled: enabled,
              );
            },
      ),
    );
  }

  /// Save SSH settings (create or update)
  static Future<void> _saveSshSettings(
    BuildContext context,
    WidgetRef ref, {
    required String projectId,
    required bool isEditMode,
    required String host,
    required int port,
    required String username,
    required SshAuthMethod authMethod,
    String? password,
    String? privateKey,
    String? passphrase,
    String? sudoPassword,
    bool? enabled,
  }) async {
    try {
      final notifier = ref.read(projectSshSettingsProvider(projectId).notifier);

      if (isEditMode) {
        await notifier.updateSshSettings(
          host: host,
          port: port,
          username: username,
          authMethod: authMethod,
          password: password,
          privateKey: privateKey,
          passphrase: passphrase,
          sudoPassword: sudoPassword,
          enabled: enabled,
        );
      } else {
        await notifier.createSshSettings(
          host: host,
          port: port,
          username: username,
          authMethod: authMethod,
          password: password,
          privateKey: privateKey,
          passphrase: passphrase,
          sudoPassword: sudoPassword,
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? 'Remote shell configuration updated'
                  : 'Remote shell configured successfully',
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
                  ? 'Error updating configuration: $e'
                  : 'Error configuring remote shell: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Internal form widget for the SSH settings dialog
class _SshSettingsDialogForm extends ConsumerStatefulWidget {
  final String title;
  final String projectId;
  final String? initialHost;
  final int? initialPort;
  final String? initialUsername;
  final SshAuthMethod? initialAuthMethod;
  final String? initialPassword;
  final String? initialPrivateKey;
  final String? initialPassphrase;
  final String? initialSudoPassword;
  final bool? initialEnabled;
  final Function(
    String host,
    int port,
    String username,
    SshAuthMethod authMethod,
    String? password,
    String? privateKey,
    String? passphrase,
    String? sudoPassword, {
    bool? enabled,
  })
  onSave;

  const _SshSettingsDialogForm({
    required this.title,
    required this.projectId,
    this.initialHost,
    this.initialPort,
    this.initialUsername,
    this.initialAuthMethod,
    this.initialPassword,
    this.initialPrivateKey,
    this.initialPassphrase,
    this.initialSudoPassword,
    this.initialEnabled,
    required this.onSave,
  });

  @override
  ConsumerState<_SshSettingsDialogForm> createState() =>
      _SshSettingsDialogFormState();
}

class _SshSettingsDialogFormState
    extends ConsumerState<_SshSettingsDialogForm> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _privateKeyController;
  late final TextEditingController _passphraseController;
  late final TextEditingController _sudoPasswordController;

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  bool _obscurePassword = true;
  bool _obscurePassphrase = true;
  bool _obscureSudoPassword = true;
  bool _isTestingConnection = false;
  String? _testResultMessage;
  bool? _testResultSuccess;
  late bool _enabled;
  late SshAuthMethod _authMethod;

  bool get _isEditMode => widget.initialHost != null;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.initialHost);
    _portController = TextEditingController(
      text: (widget.initialPort ?? 22).toString(),
    );
    _usernameController = TextEditingController(text: widget.initialUsername);
    _passwordController = TextEditingController(text: widget.initialPassword);
    _privateKeyController = TextEditingController(
      text: widget.initialPrivateKey,
    );
    _passphraseController = TextEditingController(
      text: widget.initialPassphrase,
    );
    _sudoPasswordController = TextEditingController(
      text: widget.initialSudoPassword,
    );
    _enabled = widget.initialEnabled ?? true;
    _authMethod = widget.initialAuthMethod ?? SshAuthMethod.privateKey;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    _sudoPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Host field
              TextFormField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: 'Host',
                  hintText: 'example.com or 192.168.1.100',
                  isDense: true,
                ),
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a host';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Port field
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '22',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a port';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return 'Port must be between 1 and 65535';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'root or admin',
                  isDense: true,
                ),
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Authentication method selector
              Text(
                'Authentication Method',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildAuthMethodCard(
                      title: 'Password',
                      icon: Icons.password,
                      method: SshAuthMethod.password,
                      isSelected: _authMethod == SshAuthMethod.password,
                      onTap: () {
                        setState(() {
                          _authMethod = SshAuthMethod.password;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAuthMethodCard(
                      title: 'Private Key',
                      icon: Icons.key,
                      method: SshAuthMethod.privateKey,
                      isSelected: _authMethod == SshAuthMethod.privateKey,
                      onTap: () {
                        setState(() {
                          _authMethod = SshAuthMethod.privateKey;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Conditional fields based on auth method
              if (_authMethod == SshAuthMethod.password) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: _isEditMode
                        ? 'Leave blank to keep current password'
                        : 'Enter your password',
                    isDense: true,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  minLines: 1,
                  maxLines: _obscurePassword ? 1 : 3,
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (!_isEditMode && (value == null || value.isEmpty)) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _privateKeyController,
                  decoration: InputDecoration(
                    labelText: 'Private Key',
                    hintText: _isEditMode
                        ? 'Leave blank to keep current key'
                        : 'Paste your private key',
                    isDense: true,
                    helperText: 'Paste the contents of your private key file',
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (!_isEditMode && (value == null || value.isEmpty)) {
                      return 'Please enter a private key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passphraseController,
                  decoration: InputDecoration(
                    labelText: 'Passphrase (Optional)',
                    hintText: 'Enter passphrase if key is encrypted',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassphrase
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassphrase = !_obscurePassphrase;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  minLines: 1,
                  maxLines: _obscurePassphrase ? 1 : 3,
                  obscureText: _obscurePassphrase,
                ),
              ],

              // Sudo password field (applies to all auth methods)
              const SizedBox(height: 12),
              TextFormField(
                controller: _sudoPasswordController,
                decoration: InputDecoration(
                  labelText: 'Sudo Password (Optional)',
                  hintText: _isEditMode
                      ? 'Leave blank to keep current sudo password'
                      : 'Enter password for sudo commands',
                  helperText:
                      'Required for commands needing elevated privileges',
                  helperMaxLines: 2,
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSudoPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureSudoPassword = !_obscureSudoPassword;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                minLines: 1,
                maxLines: _obscureSudoPassword ? 1 : 3,
                obscureText: _obscureSudoPassword,
              ),

              if (_isEditMode) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Enabled'),
                  subtitle: const Text(
                    'Allow connections using this configuration',
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
                    _isTestingConnection
                        ? 'Testing Connection...'
                        : 'Test Connection',
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

  Widget _buildAuthMethodCard({
    required String title,
    required IconData icon,
    required SshAuthMethod method,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
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

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // TODO: We should make sure we return complete error information
    // if there is a failure.
    // The error text should be selectable/copyable.

    setState(() {
      _isTestingConnection = true;
      _testResultMessage = null;
      _testResultSuccess = null;
    });

    try {
      // Create temporary SSH settings for testing
      final testSettings = SshSettings(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 22,
        username: _usernameController.text.trim(),
        authMethod: _authMethod,
        passwordSecretId: null,
        privateKeySecretId: null,
        passphraseSecretId: null,
        enabled: true,
      );

      // Create ShellService instance with inline credentials
      final shellService = ShellService(null, null, null);
      shellService.onUserPrompt = (prompt, echo) =>
          showSshPrompt(context, prompt, echo);

      // Connect with inline credentials
      await shellService.connect(
        testSettings,
        inlinePassword: _authMethod == SshAuthMethod.password
            ? _passwordController.text
            : null,
        inlinePrivateKey: _authMethod == SshAuthMethod.privateKey
            ? _privateKeyController.text
            : null,
        inlinePassphrase:
            _authMethod == SshAuthMethod.privateKey &&
                _passphraseController.text.isNotEmpty
            ? _passphraseController.text
            : null,
      );

      // Disconnect immediately - authentication success is sufficient
      shellService.disconnect();

      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testResultSuccess = true;
          _testResultMessage = 'Connection successful!';
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testResultSuccess = false;
          _testResultMessage = 'Connection error: $e';
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
      final port = int.parse(_portController.text);

      widget.onSave(
        _hostController.text,
        port,
        _usernameController.text,
        _authMethod,
        _authMethod == SshAuthMethod.password ? _passwordController.text : null,
        _authMethod == SshAuthMethod.privateKey
            ? _privateKeyController.text
            : null,
        _authMethod == SshAuthMethod.privateKey &&
                _passphraseController.text.isNotEmpty
            ? _passphraseController.text
            : null,
        _sudoPasswordController.text.isNotEmpty
            ? _sudoPasswordController.text
            : null,
        enabled: _isEditMode ? _enabled : null,
      );
      Navigator.of(context).pop();
    }
  }
}
