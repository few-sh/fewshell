import 'package:agent_core/src/utils/template_processor.dart';
import 'package:test/test.dart';

void main() {
  group('TemplateProcessor', () {
    test('processes simple variable substitution', () {
      final result = TemplateProcessor.process(
        'Secrets: {{ SECRETS_LIST }}',
        secretNames: ['A', 'B'],
      );
      expect(result, 'Secrets: A, B');
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
        'Secrets: {{ SECRETS_LIST }}',
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
