import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/providers.dart';

class AgentInstructionPreviewModal extends ConsumerStatefulWidget {
  final String instruction;

  const AgentInstructionPreviewModal({required this.instruction, super.key});

  static Future<void> show(BuildContext context, String instruction) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            AgentInstructionPreviewModal(instruction: instruction),
      ),
    );
  }

  @override
  ConsumerState<AgentInstructionPreviewModal> createState() =>
      _AgentInstructionPreviewModalState();
}

class _AgentInstructionPreviewModalState
    extends ConsumerState<AgentInstructionPreviewModal> {
  bool _previewMarkdown = true;
  String? _processedText;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Always process the template when the modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContext();
    });
  }

  Future<void> _loadContext() async {
    if (_processedText != null) return;

    setState(() => _isLoading = true);

    try {
      final llmService = ref.read(llmServiceProvider);
      final processed = await llmService.processTemplate(widget.instruction);

      if (mounted) {
        setState(() {
          _processedText = processed;
        });
      }
    } catch (e) {
      debugPrint('Error loading preview context: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instruction Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ],
                ShadCheckbox(
                  value: _previewMarkdown,
                  onChanged: (value) {
                    setState(() {
                      _previewMarkdown = value;
                    });
                  },
                  label: const Text('Preview Markdown'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectionArea(
                contextMenuBuilder: (context, selectableRegionState) {
                  try {
                    return AdaptiveTextSelectionToolbar.selectableRegion(
                      selectableRegionState: selectableRegionState,
                    );
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                },
                child: _previewMarkdown
                    ? GptMarkdown(_processedText ?? widget.instruction)
                    : SelectableText(_processedText ?? widget.instruction),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
