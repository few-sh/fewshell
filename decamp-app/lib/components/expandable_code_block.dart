import 'package:flutter/material.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/full_screen_code_view.dart';
import 'package:decamp/utils/highlight_injector.dart';

/// Expandable code block with truncation and hero animation
///
/// Automatically truncates code content that exceeds [kTerminalMaxLines],
/// showing first and last [kTerminalEllipsisHalfLines] with an ellipsis indicator.
/// Provides an expand button to view full content in a full-screen modal.
class ExpandableCodeBlock extends StatelessWidget {
  final String code;
  final String language;
  final String heroTag;
  final TerminalTheme terminalTheme;
  final List<CodeHighlight> highlights;
  final Color activeColor;
  final Color inactiveColor;
  final bool centered;

  const ExpandableCodeBlock({
    super.key,
    required this.code,
    required this.language,
    required this.heroTag,
    required this.terminalTheme,
    this.highlights = const [],
    this.activeColor = Colors.yellow,
    this.inactiveColor = Colors.yellow,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    final totalLines = lines.length;
    final needsTruncation = totalLines > kTerminalMaxLines;

    // Build displayed content (truncated or full)
    final displayedContent = needsTruncation
        ? _buildTruncatedContent(lines, totalLines)
        : code;

    return Hero(
      tag: heroTag,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Code content container
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: terminalTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: terminalTheme.borderColor, width: 1),
              ),
              child: centered
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildHighlightedCode(displayedContent),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      child: _buildHighlightedCode(displayedContent),
                    ),
            ),
            // Expand button (only if truncated)
            if (needsTruncation)
              Positioned(
                bottom: 8,
                right: 8,
                child: Material(
                  color: terminalTheme.backgroundColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: () => _openFullScreen(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.fullscreen,
                        size: 18,
                        color: terminalTheme.textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build truncated content showing first and last lines with ellipsis
  String _buildTruncatedContent(List<String> lines, int totalLines) {
    final firstLines = lines.take(kTerminalEllipsisHalfLines).toList();
    final lastLines = lines
        .skip(totalLines - kTerminalEllipsisHalfLines)
        .toList();
    final hiddenCount = totalLines - (2 * kTerminalEllipsisHalfLines);

    return [
      ...firstLines,
      '... ($hiddenCount more lines) ...',
      ...lastLines,
    ].join('\n');
  }

  /// Build code text with highlights using RichText
  Widget _buildHighlightedCode(String text) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      color: terminalTheme.textColor,
      height: 1.5,
    );

    if (highlights.isEmpty) {
      return Text(text, style: baseStyle);
    }

    // Build TextSpans with highlights
    final spans = <TextSpan>[];
    var lastIndex = 0;

    // Sort highlights by offset
    final sortedHighlights = highlights.toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));

    for (final highlight in sortedHighlights) {
      final start = highlight.offset;
      final end = start + highlight.length;

      // Validate bounds
      if (start < 0 || end > text.length || start < lastIndex) continue;

      // Add text before highlight
      if (start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, start)));
      }

      // Add highlighted text
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: baseStyle.copyWith(
            backgroundColor: highlight.isActive ? activeColor : inactiveColor,
          ),
        ),
      );

      lastIndex = end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  /// Open full-screen code view with hero animation
  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenCodeView(
            code: code,
            language: language,
            heroTag: heroTag,
            terminalTheme: terminalTheme,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
