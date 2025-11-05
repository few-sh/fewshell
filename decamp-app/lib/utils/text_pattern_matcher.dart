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
  /// Matches http:// and https:// URLs
  static final RegExp urlPattern = RegExp(
    r'https?://[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?'
    r'\.[a-zA-Z]{2,}(?:/[\w\.\-~:/?#\[\]@!$&()*+,;=%]*)?',
    caseSensitive: false,
  );

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
    final match = urlPattern.firstMatch(text.trim());
    if (match == null) return false;

    // Ensure the match covers most of the text (not just a substring)
    final matchedText = match.group(0) ?? '';
    final cleanedText = text.trim();
    return matchedText.length >= cleanedText.length * 0.7;
  }

  /// Extract the matched portion from text based on pattern
  static String? extractMatch(String text, ScanType scanType) {
    final pattern = scanType == ScanType.apiKey ? apiKeyPattern : urlPattern;
    final match = pattern.firstMatch(text.trim());
    return match?.group(0);
  }

  /// Get the appropriate pattern based on scan type
  static RegExp getPattern(ScanType scanType) {
    return scanType == ScanType.apiKey ? apiKeyPattern : urlPattern;
  }
}

/// Type of text being scanned for
enum ScanType { apiKey, url }
