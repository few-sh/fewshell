import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/full_screen_code_view.dart';
import 'package:decamp/utils/highlight_injector.dart';

/// Expandable code block with truncation and hero animation
///
/// Automatically truncates code content that exceeds [kTerminalMaxLines],
/// showing first and last [kTerminalEllipsisHalfLines] with an ellipsis indicator.
/// Provides an expand button to view full content in a full-screen modal.
class ExpandableCodeBlock extends StatefulWidget {
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
  State<ExpandableCodeBlock> createState() => _ExpandableCodeBlockState();
}

class _ExpandableCodeBlockState extends State<ExpandableCodeBlock> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  /// Intercepts Cmd+C / Ctrl+C to post-process the clipboard,
  /// replacing the truncation ellipsis with the full hidden content.
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyC) return false;
    if (!HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }

    final lines = widget.code.split('\n');
    if (lines.length <= kTerminalMaxLines) return false;

    // Let the default copy happen, then replace the ellipsis in clipboard
    Future.delayed(
      const Duration(milliseconds: 100),
      _replaceClipboardEllipsis,
    );
    return false;
  }

  Future<void> _replaceClipboardEllipsis() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;

    final expanded = _expandTruncatedText(data!.text!);
    if (expanded != data.text) {
      await Clipboard.setData(ClipboardData(text: expanded));
    }
  }

  /// Replaces the `... (N more lines) ...` marker with the actual hidden lines.
  String _expandTruncatedText(String text) {
    final codeLines = widget.code.split('\n');
    final totalLines = codeLines.length;
    if (totalLines <= kTerminalMaxLines) return text;

    final hiddenCount = totalLines - 2 * kTerminalEllipsisHalfLines;
    final expectedEllipsis = '... ($hiddenCount more lines) ...';
    if (!text.contains(expectedEllipsis)) return text;

    final textLines = text.split('\n');
    final ellipsisIndex = textLines.indexOf(expectedEllipsis);
    if (ellipsisIndex == -1) return text;

    final hiddenLines = codeLines.sublist(
      kTerminalEllipsisHalfLines,
      totalLines - kTerminalEllipsisHalfLines,
    );

    return [
      ...textLines.sublist(0, ellipsisIndex),
      ...hiddenLines,
      ...textLines.sublist(ellipsisIndex + 1),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.code.split('\n');
    final totalLines = lines.length;
    final needsTruncation = totalLines > kTerminalMaxLines;

    // Build displayed content (truncated or full)
    final displayedContent = needsTruncation
        ? _buildTruncatedContent(lines, totalLines)
        : widget.code;

    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        try {
          if (needsTruncation) {
            return _buildExpandedCopyContextMenu(
              context,
              selectableRegionState,
            );
          }
          return AdaptiveTextSelectionToolbar.selectableRegion(
            selectableRegionState: selectableRegionState,
          );
        } catch (e) {
          // Workaround for crash when scrolling and selecting
          return const SizedBox.shrink();
        }
      },
      child: Hero(
        tag: widget.heroTag,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Code content container
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.terminalTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.terminalTheme.borderColor,
                    width: 1,
                  ),
                ),
                child: widget.centered
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
                    color: widget.terminalTheme.backgroundColor.withValues(
                      alpha: 0.9,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: () => _openFullScreen(context),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.fullscreen,
                          size: 18,
                          color: widget.terminalTheme.textColor.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

  /// Build context menu with a Copy button that expands truncated content
  Widget _buildExpandedCopyContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final buttonItems = selectableRegionState.contextMenuButtonItems;
    final modifiedItems = buttonItems.map((item) {
      if (item.type == ContextMenuButtonType.copy) {
        final originalOnPressed = item.onPressed;
        return ContextMenuButtonItem(
          label: item.label,
          type: item.type,
          onPressed: () {
            // Perform default copy, then replace the ellipsis in clipboard
            originalOnPressed?.call();
            Future.delayed(
              const Duration(milliseconds: 100),
              _replaceClipboardEllipsis,
            );
          },
        );
      }
      return item;
    }).toList();

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: modifiedItems,
    );
  }

  /// Build code text with highlights using RichText
  Widget _buildHighlightedCode(String text) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      color: widget.terminalTheme.textColor,
      height: 1.5,
    );

    if (widget.highlights.isEmpty) {
      return Text(text, style: baseStyle);
    }

    // Build TextSpans with highlights
    final spans = <TextSpan>[];
    var lastIndex = 0;

    // Sort highlights by offset
    final sortedHighlights = widget.highlights.toList()
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
            backgroundColor: highlight.isActive
                ? widget.activeColor
                : widget.inactiveColor,
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
            code: widget.code,
            language: widget.language,
            heroTag: widget.heroTag,
            terminalTheme: widget.terminalTheme,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
