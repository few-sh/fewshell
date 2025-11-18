import 'package:flutter/material.dart';
import 'package:decamp/themes/terminal_theme.dart';

/// Full-screen code viewer with hero animation
///
/// Displays code content in a full-screen modal view with scrolling support.
/// Dismissible via floating X button or swipe-down gesture.
/// Placeholder for future search controller integration.
class FullScreenCodeView extends StatelessWidget {
  final String code;
  final String language;
  final String heroTag;
  final TerminalTheme terminalTheme;

  const FullScreenCodeView({
    super.key,
    required this.code,
    required this.language,
    required this.heroTag,
    required this.terminalTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable code content
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Hero(
                tag: heroTag,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: terminalTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: terminalTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        code,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: terminalTheme.textColor,
                          height: 1.5,
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
          ],
        ),
      ),
    );
  }
}
