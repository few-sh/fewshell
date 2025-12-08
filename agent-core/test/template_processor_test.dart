import 'package:agent_core/src/utils/template_processor.dart';
import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('TemplateProcessor', () {
    final testSnippet = SnippetEntity(
      id: '1',
      name: 'Test Snippet',
      content: 'echo "hello"',
      tags: 'test, demo',
      position: 0,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
    );

    test('processes list variable with join filter', () {
      final result = TemplateProcessor.process(
        "Secrets: {{ SECRETS|join(', ') }}",
        secretNames: ['A', 'B'],
      );
      expect(result, 'Secrets: A, B');
    });

    test('processes list variable iteration', () {
      final result = TemplateProcessor.process(
        "{% for secret in SECRETS %}- {{ secret }}\n{% endfor %}",
        secretNames: ['A', 'B'],
      );
      expect(result, '- A\n- B\n');
    });

    test('processes user snippets', () {
      final result = TemplateProcessor.process(
        '{% for s in USER_SNIPPETS %}{{ s.name }}: {{ s.content }}{% endfor %}',
        secretNames: [],
        userSnippets: [testSnippet],
      );
      expect(result, 'Test Snippet: echo "hello"');
    });

    test('processes project snippets', () {
      final result = TemplateProcessor.process(
        '{% for s in PROJECT_SNIPPETS %}{{ s.name }} ({{ s.tags }}){% endfor %}',
        secretNames: [],
        projectSnippets: [testSnippet],
      );
      expect(result, 'Test Snippet (test, demo)');
    });

    test('exposes all snippet fields', () {
      final result = TemplateProcessor.process(
        '{{ USER_SNIPPETS[0].createdAt }}',
        secretNames: [],
        userSnippets: [testSnippet],
      );
      expect(result, '2024-01-01T00:00:00.000');
    });

    test('handles empty text', () {
      final result = TemplateProcessor.process(
        '',
        secretNames: ['A'],
      );
      expect(result, '');
    });

    test('handles text without variables', () {
      final result = TemplateProcessor.process(
        'No secrets here',
        secretNames: ['A'],
      );
      expect(result, 'No secrets here');
    });

    test('handles empty secret list', () {
      final result = TemplateProcessor.process(
        "Secrets: {{ SECRETS|join(', ') }}",
        secretNames: [],
      );
      expect(result, 'Secrets: ');
    });

    test('hasTemplateVariables detects variables', () {
      expect(TemplateProcessor.hasTemplateVariables('{{ foo }}'), isTrue);
      expect(TemplateProcessor.hasTemplateVariables('no variables'), isFalse);
    });
  });
}
