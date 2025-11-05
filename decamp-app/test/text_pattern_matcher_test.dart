import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world/utils/text_pattern_matcher.dart';

void main() {
  group('URL normalization and matching', () {
    test('normalizes basic slash variations', () {
      expect(
        TextPatternMatcher.normalizeUrl('https://example.com'),
        'https://example.com',
      );
      expect(
        TextPatternMatcher.normalizeUrl('https:/example.com'),
        'https://example.com',
      );
      expect(
        TextPatternMatcher.normalizeUrl('https:\\example.com'),
        'https://example.com',
      );
    });

    test('normalizes OCR slash mistakes (l, 1, I)', () {
      expect(
        TextPatternMatcher.normalizeUrl('https:llexample.com'),
        'https://example.com',
      );
      expect(
        TextPatternMatcher.normalizeUrl('https:11example.com'),
        'https://example.com',
      );
      expect(
        TextPatternMatcher.normalizeUrl('https:IIexample.com'),
        'https://example.com',
      );
      expect(
        TextPatternMatcher.normalizeUrl('https:l/example.com'),
        'https://example.com',
      );
    });

    test('strips prefix text', () {
      expect(
        TextPatternMatcher.normalizeUrl('some text https://example.com'),
        'https://example.com',
      );
      expect(
        TextPatternMatcher.normalizeUrl('URL: https:llexample.com'),
        'https://example.com',
      );
    });

    test('detects URLs with surrounding text', () {
      expect(TextPatternMatcher.isUrl('https://api.openai.com/v1'), true);
      expect(TextPatternMatcher.isUrl('URL: https://api.openai.com/v1'), true);
      expect(
        TextPatternMatcher.isUrl('some text https:llapi.openai.com/v1 more'),
        true,
      );
      expect(TextPatternMatcher.isUrl('https:IIexample.com'), true);
    });

    test('extracts clean URLs from messy OCR text', () {
      expect(
        TextPatternMatcher.extractMatch(
          'https:llapi.openai.com/v1',
          ScanType.url,
        ),
        'https://api.openai.com/v1',
      );
      expect(
        TextPatternMatcher.extractMatch(
          'URL: https://example.com some more text',
          ScanType.url,
        ),
        'https://example.com',
      );
    });

    test('rejects invalid URLs', () {
      expect(TextPatternMatcher.isUrl('not a url'), false);
      expect(TextPatternMatcher.isUrl('http'), false);
      expect(TextPatternMatcher.isUrl('random text'), false);
    });
  });

  group('API key matching', () {
    test('detects OpenAI style keys', () {
      expect(TextPatternMatcher.isApiKey('sk-1234567890abcdefghij'), true);
      expect(TextPatternMatcher.isApiKey('sk-proj-AbCdEfGhIjKlMnOpQrSt'), true);
    });

    test('detects generic api_key formats', () {
      expect(TextPatternMatcher.isApiKey('api_key_1234567890abcdefghij'), true);
      expect(TextPatternMatcher.isApiKey('apikey:1234567890abcdefghij'), true);
    });

    test('detects long alphanumeric strings', () {
      expect(
        TextPatternMatcher.isApiKey('abcdefghijklmnopqrstuvwxyz123456'),
        true,
      );
    });

    test('rejects short strings', () {
      expect(TextPatternMatcher.isApiKey('short'), false);
      expect(TextPatternMatcher.isApiKey('sk-tiny'), false);
    });
  });
}
