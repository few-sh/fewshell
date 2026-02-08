import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'full_screen_summary_view.dart';

/// Collapsed card for conversation summary messages.
/// Shows a single-line header; taps to open a full-screen reader.
class SummaryMessageCard extends StatelessWidget {
  final MessageEntity message;

  const SummaryMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.muted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.border),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.listCollapse,
              size: 16,
              color: colorScheme.mutedForeground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Conversation summary',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              LucideIcons.expand,
              size: 14,
              color: colorScheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenSummaryView(message: message);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
