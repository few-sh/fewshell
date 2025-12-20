import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      _nameController.text = prefs.getString('feedback_name') ?? '';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some feedback')),
      );
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
      );

      await _clearTransientState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Bug Report'),
                  selected: _feedbackType == 'bug',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _feedbackType = 'bug';
                      });
                      _saveState();
                    }
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Feature Request'),
                  selected: _feedbackType == 'feature',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _feedbackType = 'feature';
                      });
                      _saveState();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              minLines: 7,
              maxLines: 7,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Describe your feedback here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text(
                'Allow the team to contact me about my feedback',
              ),
              value: _canContact,
              onChanged: (value) {
                setState(() {
                  _canContact = value ?? false;
                });
                _saveState();
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Include debug logs'),
              value: _feedbackType == 'bug' ? _includeLogs : false,
              onChanged: _feedbackType == 'bug'
                  ? (value) {
                      setState(() {
                        _includeLogs = value ?? false;
                      });
                      _saveState();
                    }
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
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
