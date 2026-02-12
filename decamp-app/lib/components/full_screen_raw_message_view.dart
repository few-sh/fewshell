import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Full-screen viewer for raw message JSON.
/// Displays the pretty-printed MessageEntity as JSON.
/// Selectable/copyable, dismissible via a close button.
class FullScreenRawMessageView extends StatelessWidget {
  final MessageEntity message;

  const FullScreenRawMessageView({super.key, required this.message});

  String get _prettyJson {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(message.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    final json = _prettyJson;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable JSON content
            SelectionArea(
              contextMenuBuilder: (context, selectableRegionState) {
                try {
                  return AdaptiveTextSelectionToolbar.selectableRegion(
                    selectableRegionState: selectableRegionState,
                  );
                } catch (e) {
                  return const SizedBox.shrink();
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        LucideIcons.braces,
                        size: 18,
                        color: colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Raw Message',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // JSON body
                  Text(
                    json,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colorScheme.foreground,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            // Top-right buttons: copy + close
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShadButton.ghost(
                    width: 36,
                    height: 36,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: json));
                      ShadToaster.of(context).show(
                        const ShadToast(
                          description: Text('JSON copied to clipboard'),
                        ),
                      );
                    },
                    child: Icon(
                      LucideIcons.copy,
                      size: 18,
                      color: colorScheme.foreground,
                    ),
                  ),
                  ShadButton.ghost(
                    width: 36,
                    height: 36,
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: colorScheme.foreground,
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
