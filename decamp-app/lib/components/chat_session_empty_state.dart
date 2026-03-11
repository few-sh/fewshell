import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Landing page shown when a chat session has no messages yet.
/// Displays a brief overview and example prompts that pre-fill the input.
class ChatSessionEmptyState extends StatelessWidget {
  final ValueChanged<String> onPromptSelected;

  const ChatSessionEmptyState({super.key, required this.onPromptSelected});

  static final _examplePrompts = [
    (icon: LucideIcons.fileText, text: 'Show recent error logs'),
    (icon: LucideIcons.container, text: 'List running containers'),
    (icon: LucideIcons.wifi, text: 'Check network connectivity'),
    (icon: LucideIcons.memoryStick, text: 'Analyze memory usage'),
  ];

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final colorScheme = shadTheme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo / icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  LucideIcons.terminal,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Fewshell',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'AI-assisted terminal for on-call infrastructure\nmanagement and troubleshooting.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // "Try asking" label
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Try asking',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              // Prompt cards
              ...List.generate(_examplePrompts.length, (i) {
                final prompt = _examplePrompts[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PromptCard(
                    icon: prompt.icon,
                    text: prompt.text,
                    onTap: () => onPromptSelected(prompt.text),
                    colorScheme: colorScheme,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptCard extends StatefulWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final ShadColorScheme colorScheme;

  const _PromptCard({
    required this.icon,
    required this.text,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? cs.muted : Colors.transparent,
            border: Border.all(color: cs.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(fontSize: 14, color: cs.foreground),
                ),
              ),
              Icon(LucideIcons.arrowRight, size: 16, color: cs.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
