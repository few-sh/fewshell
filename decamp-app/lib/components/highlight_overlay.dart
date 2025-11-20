import 'package:flutter/material.dart';

/// Widget that wraps content and highlights specific text ranges
/// Works by overlaying semi-transparent colored boxes at calculated positions
class HighlightOverlay extends StatelessWidget {
  final Widget child;
  final String text;
  final List<HighlightInfo> highlights;

  const HighlightOverlay({
    super.key,
    required this.child,
    required this.text,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    // If no highlights, return child as-is
    if (highlights.isEmpty) {
      return child;
    }

    // For now, return child directly
    // TODO: Implement overlay positioning (complex - needs TextPainter calculations)
    return child;
  }
}

/// Information about a highlight region
class HighlightInfo {
  final int offset;
  final int length;
  final Color color;
  final bool isActive;

  const HighlightInfo({
    required this.offset,
    required this.length,
    required this.color,
    this.isActive = false,
  });
}
