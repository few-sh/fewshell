import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as nacl;

/// Result of SSH key pair generation.
///
/// Holds both the raw key bytes and the formatted OpenSSH strings.
/// Call [dispose] when done to zero out sensitive key material in memory.
class SshKeyPairResult {
  /// Raw 32-byte ed25519 seed (private key seed).
  final Uint8List privateSeed;

  /// Raw 64-byte ed25519 private key (seed || public key), as used by OpenSSH.
  final Uint8List privateKeyBytes;

  /// Raw 32-byte ed25519 public key.
  final Uint8List publicKeyBytes;

  /// Private key in OpenSSH PEM format (-----BEGIN OPENSSH PRIVATE KEY-----).
  final String privatePem;

  /// Public key in OpenSSH authorized_keys format: `ssh-ed25519 <base64> <comment>`
  final String publicKeyString;

  /// SHA-256 fingerprint in the format `SHA256:<base64>`.
  final String fingerprint;

  /// Randomart visualization of the public key (similar to `ssh-keygen -lv`).
  final String randomart;

  /// Comment embedded in the key.
  final String comment;

  bool _disposed = false;

  SshKeyPairResult({
    required this.privateSeed,
    required this.privateKeyBytes,
    required this.publicKeyBytes,
    required this.privatePem,
    required this.publicKeyString,
    required this.fingerprint,
    required this.randomart,
    required this.comment,
  });

  /// Zeros out sensitive key material (seed and private key bytes).
  /// After calling this, [privateSeed] and [privateKeyBytes] contain only zeros.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _zeroFill(privateSeed);
    _zeroFill(privateKeyBytes);
  }

  static void _zeroFill(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
}

/// Service for generating ed25519 SSH key pairs in OpenSSH format.
///
/// Produces keys compatible with `~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub`.
/// Uses the `pinenacl` library (via dartssh2) for ed25519 cryptography.
class SshKeygenService {
  /// Generates a new ed25519 SSH key pair.
  ///
  /// [comment] is embedded in both the private and public key files.
  /// Conventionally this is `user@hostname`.
  ///
  /// Returns an [SshKeyPairResult] containing the key material in multiple
  /// formats. The caller is responsible for calling [SshKeyPairResult.dispose]
  /// when the key material is no longer needed.
  SshKeyPairResult generate({String comment = ''}) {
    // Generate a new ed25519 signing key (random 32-byte seed).
    final signingKey = nacl.SigningKey.generate();

    // Extract the 32-byte seed (the true private secret).
    final seed = Uint8List.fromList(signingKey.seed);

    // The full 64-byte private key as OpenSSH stores it: seed || publicKey.
    final publicKeyRaw = Uint8List.fromList(signingKey.publicKey);
    final privateKeyFull = Uint8List(64);
    privateKeyFull.setRange(0, 32, seed);
    privateKeyFull.setRange(32, 64, publicKeyRaw);

    // Build the OpenSSH key pair structure.
    final keyPair = OpenSSHEd25519KeyPair(
      publicKeyRaw,
      privateKeyFull,
      comment,
    );

    // Private key PEM.
    final privatePem = keyPair.toPem();

    // Public key in authorized_keys format.
    final publicKeyEncoded = keyPair.toPublicKey().encode();
    final publicKeyBase64 = base64.encode(publicKeyEncoded);
    final publicKeyString = comment.isNotEmpty
        ? 'ssh-ed25519 $publicKeyBase64 $comment'
        : 'ssh-ed25519 $publicKeyBase64';

    // SHA-256 fingerprint (matches `ssh-keygen -l -E sha256`).
    final digest = crypto.sha256.convert(publicKeyEncoded);
    // ssh-keygen uses unpadded base64 for the fingerprint.
    final fingerprintBase64 =
        base64.encode(digest.bytes).replaceAll(RegExp(r'=+$'), '');
    final fingerprint = 'SHA256:$fingerprintBase64';

    // Randomart visualization.
    final randomart = _generateRandomart(
      Uint8List.fromList(digest.bytes),
      'ED25519',
      256,
    );

    return SshKeyPairResult(
      privateSeed: seed,
      privateKeyBytes: privateKeyFull,
      publicKeyBytes: publicKeyRaw,
      privatePem: privatePem,
      publicKeyString: publicKeyString,
      fingerprint: fingerprint,
      randomart: randomart,
      comment: comment,
    );
  }

