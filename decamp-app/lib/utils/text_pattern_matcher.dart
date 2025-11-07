/// Utility for matching text patterns like API keys and URLs
///
// TODO: Add more key types, e.g., AWS, Azure, etc.
// ssh keys, sha1, sha256, etc.

class TextPatternMatcher {
  /// Regex pattern for detecting API keys
  /// Matches common formats:
  /// - OpenAI style: sk-...
  /// - Gemini style: AIza...
  /// - Generic: api_key_..., apikey:..., etc.
  /// - Long alphanumeric strings (32+ chars)
  static final RegExp apiKeyPattern = RegExp(
    r'(?:sk-[A-Za-z0-9]{20,})|'
    r'(?:AIza[A-Za-z0-9_\-]{35})|'
    r'(?:api[_-]?key[_:\s]*[A-Za-z0-9]{20,})|'
    r'(?:[A-Za-z0-9]{32,})',
    caseSensitive: false,
  );

  /// Regex pattern for detecting URLs
  /// Stricter pattern - requires complete domain and filters out ellipsis
  static final RegExp urlPattern = RegExp(
    r'https?://[a-zA-Z0-9][-a-zA-Z0-9]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}(?:[/\w\.\-~:?#\[\]@!$&()*+,;=%]*)?',
    caseSensitive: false,
  );

  /// Regex pattern for detecting SSH private keys
  /// Matches various SSH key formats:
  /// - RSA keys (-----BEGIN RSA PRIVATE KEY-----)
  /// - OpenSSH format (-----BEGIN OPENSSH PRIVATE KEY-----)
  /// - DSA keys (-----BEGIN DSA PRIVATE KEY-----)
  /// - EC keys (-----BEGIN EC PRIVATE KEY-----)
  /// - Generic encrypted keys (-----BEGIN ENCRYPTED PRIVATE KEY-----)
  static final RegExp sshKeyPattern = RegExp(
    r'-----BEGIN\s+(?:RSA|DSA|EC|OPENSSH|ENCRYPTED)?\s*PRIVATE\s+KEY-----[\s\S]*?-----END\s+(?:RSA|DSA|EC|OPENSSH|ENCRYPTED)?\s*PRIVATE\s+KEY-----',
    caseSensitive: false,
    multiLine: true,
  );

  /// Regex pattern for detecting hostnames and IP addresses
  /// Matches:
  /// - IPv4 addresses (e.g., 192.168.1.1)
  /// - IPv6 addresses (basic support)
  /// - Fully qualified domain names (e.g., example.com, sub.example.co.uk)
  /// - Hostnames with ports (e.g., example.com:8080, 192.168.1.1:22)
  static final RegExp hostnamePattern = RegExp(
    r'(?:'
    // IPv4 address with optional port
    r'(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(?::[0-9]{1,5})?'
    r'|'
    // IPv6 address (simplified pattern)
    r'\[?(?:[0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}\]?(?::[0-9]{1,5})?'
    r'|'
    // Domain name with optional port (requires at least one dot)
    r'(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(?::[0-9]{1,5})?'
    r')',
  );

  /// Check if text contains ellipsis or other indicators of incomplete text
  static bool hasEllipsisOrIncomplete(String text) {
    return text.contains('...') ||
        text.contains('…') || // Unicode ellipsis
        text.contains('..') ||
        text.endsWith('..');
  }

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
    // Reject URLs with ellipsis or incomplete indicators
    if (hasEllipsisOrIncomplete(text)) return false;

    final cleaned = normalizeUrl(text);
    final match = urlPattern.firstMatch(cleaned);
    if (match == null) return false;

    // URL must be at least 10 chars (e.g., "http://a.co")
    final matchedText = match.group(0) ?? '';
    return matchedText.length >= 10;
  }

  /// Check if text matches SSH private key pattern
  static bool isSshKey(String text) {
    final match = sshKeyPattern.firstMatch(text.trim());
    if (match == null) return false;

    // Must contain BEGIN and END markers
    final matchedText = match.group(0) ?? '';
    return matchedText.contains('BEGIN') && matchedText.contains('END');
  }

  /// Check if text matches hostname or IP address pattern
  static bool isHostname(String text) {
    final trimmed = text.trim();
    final match = hostnamePattern.firstMatch(trimmed);
    if (match == null) return false;

    // The match should be the entire trimmed text (or very close to it)
    final matchedText = match.group(0) ?? '';
    return matchedText.length >= trimmed.length * 0.8;
  }

  /// Extract the matched portion from text based on pattern
  static String? extractMatch(String text, ScanType scanType) {
    final RegExp pattern;
    String input;

    switch (scanType) {
      case ScanType.apiKey:
        pattern = apiKeyPattern;
        input = text.trim();
        break;
      case ScanType.url:
        pattern = urlPattern;
        input = normalizeUrl(text);
        break;
      case ScanType.sshKey:
        pattern = sshKeyPattern;
        input = text.trim();
        break;
      case ScanType.hostname:
        pattern = hostnamePattern;
        input = text.trim();
        break;
    }

    final match = pattern.firstMatch(input);
    return match?.group(0);
  }

  /// Get the appropriate pattern based on scan type
  static RegExp getPattern(ScanType scanType) {
    switch (scanType) {
      case ScanType.apiKey:
        return apiKeyPattern;
      case ScanType.url:
        return urlPattern;
      case ScanType.sshKey:
        return sshKeyPattern;
      case ScanType.hostname:
        return hostnamePattern;
    }
  }
}

/// Type of text being scanned for
enum ScanType { apiKey, url, sshKey, hostname }
