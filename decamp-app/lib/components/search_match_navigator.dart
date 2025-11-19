import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final hasMatches = totalMatches > 0;

    return Card(
      elevation: 4,
      color: colorScheme.surface,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasMatches ? '$currentMatch of $totalMatches' : 'No matches',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_up,
                size: 18,
                color: hasMatches
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Previous match',
              onPressed: hasMatches ? onPrevious : null,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: hasMatches
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Next match',
              onPressed: hasMatches ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}