  /// Reconstructs an [SshKeyPairResult] from a stored OpenSSH PEM string.
  ///
  /// This derives the public key, fingerprint, and randomart from the
  /// private key material in the PEM. Useful for loading a previously
  /// generated key from secure storage without regenerating.
  SshKeyPairResult fromPem(String pem) {
    final pairs = SSHKeyPair.fromPem(pem);
    if (pairs.isEmpty) {
      throw ArgumentError('No key pairs found in PEM');
    }
    final pair = pairs.first;
    if (pair is! OpenSSHEd25519KeyPair) {
      throw ArgumentError(
        'Expected ed25519 key, got ${pair.runtimeType}',
      );
    }

    final publicKeyRaw = Uint8List.fromList(pair.publicKey);
    final privateKeyFull = Uint8List.fromList(pair.privateKey);
    final seed = Uint8List.fromList(privateKeyFull.sublist(0, 32));
    final comment = pair.comment;

    // Rebuild public key string.
    final publicKeyEncoded = pair.toPublicKey().encode();
    final publicKeyBase64 = base64.encode(publicKeyEncoded);
    final publicKeyString = comment.isNotEmpty
        ? 'ssh-ed25519 $publicKeyBase64 $comment'
        : 'ssh-ed25519 $publicKeyBase64';

    // SHA-256 fingerprint.
    final digest = crypto.sha256.convert(publicKeyEncoded);
    final fingerprintBase64 =
        base64.encode(digest.bytes).replaceAll(RegExp(r'=+$'), '');
    final fingerprint = 'SHA256:$fingerprintBase64';

    // Randomart.
    final randomart = _generateRandomart(
      Uint8List.fromList(digest.bytes),
      'ED25519',
      256,
    );

    return SshKeyPairResult(
      privateSeed: seed,
      privateKeyBytes: privateKeyFull,
      publicKeyBytes: publicKeyRaw,
      privatePem: pem,
      publicKeyString: publicKeyString,
      fingerprint: fingerprint,
      randomart: randomart,
      comment: comment,
    );
  }

  /// Generates the "Bishop" randomart visualization for an SSH key fingerprint.
  ///
  /// This implements the same algorithm as OpenSSH's `ssh-keygen -lv`,
  /// described in "The drunken bishop" paper by Dirk Loss, Tobias Limmer,
  /// and Alexander von Gernler (2009).
  ///
  /// The algorithm works by interpreting the fingerprint hash as a series
  /// of 2-bit moves on an 9x17 grid. A "bishop" starts at the center and
  /// moves diagonally based on each pair of bits. Each cell counts how many
  /// times it has been visited and is rendered using a character from a
  /// fixed alphabet.
  static String _generateRandomart(
    Uint8List hash,
    String keyType,
    int keyBits,
  ) {
    const rows = 9;
    const cols = 17;

    // The field tracks visit counts.
    final field = List.generate(rows, (_) => List.filled(cols, 0));

    // Start position: center of the field.
    var x = cols ~/ 2; // 8
    var y = rows ~/ 2; // 4

    // Process each byte of the hash as four 2-bit moves (LSB first).
    for (final byte in hash) {
      for (var shift = 0; shift < 8; shift += 2) {
        final move = (byte >> shift) & 0x03;

        // Diagonal moves: bit 0 = horizontal direction, bit 1 = vertical.
        if (move & 0x01 != 0) {
          x = min(x + 1, cols - 1);
        } else {
          x = max(x - 1, 0);
        }
        if (move & 0x02 != 0) {
          y = min(y + 1, rows - 1);
        } else {
          y = max(y - 1, 0);
        }

        field[y][x]++;
      }
    }

    // Character mapping for visit counts.
    // 0 visits = ' ', then ascending density. S = start, E = end.
    const chars = ' .o+=*BOX@%&#/^SE';

    // Build the ASCII art.
    final startX = cols ~/ 2;
    final startY = rows ~/ 2;
    final endX = x;
    final endY = y;

    final header = '[$keyType $keyBits]';
    final topBorder = '+${header.padRight(cols, '-')}+';
    final bottomBorder = '+${'-' * cols}+';

    final lines = <String>[topBorder];
    for (var row = 0; row < rows; row++) {
      final buf = StringBuffer('|');
      for (var col = 0; col < cols; col++) {
        if (row == startY && col == startX) {
          buf.write('S');
        } else if (row == endY && col == endX) {
          buf.write('E');
        } else {
          final visits = field[row][col];
          final charIndex = min(visits, chars.length - 3);
          buf.write(chars[charIndex]);
        }
      }
      buf.write('|');
      lines.add(buf.toString());
    }
    lines.add(bottomBorder);

    return lines.join('\n');
  }
}
