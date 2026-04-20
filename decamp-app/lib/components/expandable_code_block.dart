import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/components/full_screen_code_view.dart';
import 'package:decamp/utils/ansi_renderer.dart';
import 'package:decamp/utils/highlight_injector.dart';

/// Expandable code block with truncation and hero animation
///
/// Automatically truncates code content that exceeds [kTerminalMaxLines],
/// showing first and last [kTerminalEllipsisHalfLines] with an ellipsis indicator.
/// Provides an expand button to view full content in a full-screen modal.
/// When opened while [isStreaming] is true, the full-screen view will
/// continue receiving live updates as the code block is rebuilt.
class ExpandableCodeBlock extends StatefulWidget {
  final String code;
  final String language;
  final String heroTag;
  final TerminalTheme terminalTheme;
  final List<CodeHighlight> highlights;
  final Color activeColor;
  final Color inactiveColor;
  final bool centered;
  final bool isStreaming;

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
    this.isStreaming = false,
  });

  @override
  State<ExpandableCodeBlock> createState() => _ExpandableCodeBlockState();
}

class _ExpandableCodeBlockState extends State<ExpandableCodeBlock> {
  // Owned stream that feeds the full-screen modal if it is open.
  // Broadcast so the user can close/reopen the modal.
  // Closed when this widget is disposed, which triggers onDone in the modal.
  late final StreamController<(String, bool)> _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = StreamController.broadcast();
  }

  @override
  void didUpdateWidget(ExpandableCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.code != oldWidget.code ||
        widget.isStreaming != oldWidget.isStreaming) {
      _codeController.add((widget.code, widget.isStreaming));
    }
  }

  @override
  void dispose() {
    _codeController.close();
    super.dispose();
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

    // Strip ANSI escapes from hidden lines so the clipboard content is
    // consistent with the visible (already escape-free) selection.
    final hiddenLines = codeLines
        .sublist(
          kTerminalEllipsisHalfLines,
          totalLines - kTerminalEllipsisHalfLines,
        )
        .map(stripAnsi)
        .toList();

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
              // Expand button
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

  /// Build code text with ANSI color parsing and search highlights.
  Widget _buildHighlightedCode(String text) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      color: widget.terminalTheme.textColor,
      height: 1.5,
    );

    final span = buildAnsiTextSpan(
      text: text,
      baseStyle: baseStyle,
      palette: widget.terminalTheme.ansiPalette,
      defaultForeground: widget.terminalTheme.textColor,
      highlights: widget.highlights,
      activeHighlightColor: widget.activeColor,
      inactiveHighlightColor: widget.inactiveColor,
    );

    return Text.rich(span);
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
            isStreaming: widget.isStreaming,
            language: widget.language,
            heroTag: widget.heroTag,
            terminalTheme: widget.terminalTheme,
            codeStream: _codeController.stream,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
