import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Full-screen reader for conversation summary messages.
/// Dismissible via a close button in the top-right corner.
class FullScreenSummaryView extends StatelessWidget {
  final MessageEntity message;

  const FullScreenSummaryView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable markdown content
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
                        LucideIcons.listCollapse,
                        size: 18,
                        color: colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Session Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Markdown body
                  GptMarkdown(
                    message.content,
                    style: TextStyle(color: colorScheme.foreground),
                  ),
                ],
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: ShadButton.ghost(
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
            ),
          ],
        ),
      ),
    );
  }
}
