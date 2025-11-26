import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/shell_service.dart';
import 'ssh_settings_provider.dart';
import 'secret_provider.dart';

/// Provider for the shell service
/// Now requires a project ID to access SSH settings
final shellServiceProvider = Provider.family<ShellService, String?>((
  ref,
  projectId,
) {
  if (projectId == null) {
    return ShellService(null, null, null);
  }

  final sshSettings = ref.watch(projectSshSettingsProvider(projectId));
  final keychain = ref.watch(keychainServiceProvider);
  return ShellService(sshSettings, keychain, projectId);
});
