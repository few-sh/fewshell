import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/snippet_provider.dart';
import '../providers/project_provider.dart';
import '../models/snippet.dart';

/// Snippets page with User and Project snippets tabs
class SnippetsPage extends ConsumerStatefulWidget {
  const SnippetsPage({super.key});

  @override
  ConsumerState<SnippetsPage> createState() => _SnippetsPageState();
}

class _SnippetsPageState extends ConsumerState<SnippetsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _newSnippetId; // Track if we're adding a new snippet

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snippets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Stationary tab bar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'User Snippets'),
                Tab(text: 'Project Snippets'),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildUserSnippets(), _buildProjectSnippets()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewSnippet,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addNewSnippet() {
    setState(() {
      _newSnippetId = 'new_${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  Widget _buildUserSnippets() {
    final snippetsAsync = ref.watch(globalSnippetsStreamProvider);

    return snippetsAsync.when(
      data: (snippets) => _buildSnippetsList(snippets, isGlobal: true),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading snippets: $error')),
    );
  }

  Widget _buildProjectSnippets() {
    final currentProjectId = ref.watch(currentProjectIdProvider);

    if (currentProjectId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No Project Selected',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Select a project to manage project-specific snippets.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final snippetsAsync = ref.watch(
      projectSnippetsStreamProvider(currentProjectId),
    );

    return snippetsAsync.when(
      data: (snippets) => _buildSnippetsList(snippets, isGlobal: false),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error loading snippets: $error')),
    );
  }

  Widget _buildSnippetsList(List<Snippet> snippets, {required bool isGlobal}) {
    final currentProjectId = ref.watch(currentProjectIdProvider);
    final notifier = isGlobal
        ? ref.read(globalSnippetsProvider.notifier)
        : (currentProjectId != null
              ? ref.read(projectSnippetsProvider(currentProjectId).notifier)
              : null);

    // Show empty state only if no snippets AND not adding a new one
    if (snippets.isEmpty && _newSnippetId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.code_off,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No Snippets Yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first snippet using the + button below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: snippets.length + (_newSnippetId != null ? 1 : 0),
      itemBuilder: (context, index) {
        // Show new snippet card at the top
        if (_newSnippetId != null && index == 0) {
          return _NewSnippetCard(
            key: ValueKey(_newSnippetId),
            isGlobal: isGlobal,
            onSave: (name, content, description) async {
              if (notifier != null) {
                try {
                  await notifier.addSnippet(
                    name: name,
                    content: content,
                    description: description.isEmpty ? null : description,
                  );
                  setState(() {
                    _newSnippetId = null;
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding snippet: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
            onCancel: () {
              setState(() {
                _newSnippetId = null;
              });
            },
          );
        }

        final snippetIndex = _newSnippetId != null ? index - 1 : index;
        final snippet = snippets[snippetIndex];

        return _buildSnippetCard(
          key: ValueKey(snippet.id),
          snippet: snippet,
          isGlobal: isGlobal,
          onDelete: () async {
            if (notifier != null) {
              await notifier.deleteSnippet(snippet.id);
            }
          },
        );
      },
    );
  }

  Widget _buildSnippetCard({
    required Key key,
    required Snippet snippet,
    required bool isGlobal,
    required VoidCallback onDelete,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      child: _SnippetCardContent(
        snippet: snippet,
        isGlobal: isGlobal,
        onDelete: onDelete,
      ),
    );
  }
}

/// Widget for creating a new snippet inline
class _NewSnippetCard extends StatefulWidget {
  final bool isGlobal;
  final Future<void> Function(String name, String content, String description)
  onSave;
  final VoidCallback onCancel;

  const _NewSnippetCard({
    super.key,
    required this.isGlobal,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_NewSnippetCard> createState() => _NewSnippetCardState();
}

class _NewSnippetCardState extends State<_NewSnippetCard> {
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus on name field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return; // Don't save if required fields are empty
    }

    setState(() => _isSaving = true);
    await widget.onSave(
      _nameController.text.trim(),
      _contentController.text.trim(),
      _descriptionController.text.trim(),
    );
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'New Snippet',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                    tooltip: 'Cancel',
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              decoration: InputDecoration(
                hintText: 'Snippet name (e.g., List pods)',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: 'Command (e.g., kubectl get pods)',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Save Snippet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying and editing a snippet inline
class _SnippetCardContent extends ConsumerStatefulWidget {
  final Snippet snippet;
  final bool isGlobal;
  final VoidCallback onDelete;

  const _SnippetCardContent({
    required this.snippet,
    required this.isGlobal,
    required this.onDelete,
  });

  @override
  ConsumerState<_SnippetCardContent> createState() =>
      _SnippetCardContentState();
}

class _SnippetCardContentState extends ConsumerState<_SnippetCardContent> {
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  late TextEditingController _descriptionController;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.snippet.name);
    _contentController = TextEditingController(text: widget.snippet.content);
    _descriptionController = TextEditingController(
      text: widget.snippet.description ?? '',
    );

    // Listen for changes
    _nameController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
    _descriptionController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _autoSave() async {
    if (!_hasChanges) return;
    if (_nameController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentProjectId = ref.read(currentProjectIdProvider);
      final notifier = widget.isGlobal
          ? ref.read(globalSnippetsProvider.notifier)
          : ref.read(projectSnippetsProvider(currentProjectId!).notifier);

      await notifier.updateSnippet(
        id: widget.snippet.id,
        name: _nameController.text.trim(),
        content: _contentController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(widget.snippet.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        widget.onDelete();
        return true;
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isSaving)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                else if (_hasChanges)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Snippet name',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    onSubmitted: (_) => _autoSave(),
                    onTapOutside: (_) => _autoSave(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onDelete,
                  tooltip: 'Delete',
                  iconSize: 20,
                  color: theme.colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                hintText: 'Command',
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: null,
              minLines: 2,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
              onSubmitted: (_) => _autoSave(),
              onTapOutside: (_) => _autoSave(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: null,
              minLines: 1,
              style: theme.textTheme.bodyMedium,
              onSubmitted: (_) => _autoSave(),
              onTapOutside: (_) => _autoSave(),
            ),
          ],
        ),
      ),
    );
  }
}
