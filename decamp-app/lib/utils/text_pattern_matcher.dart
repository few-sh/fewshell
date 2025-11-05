/// Utility for matching text patterns like API keys and URLs
class TextPatternMatcher {
  /// Regex pattern for detecting API keys
  /// Matches common formats:
  /// - OpenAI style: sk-...
  /// - Generic: api_key_..., apikey:..., etc.
  /// - Long alphanumeric strings (32+ chars)
  static final RegExp apiKeyPattern = RegExp(
    r'(?:sk-[A-Za-z0-9]{20,})|'
    r'(?:api[_-]?key[_:\s]*[A-Za-z0-9]{20,})|'
    r'(?:[A-Za-z0-9]{32,})',
    caseSensitive: false,
  );

  /// Regex pattern for detecting URLs
  /// Matches http:// and https:// URLs even when embedded in surrounding text
  static final RegExp urlPattern = RegExp(
    // Allow one or two slashes after the protocol and tolerate stray
    // backslashes/spaces that OCR sometimes inserts. We'll also
    // normalize the input before matching.
    // This pattern can match URLs anywhere in the text, not just at the start.
    r'https?:/{1,2}[ \t\\/]*[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?'
    r'\.[a-zA-Z]{2,}(?:[\/\w\.\-~:/?#\[\]@!$&()*+,;=%]*)?',
    caseSensitive: false,
  );

  /// Try to repair common OCR mistakes in URLs before applying regex.
  ///
  /// Repairs handled:
  /// - `https:/` or `https:\` or `https: /` -> `https://`
  /// - single slash after protocol -> double slash
  /// - common mistaken characters for slash (\, |, ;, l, 1, I, fullwidth ／)
  /// - strips surrounding text to isolate the URL
  static String normalizeUrl(String text) {
    var t = text.trim();

    // Replace common mistaken slash-like characters with `/`
    // OCR often confuses / with: \, |, ;, l (lowercase L), 1 (digit one), I (uppercase i)
    t = t.replaceAll(RegExp(r'[\\|;]+'), '/');
    t = t.replaceAll('／', '/'); // fullwidth slash

    // In the protocol area specifically, also fix l, 1, I that look like /
    // Match variations like "https:ll", "https:11", "https:II", "httpsl/", etc.
    t = t.replaceAllMapped(
      RegExp(r'^(.*?)(https?):([:\s\\/lI1]{1,6})', caseSensitive: false),
      (m) {
        var protocol = m.group(2)!.toLowerCase();
        // Strip any prefix text before the protocol
        return '$protocol://';
      },
    );

    // Also catch cases where the protocol itself wasn't at the start
    // e.g., "some text https:ll example.com"
    t = t.replaceAllMapped(
      RegExp(r'(https?):([:\s\\/lI1]{1,6})', caseSensitive: false),
      (m) => '${m.group(1)!.toLowerCase()}://',
    );

    return t;
  }

  /// Check if text matches API key pattern
  static bool isApiKey(String text) {
    final match = apiKeyPattern.firstMatch(text.trim());
    if (match == null) return false;

    // Ensure the match covers most of the text (not just a substring)
    final matchedText = match.group(0) ?? '';
    final cleanedText = text.trim();
    return matchedText.length >= cleanedText.length * 0.7;
  }

  /// Check if text matches URL pattern
  static bool isUrl(String text) {
    final cleaned = normalizeUrl(text);
    final match = urlPattern.firstMatch(cleaned);
    if (match == null) return false;

    // For URLs, we're more lenient - just check if we found a valid URL
    // somewhere in the text (it doesn't need to cover 70% since URLs
    // can be embedded in surrounding text that OCR picked up)
    final matchedText = match.group(0) ?? '';
    // URL must be at least 10 chars (e.g., "http://a.co")
    return matchedText.length >= 10;
  }

  /// Extract the matched portion from text based on pattern
  static String? extractMatch(String text, ScanType scanType) {
    final pattern = scanType == ScanType.apiKey ? apiKeyPattern : urlPattern;
    final input = scanType == ScanType.url ? normalizeUrl(text) : text.trim();
    final match = pattern.firstMatch(input);
    return match?.group(0);
  }

  /// Get the appropriate pattern based on scan type
  static RegExp getPattern(ScanType scanType) {
    return scanType == ScanType.apiKey ? apiKeyPattern : urlPattern;
  }
}

/// Type of text being scanned for
enum ScanType { apiKey, url }
