/// Semantic version comparison utility (semver.org).
///
/// Supports the format: MAJOR.MINOR.PATCH[-prerelease][+build]
/// Build metadata is ignored for comparisons per the semver spec.
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  /// Pre-release identifiers, e.g. ["alpha", "1"] for "1.0.0-alpha.1".
  final List<String> preRelease;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = const [],
  });

  /// Parses a semver string. Throws [FormatException] if invalid.
  factory SemanticVersion.parse(String version) {
    // Strip build metadata
    final withoutBuild = version.split('+').first;
    final parts = withoutBuild.split('-');
    final corePart = parts[0];
    final preReleasePart = parts.length > 1 ? parts.sublist(1).join('-') : null;

    final coreSegments = corePart.split('.');
    if (coreSegments.length != 3) {
      throw FormatException('Invalid semver: "$version"');
    }

    final major = int.tryParse(coreSegments[0]);
    final minor = int.tryParse(coreSegments[1]);
    final patch = int.tryParse(coreSegments[2]);

    if (major == null || minor == null || patch == null) {
      throw FormatException('Invalid semver: "$version"');
    }

    final preRelease =
        preReleasePart != null ? preReleasePart.split('.') : <String>[];

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preRelease,
    );
  }

  /// Returns `null` if [version] cannot be parsed.
  static SemanticVersion? tryParse(String version) {
    try {
      return SemanticVersion.parse(version);
    } on FormatException {
      return null;
    }
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // A version without pre-release has higher precedence than one with it.
    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;

    // Compare pre-release identifiers left-to-right.
    final len =
        preRelease.length < other.preRelease.length
            ? preRelease.length
            : other.preRelease.length;
    for (var i = 0; i < len; i++) {
      final a = preRelease[i];
      final b = other.preRelease[i];
      final result = _compareIdentifier(a, b);
      if (result != 0) return result;
    }

    return preRelease.length.compareTo(other.preRelease.length);
  }

  /// Numeric identifiers have lower precedence than alphanumeric ones (semver §11).
  static int _compareIdentifier(String a, String b) {
    final aNum = int.tryParse(a);
    final bNum = int.tryParse(b);

    if (aNum != null && bNum != null) return aNum.compareTo(bNum);
    if (aNum != null) return -1; // numeric < alphanumeric
    if (bNum != null) return 1;
    return a.compareTo(b);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    return preRelease.isEmpty ? base : '$base-${preRelease.join('.')}';
  }
}
