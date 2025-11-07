import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ssh_settings.dart';
import '../providers/ssh_settings_provider.dart';
import '../pages/ocr_scanner_page.dart';
import '../utils/text_pattern_matcher.dart';

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
        initialEnabled: existingSettings?.enabled,
        onSave:
            (
              host,
              port,
              username,
              authMethod,
              password,
              privateKey,
              passphrase, {
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
class _SshSettingsDialogForm extends StatefulWidget {
  final String title;
  final String projectId;
  final String? initialHost;
  final int? initialPort;
  final String? initialUsername;
  final SshAuthMethod? initialAuthMethod;
  final String? initialPassword;
  final String? initialPrivateKey;
  final String? initialPassphrase;
  final bool? initialEnabled;
  final Function(
    String host,
    int port,
    String username,
    SshAuthMethod authMethod,
    String? password,
    String? privateKey,
    String? passphrase, {
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
    this.initialEnabled,
    required this.onSave,
  });

  @override
  State<_SshSettingsDialogForm> createState() => _SshSettingsDialogFormState();
}

class _SshSettingsDialogFormState extends State<_SshSettingsDialogForm> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _privateKeyController;
  late final TextEditingController _passphraseController;

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscurePassphrase = true;
  bool _isTestingConnection = false;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                  prefixIcon: const Icon(Icons.dns),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _scanHost,
                    tooltip: 'Scan host with camera',
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a host';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Port field
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '22',
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              const SizedBox(height: 16),

              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'root or admin',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

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
              const SizedBox(height: 16),

              // Conditional fields based on auth method
              if (_authMethod == SshAuthMethod.password) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: _isEditMode
                        ? 'Leave blank to keep current password'
                        : 'Enter your password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: _scanPassword,
                          tooltip: 'Scan password with camera',
                        ),
                        IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
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
                    prefixIcon: const Icon(Icons.vpn_key),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: _scanPrivateKey,
                      tooltip: 'Scan private key with camera',
                    ),
                    helperText: 'Paste the contents of your private key file',
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (!_isEditMode && (value == null || value.isEmpty)) {
                      return 'Please enter a private key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passphraseController,
                  decoration: InputDecoration(
                    labelText: 'Passphrase (Optional)',
                    hintText: 'Enter passphrase if key is encrypted',
                    prefixIcon: const Icon(Icons.security),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassphrase
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassphrase = !_obscurePassphrase;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassphrase,
                ),
              ],

              if (_isEditMode) ...[
                const SizedBox(height: 16),
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
                    _isTestingConnection
                        ? 'Testing Connection...'
                        : 'Test Connection',
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

    setState(() {
      _isTestingConnection = true;
    });

    // TODO: Implement actual SSH connection test
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection test successful! (Not yet implemented)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _scanHost() async {
    final scannedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const OcrScannerPage(scanType: ScanType.url),
      ),
    );

    if (scannedText != null && mounted) {
      setState(() {
        _hostController.text = scannedText;
      });
    }
  }

  Future<void> _scanPassword() async {
    final scannedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const OcrScannerPage(scanType: ScanType.apiKey),
      ),
    );

    if (scannedText != null && mounted) {
      setState(() {
        _passwordController.text = scannedText;
      });
    }
  }

  Future<void> _scanPrivateKey() async {
    final scannedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const OcrScannerPage(scanType: ScanType.apiKey),
      ),
    );

    if (scannedText != null && mounted) {
      setState(() {
        _privateKeyController.text = scannedText;
      });
    }
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
        enabled: _isEditMode ? _enabled : null,
      );
      Navigator.of(context).pop();
    }
  }
}
