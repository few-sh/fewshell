import 'package:agent_core/src/utils/template_processor.dart';
import 'package:test/test.dart';

void main() {
  group('TemplateProcessor', () {
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
