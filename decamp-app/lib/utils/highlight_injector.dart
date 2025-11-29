import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:decamp/utils/search_utils.dart';

/// Result of extracting highlights from code
class CodeWithHighlights {
  final String code;
  final List<CodeHighlight> highlights;

  CodeWithHighlights({required this.code, required this.highlights});
}

/// Highlight information for code blocks
class CodeHighlight {
  final int offset;
  final int length;
  final bool isActive;
  final int matchIndex;

  CodeHighlight({
    required this.offset,
    required this.length,
    required this.isActive,
    required this.matchIndex,
  });
}

/// Injects special highlight markers into text for custom markdown component
class HighlightInjector {
  // Marker pattern: §M<matchIndex>:<active>§text§/M§
  // Using § as it's unlikely to appear in normal text or markdown
  static String injectMarkers(String text, List<HighlightRange> highlights) {
    if (highlights.isEmpty) return text;

    // Sort by offset descending to inject from end to start (avoids offset shifts)
    final sorted = highlights.toList()
      ..sort((a, b) => b.offset.compareTo(a.offset));

    var result = text;
    for (final hl in sorted) {
      final start = hl.offset;
      final end = start + hl.length;

      if (start < 0 || end > result.length || start >= end) continue;

      final marker = '§M${hl.matchIndex}:${hl.isActive ? '1' : '0'}§';
      result =
          '${result.substring(0, start)}$marker${result.substring(start, end)}§/M§${result.substring(end)}';
    }

    return result;
  }

  /// Extract highlights from marked code text and return cleaned code + highlight info
  static CodeWithHighlights extractFromCode(String markedCode) {
    final highlights = <CodeHighlight>[];
    final pattern = RegExp(r'§M(\d+):(0|1)§(.*?)§/M§', dotAll: true);

    var cleanCode = '';
    var lastEnd = 0;
    var offsetShift = 0; // Track cumulative offset shift from removed markers

    // Process matches forward to maintain correct offsets
    for (final match in pattern.allMatches(markedCode)) {
      final matchIndex = int.parse(match.group(1)!);
      final isActive = match.group(2) == '1';
      final text = match.group(3)!;

      // Add text before this match
      cleanCode += markedCode.substring(lastEnd, match.start);

      // Calculate position in cleaned text
      final cleanStart = match.start - offsetShift;

      // Add the highlighted text (without markers)
      cleanCode += text;

      highlights.add(
        CodeHighlight(
          offset: cleanStart,
          length: text.length,
          isActive: isActive,
          matchIndex: matchIndex,
        ),
      );

      // Update offset shift (marker length = total match length - text length)
      final markerLength = match.group(0)!.length - text.length;
      offsetShift += markerLength;

      lastEnd = match.end;
    }

    // Add remaining text after last match
    cleanCode += markedCode.substring(lastEnd);

    return CodeWithHighlights(code: cleanCode, highlights: highlights);
  }
}

/// Custom markdown component for rendering search match highlights with animation
class SearchHighlightComponent extends InlineMd {
  final int? activeMatchIndex;
  final Color activeColor;
  final Color inactiveColor;

  SearchHighlightComponent({
    required this.activeMatchIndex,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  RegExp get exp => RegExp(r'§M(\d+):(0|1)§(.*?)§/M§', dotAll: true);

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    final GptMarkdownConfig config,
  ) {
    final match = exp.firstMatch(text);
    if (match == null) return TextSpan(text: text);

    final matchIndex = int.parse(match.group(1)!);
    final isActive = match.group(2) == '1';
    final highlightedText = match.group(3)!;

    // Return animated widget span for active matches
    if (isActive) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _AnimatedHighlight(
          key: ValueKey('match_$matchIndex'),
          text: highlightedText,
          color: activeColor,
          style: config.style ?? const TextStyle(),
        ),
      );
    }

    // Return simple colored background for inactive matches
    return TextSpan(
      text: highlightedText,
      style: (config.style ?? const TextStyle()).copyWith(
        backgroundColor: inactiveColor,
      ),
    );
  }
}

/// Animated highlight widget with pulse effect
class _AnimatedHighlight extends StatefulWidget {
  final String text;
  final Color color;
  final TextStyle style;

  const _AnimatedHighlight({
    super.key,
    required this.text,
    required this.color,
    required this.style,
  });

  @override
  State<_AnimatedHighlight> createState() => _AnimatedHighlightState();
}

class _AnimatedHighlightState extends State<_AnimatedHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Flash from a brighter version to the base color with ease-out
    // Use HSL to create a brighter version of the color for the flash effect
    final hsl = HSLColor.fromColor(widget.color);
    final brighterColor = hsl
        .withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0))
        .toColor();

    _colorAnimation = ColorTween(
      begin: brighterColor,
      end: widget.color,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Play flash animation once, then repeat with reverse for pulsing effect
    _controller.forward().then((_) {
      _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(widget.text, style: widget.style),
        );
      },
    );
  }
}
