import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decamp/providers/user_provider.dart';
import 'package:decamp/utils/globals.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../utils/ui_utils.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  String _feedbackType = 'bug'; // 'feature' or 'bug'
  final _textController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _includeLogs = true;
  bool _canContact = true;
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
    _textController.addListener(_saveState);
    _nameController.addListener(_saveState);
    _emailController.addListener(_saveState);
  }

  @override
  void dispose() {
    _textController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      final savedName = prefs.getString('feedback_name');
      if (savedName == null) {
        _nameController.text = ref.read(userProvider);
      } else {
        _nameController.text = savedName;
      }

      _emailController.text = prefs.getString('feedback_email') ?? '';
      _feedbackType = prefs.getString('feedback_type') ?? 'bug';
      _textController.text = prefs.getString('feedback_text') ?? '';
      _includeLogs = prefs.getBool('feedback_include_logs') ?? true;
      _canContact = prefs.getBool('feedback_can_contact') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feedback_name', _nameController.text);
    await prefs.setString('feedback_email', _emailController.text);
    await prefs.setString('feedback_type', _feedbackType);
    await prefs.setString('feedback_text', _textController.text);
    await prefs.setBool('feedback_include_logs', _includeLogs);
    await prefs.setBool('feedback_can_contact', _canContact);
  }

  Future<void> _clearTransientState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('feedback_type');
    await prefs.remove('feedback_text');
    await prefs.remove('feedback_include_logs');
    await prefs.remove('feedback_can_contact');
    // Name and email are kept
  }

  Future<void> _submit() async {
    if (_textController.text.trim().isEmpty) {
      ShadToaster.of(
        context,
      ).show(const ShadToast(description: Text('Please enter some feedback')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FeedbackSubmitter.submitFeedback(
        type: _feedbackType,
        text: _textController.text,
        includeLogs: _feedbackType == 'bug' && _includeLogs,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        canContact: _canContact,
        logger: globalSqliteLogger,
      );

      await _clearTransientState();

      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast(description: Text('Feedback submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Error submitting feedback: $e'),
            action: ShadButton.destructive(
              child: const Text('Dismiss'),
              onPressed: () => ShadToaster.of(context).hide(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Feedback', style: theme.textTheme.h4),
        leading: ShadButton.ghost(
          child: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadInput(
              contextMenuBuilder: adaptiveContextMenuBuilder,
              controller: _nameController,
              placeholder: const Text('Name (optional)'),
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            ShadInput(
              contextMenuBuilder: adaptiveContextMenuBuilder,
              controller: _emailController,
              placeholder: const Text('Email (optional)'),
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ShadButton(
                    onPressed: () {
                      setState(() {
                        _feedbackType = 'bug';
                      });
                      _saveState();
                    },
                    backgroundColor: _feedbackType == 'bug'
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                    foregroundColor: _feedbackType == 'bug'
                        ? theme.colorScheme.primaryForeground
                        : theme.colorScheme.secondaryForeground,
                    child: const Text('Bug Report'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton(
                    onPressed: () {
                      setState(() {
                        _feedbackType = 'feature';
                      });
                      _saveState();
                    },
                    backgroundColor: _feedbackType == 'feature'
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                    foregroundColor: _feedbackType == 'feature'
                        ? theme.colorScheme.primaryForeground
                        : theme.colorScheme.secondaryForeground,
                    child: const Text('Feature Request'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ShadInput(
              contextMenuBuilder: adaptiveContextMenuBuilder,
              controller: _textController,
              minLines: 7,
              maxLines: 7,
              placeholder: const Text('Describe your feedback here...'),
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ShadCheckbox(
                  value: _canContact,
                  onChanged: (value) {
                    setState(() {
                      _canContact = value;
                    });
                    _saveState();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _canContact = !_canContact;
                      });
                      _saveState();
                    },
                    child: const Text(
                      'Allow the team to contact me about my feedback',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ShadCheckbox(
                  value: _feedbackType == 'bug' ? _includeLogs : false,
                  enabled: _feedbackType == 'bug',
                  onChanged: (value) {
                    setState(() {
                      _includeLogs = value;
                    });
                    _saveState();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _feedbackType == 'bug'
                        ? () {
                            setState(() {
                              _includeLogs = !_includeLogs;
                            });
                            _saveState();
                          }
                        : null,
                    child: Text(
                      'Include debug logs',
                      style: TextStyle(
                        color: _feedbackType == 'bug'
                            ? theme.colorScheme.foreground
                            : theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ShadButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
