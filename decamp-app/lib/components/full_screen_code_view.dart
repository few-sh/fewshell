import 'dart:async';
import 'package:flutter/material.dart';
import 'package:decamp/themes/terminal_theme.dart';
import 'package:decamp/utils/ansi_renderer.dart';

/// Full-screen code viewer with hero animation and streaming support
///
/// Displays code content in a full-screen modal view with scrolling support.
/// When [codeStream] is provided the displayed code updates live as events
/// arrive. The stream is expected to emit `(String code, bool isStreaming)`
/// tuples. The modal stays open and shows the last known code even after the
/// stream closes (source widget disposed).
/// Dismissible via floating X button.
class FullScreenCodeView extends StatefulWidget {
  final String code;
  final bool isStreaming;
  final String language;
  final String heroTag;
  final TerminalTheme terminalTheme;
  final Stream<(String, bool)>? codeStream;

  const FullScreenCodeView({
    super.key,
    required this.code,
    required this.isStreaming,
    required this.language,
    required this.heroTag,
    required this.terminalTheme,
    this.codeStream,
  });

  @override
  State<FullScreenCodeView> createState() => _FullScreenCodeViewState();
}

class _FullScreenCodeViewState extends State<FullScreenCodeView> {
  late String _displayedCode;
  late bool _isStreaming;
  StreamSubscription<(String, bool)>? _codeSub;

  @override
  void initState() {
    super.initState();
    _displayedCode = widget.code;
    _isStreaming = widget.isStreaming;
    if (widget.codeStream != null) {
      _codeSub = widget.codeStream!.listen(
        (event) {
          final (code, isStreaming) = event;
          setState(() {
            _displayedCode = code;
            _isStreaming = isStreaming;
          });
        },
        onDone: () {
          setState(() {
            _isStreaming = false;
          });
        },
      );
    }
  }

  @override
  void dispose() {
    _codeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable code content
            SelectionArea(
              contextMenuBuilder: (context, selectableRegionState) {
                try {
                  return AdaptiveTextSelectionToolbar.selectableRegion(
                    selectableRegionState: selectableRegionState,
                  );
                } catch (e) {
                  // Workaround for crash when scrolling and selecting
                  return const SizedBox.shrink();
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Hero(
                  tag: widget.heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.terminalTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.terminalTheme.borderColor,
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(12),
                        child: Text.rich(
                          buildAnsiTextSpan(
                            text: _displayedCode,
                            baseStyle: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: widget.terminalTheme.textColor,
                              height: 1.5,
                            ),
                            palette: widget.terminalTheme.ansiPalette,
                            defaultForeground: widget.terminalTheme.textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Floating close button
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ),
            ),
            // Streaming indicator
            if (_isStreaming)
              Positioned(
                bottom: 16,
                right: 16,
                child: Material(
                  color: Colors.black54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Streaming...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
