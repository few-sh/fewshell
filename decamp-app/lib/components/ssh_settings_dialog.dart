import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../utils/ui_utils.dart';
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
    String? password,
    String? privateKey,
    String? passphrase,
    String? sudoPassword,
    List<Override>? overrides,
  }) async {
    final isEditMode = existingSettings != null;

    // Fetch credentials for edit mode if not provided
    String? finalPassword = password;
    String? finalPrivateKey = privateKey;
    String? finalPassphrase = passphrase;
    String? finalSudoPassword = sudoPassword;

    if (isEditMode) {
      final notifier = ref.read(projectSshSettingsProvider(projectId).notifier);

      if (finalPassword == null && existingSettings.passwordSecretId != null) {
        finalPassword = await notifier.getSecret(
          existingSettings.passwordSecretId!,
        );
      }
      if (finalPrivateKey == null &&
          existingSettings.privateKeySecretId != null) {
        finalPrivateKey = await notifier.getSecret(
          existingSettings.privateKeySecretId!,
        );
      }
      if (finalPassphrase == null &&
          existingSettings.passphraseSecretId != null) {
        finalPassphrase = await notifier.getSecret(
          existingSettings.passphraseSecretId!,
        );
      }
      if (finalSudoPassword == null &&
          existingSettings.sudoPasswordSecretId != null) {
        finalSudoPassword = await notifier.getSecret(
          existingSettings.sudoPasswordSecretId!,
        );
      }
    }

    if (!context.mounted) return;

    await showShadDialog(
      context: context,
      builder: (context) => ProviderScope(
        overrides: overrides ?? [],
        child: _SshSettingsDialogForm(
          title: isEditMode ? 'Edit Remote Shell' : 'Configure Remote Shell',
          projectId: projectId,
          initialHost: existingSettings?.host,
          initialPort: existingSettings?.port,
          initialUsername: existingSettings?.username,
          initialAuthMethod: existingSettings?.authMethod,
          initialPassword: finalPassword,
          initialPrivateKey: finalPrivateKey,
          initialPassphrase: finalPassphrase,
          initialSudoPassword: finalSudoPassword,
          initialEnabled: existingSettings?.enabled,
        ),
      ),
    );
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

  final _scrollController = ScrollController();
  final _testResultKey = GlobalKey();
  final Map<String, String?> _errors = {};

  bool _obscurePassword = true;
  bool _obscurePrivateKey = true;
  bool _obscurePassphrase = true;
  bool _obscureSudoPassword = true;
  bool _isTestingConnection = false;
  ShellService? _testShellService;
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

  bool _validate() {
    final errors = <String, String?>{};
    bool isValid = true;

    if (_hostController.text.isEmpty) {
      errors['host'] = 'Please enter a host';
      isValid = false;
    }

    if (_portController.text.isEmpty) {
      errors['port'] = 'Please enter a port';
      isValid = false;
    } else {
      final port = int.tryParse(_portController.text);
      if (port == null || port < 1 || port > 65535) {
        errors['port'] = 'Port must be between 1 and 65535';
        isValid = false;
      }
    }

    if (_usernameController.text.isEmpty) {
      errors['username'] = 'Please enter a username';
      isValid = false;
    }

    if (_authMethod == SshAuthMethod.password) {
      if (!_isEditMode && _passwordController.text.isEmpty) {
        errors['password'] = 'Please enter a password';
        isValid = false;
      }
    } else {
      if (!_isEditMode && _privateKeyController.text.isEmpty) {
        errors['privateKey'] = 'Please enter a private key';
        isValid = false;
      }
    }

    setState(() {
      _errors.clear();
      _errors.addAll(errors);
    });

    return isValid;
  }

  Widget _buildLabeledInput({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    String? description,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? trailing,
    int? minLines,
    int? maxLines = 1,
    String? errorKey,
  }) {
    final theme = ShadTheme.of(context);
    final error = errorKey != null ? _errors[errorKey] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.small),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description,
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
        ],
        const SizedBox(height: 4),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          curve: Curves.easeInOut,
          child: ShadInput(
            contextMenuBuilder: adaptiveContextMenuBuilder,
            controller: controller,
            placeholder: placeholder != null ? Text(placeholder) : null,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            trailing: trailing,
            minLines: minLines,
            maxLines: obscureText ? 1 : maxLines,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontFamily: 'Courier New',
              fontFamilyFallback: ['Courier', 'Monaco', 'Menlo'],
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.destructive,
            ),
          ),
        ],
      ],
    );
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
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Host field
              _buildLabeledInput(
                label: 'Host',
                controller: _hostController,
                placeholder: 'example.com or 192.168.1.100',
                errorKey: 'host',
              ),
              const SizedBox(height: 12),

              // Port field
              _buildLabeledInput(
                label: 'Port',
                controller: _portController,
                placeholder: '22',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                errorKey: 'port',
              ),
              const SizedBox(height: 12),

              // Username field
              _buildLabeledInput(
                label: 'Username',
                controller: _usernameController,
                placeholder: 'root or admin',
                errorKey: 'username',
              ),
              const SizedBox(height: 16),

              // Authentication method selector
              Text(
                'Authentication Method',
                style: theme.textTheme.small.copyWith(
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
                      icon: LucideIcons.lock,
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
                      icon: LucideIcons.key,
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
                _buildLabeledInput(
                  label: 'Password',
                  controller: _passwordController,
                  placeholder: _isEditMode
                      ? 'Leave blank to keep current password'
                      : 'Enter your password',
                  obscureText: _obscurePassword,
                  trailing: ShadButton.ghost(
                    width: 24,
                    height: 24,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    child: Icon(
                      _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 16,
                    ),
                  ),
                  errorKey: 'password',
                  maxLines: null,
                ),
              ] else ...[
                _buildLabeledInput(
                  label: 'Private Key',
                  controller: _privateKeyController,
                  placeholder: _isEditMode
                      ? 'Leave blank to keep current key'
                      : 'Paste your private key',
                  description: 'Paste the contents of your private key file',
                  obscureText: _obscurePrivateKey,
                  minLines: _obscurePrivateKey ? 1 : 3,
                  maxLines: null,
                  trailing: ShadButton.ghost(
                    width: 24,
                    height: 24,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _obscurePrivateKey = !_obscurePrivateKey;
                      });
                    },
                    child: Icon(
                      _obscurePrivateKey ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 16,
                    ),
                  ),
                  errorKey: 'privateKey',
                ),
                const SizedBox(height: 12),
                _buildLabeledInput(
                  label: 'Passphrase (Optional)',
                  controller: _passphraseController,
                  placeholder: 'Enter passphrase if key is encrypted',
                  obscureText: _obscurePassphrase,
                  maxLines: null,
                  trailing: ShadButton.ghost(
                    width: 24,
                    height: 24,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _obscurePassphrase = !_obscurePassphrase;
                      });
                    },
                    child: Icon(
                      _obscurePassphrase ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 16,
                    ),
                  ),
                ),
              ],

              // Sudo password field (applies to all auth methods)
              const SizedBox(height: 12),
              _buildLabeledInput(
                label: 'Sudo Password (Optional)',
                controller: _sudoPasswordController,
                placeholder: _isEditMode
                    ? 'Leave blank to keep current sudo password'
                    : 'Enter password for sudo commands',
                description:
                    'Required for commands needing elevated privileges',
                obscureText: _obscureSudoPassword,
                maxLines: null,
                trailing: ShadButton.ghost(
                  width: 24,
                  height: 24,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _obscureSudoPassword = !_obscureSudoPassword;
                    });
                  },
                  child: Icon(
                    _obscureSudoPassword ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 16,
                  ),
                ),
              ),

              if (_isEditMode) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    ShadSwitch(
                      value: _enabled,
                      onChanged: (value) {
                        setState(() {
                          _enabled = value;
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enabled',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Allow connections using this configuration'),
                      ],
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ShadButton.outline(
                  onPressed: _isTestingConnection
                      ? _abortConnection
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
                        : theme.colorScheme.destructive.withValues(alpha: 0.1),
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
                            ? LucideIcons.check
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
    );
  }

  Widget _buildAuthMethodCard({
    required String title,
    required IconData icon,
    required SshAuthMethod method,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.background,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.foreground.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: theme.textTheme.small.copyWith(
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

  void _abortConnection() {
    _testShellService?.disconnect();
    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _testResultMessage = 'Connection aborted by user';
        _testResultSuccess = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _testConnection() async {
    if (!_validate()) {
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
      _testShellService = ShellService(null, null, null);
      _testShellService!.onUserPrompt = (prompt, echo) =>
          showSshPrompt(context, prompt, echo);

      // Connect with inline credentials
      await _testShellService!.connect(
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
      _testShellService?.disconnect();
      _testShellService = null;

      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testResultSuccess = true;
          _testResultMessage = 'Connection successful!';
        });
        _scrollToBottom();
      }
    } catch (e) {
      // If aborted, don't show error
      if (_testResultMessage == 'Connection aborted by user') return;

      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testResultSuccess = false;
          _testResultMessage = 'Connection error: $e';
        });
        _scrollToBottom();
      }
    } finally {
      _testShellService = null;
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

  Future<void> _save() async {
    if (!_validate()) {
      return;
    }

    final port = int.parse(_portController.text);
    final host = _hostController.text;
    final username = _usernameController.text;
    final authMethod = _authMethod;
    final password = authMethod == SshAuthMethod.password
        ? _passwordController.text
        : null;
    final privateKey = authMethod == SshAuthMethod.privateKey
        ? _privateKeyController.text
        : null;
    final passphrase =
        authMethod == SshAuthMethod.privateKey &&
            _passphraseController.text.isNotEmpty
        ? _passphraseController.text
        : null;
    final sudoPassword = _sudoPasswordController.text.isNotEmpty
        ? _sudoPasswordController.text
        : null;
    final enabled = _isEditMode ? _enabled : null;

    try {
      final notifier = ref.read(
        projectSshSettingsProvider(widget.projectId).notifier,
      );

      if (_isEditMode) {
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

      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text('Success'),
            description: Text(
              _isEditMode
                  ? 'Remote shell configuration updated'
                  : 'Remote shell configured successfully',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Error'),
            description: Text(
              _isEditMode
                  ? 'Error updating configuration: $e'
                  : 'Error configuring remote shell: $e',
            ),
          ),
        );
      }
    }
  }
}
