import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('AppUpdateDialog');

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=sh.few.fewshell';
const _appStoreUrl = 'https://apps.apple.com/us/app/fewshell/id6755896752';
const _websiteUrl = 'https://fewshell.com/';

/// Dialog shown when the connected server reports a version newer than the
/// running client. Directs the user to the appropriate app store / download
/// page for their platform.
class AppUpdateDialog extends StatelessWidget {
  final String serverVersion;
  final String clientVersion;

  const AppUpdateDialog({
    super.key,
    required this.serverVersion,
    required this.clientVersion,
  });

  static Future<void> show(
    BuildContext context, {
    required String serverVersion,
    required String clientVersion,
  }) {
    return showShadDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppUpdateDialog(
        serverVersion: serverVersion,
        clientVersion: clientVersion,
      ),
    );
  }

  /// Returns the platform-appropriate update URL.
  static String _updateUrl() {
    if (kIsWeb) return _websiteUrl;
    if (Platform.isAndroid) return _playStoreUrl;
    if (Platform.isIOS) return _appStoreUrl;
    return _websiteUrl;
  }

  Future<void> _openUpdateUrl(BuildContext context) async {
    final url = Uri.parse(_updateUrl());
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) {
        _log.warning('launchUrl returned false for $url');
      }
    } catch (e, st) {
      _log.warning('Failed to launch update URL $url', e, st);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadDialog(
      title: const Text('Update Required'),
      actions: [
        ShadButton.outline(
          child: const Text('Later'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ShadButton(
          child: const Text('Update'),
          onPressed: () => _openUpdateUrl(context),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The server is running a newer version of Fewshell. '
            'Please update the app to ensure full compatibility.',
            style: TextStyle(
              color: theme.colorScheme.mutedForeground,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _VersionRow(label: 'Server version', value: serverVersion),
          const SizedBox(height: 4),
          _VersionRow(label: 'App version', value: clientVersion),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;

  const _VersionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: theme.colorScheme.mutedForeground,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
