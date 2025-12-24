import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Search match navigator widget
/// Shows match count and provides previous/next navigation buttons
class SearchMatchNavigator extends StatelessWidget {
  final int currentMatch;
  final int totalMatches;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const SearchMatchNavigator({
    super.key,
    required this.currentMatch,
    required this.totalMatches,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hasMatches = totalMatches > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasMatches ? '$currentMatch of $totalMatches' : 'No matches',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.foreground.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            ShadButton.ghost(
              width: 24,
              height: 24,
              padding: EdgeInsets.zero,
              onPressed: hasMatches ? onPrevious : null,
              child: Icon(
                LucideIcons.chevronUp,
                size: 16,
                color: hasMatches
                    ? theme.colorScheme.primary
                    : theme.colorScheme.foreground.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 4),
            ShadButton.ghost(
              width: 24,
              height: 24,
              padding: EdgeInsets.zero,
              onPressed: hasMatches ? onNext : null,
              child: Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: hasMatches
                    ? theme.colorScheme.primary
                    : theme.colorScheme.foreground.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
