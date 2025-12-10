import 'dart:io';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:decamp_agent/router.dart';
import 'package:decamp_agent/services/database_manager.dart';
import 'package:decamp_agent/certs.dart';

final _log = Logger('DecampAgent');

void main(List<String> args) async {
  // Configure logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final timestamp = record.time.toIso8601String();
    final level = record.level.name;
    final message = '$timestamp [$level] ${record.message}';
    if (record.level >= Level.SEVERE) {
      stderr.writeln(message);
      if (record.error != null) stderr.writeln(record.error);
      if (record.stackTrace != null) stderr.writeln(record.stackTrace);
    } else {
      stdout.writeln(message);
    }
  });

  try {
    // Initialize FFI for sqflite explicitly
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Get port from environment or use default
    final portEnv = Platform.environment['PORT'];
    final port = portEnv != null ? int.tryParse(portEnv) ?? 3123 : 3123;

    // Initialize DatabaseManager
    final dbManager = DatabaseManager('${Directory.current.path}/data');
    await dbManager.init();

    // Configure SecurityContext for mTLS
    _log.info('Initializing mTLS with embedded certificates');

    try {
      _log.info(_parseCertificateInfo(caCert, 'CA Certificate'));
    } catch (e) {
      _log.warning('Could not parse CA certificate details: $e');
      _log.info('CA Certificate PEM:\n$caCert');
    }

    try {
      _log.info(_parseCertificateInfo(serverCert, 'Server Certificate'));
    } catch (e) {
      _log.warning('Could not parse Server certificate details: $e');
      _log.info('Server Certificate PEM:\n$serverCert');
    }

    final securityContext = SecurityContext(withTrustedRoots: true)
      ..useCertificateChainBytes(utf8.encode(serverCert))
      ..usePrivateKeyBytes(utf8.encode(serverKey))
      ..setClientAuthoritiesBytes(utf8.encode(caCert));
    _log.info(
      'SecurityContext initialized successfully ${securityContext.toString()}',
    );

    // Add middleware for logging and CORS
    final handler = const shelf.Pipeline()
        .addMiddleware(
          shelf.logRequests(
            logger: (msg, isError) {
              if (isError) {
                _log.severe(msg);
              } else {
                _log.info(msg);
              }
            },
          ),
        )
        .addMiddleware(_corsMiddleware())
        .addHandler(createRouter(dbManager).call);

    // Start the server
    _log.info('Starting server on port $port...');

    // Use anyIPv6 with v6Only=false to listen on both IPv4 and IPv6
    // This ensures localhost works regardless of whether it resolves to 127.0.0.1 or ::1
    final server = await HttpServer.bindSecure(
      InternetAddress.anyIPv6,
      port,
      securityContext,
      requestClientCertificate: true,
      v6Only: false,
    );

    server.listen(
      (HttpRequest request) {
        try {
          final clientIp = request.connectionInfo?.remoteAddress.address;
          final cert = request.certificate;

          if (cert != null) {
            _log.info('Client connection from $clientIp');
            _log.info('  Client Cert Subject: ${cert.subject}');
            _log.info('  Client Cert Issuer:  ${cert.issuer}');
          } else {
            _log.warning(
              'Client connection from $clientIp - NO CERTIFICATE PRESENTED',
            );
          }
        } catch (e) {
          _log.warning('Error logging client info: $e');
        }

        shelf_io.handleRequest(request, handler);
      },
      onError: (e) {
        _log.severe('HttpServer stream error', e);
      },
    );

    final scheme = 'https';
    _log.info(
      '🚀 Decamp Agent server running on $scheme://${server.address.host}:${server.port}',
    );
    _log.info('Server serving...');
  } catch (e, st) {
    _log.severe('CRITICAL FAILURE', e, st);
    exit(1);
  }
}

String _parseCertificateInfo(String pem, String label) {
  try {
    // Remove PEM headers and newlines
    final lines = pem
        .split('\n')
        .where((line) => !line.startsWith('-----') && line.trim().isNotEmpty)
        .join('');
    final bytes = base64.decode(lines);

    final parser = ASN1Parser(bytes);
    final topSequence = parser.nextObject() as ASN1Sequence;
    final tbsCertificate = topSequence.elements[0] as ASN1Sequence;

    // Iterate through TBSCertificate elements to find Subject and Issuer
    // Structure varies slightly by version, but usually:
    // [0] Version (optional)
    // [1] Serial Number
    // [2] Signature Algorithm
    // [3] Issuer (Sequence)
    // [4] Validity (Sequence)
    // [5] Subject (Sequence)

    // We'll look for Sequences that look like DNs (Distinguished Names)
    // A simple heuristic: The 4th sequence is usually Issuer, 6th is Subject (if version is present)

    // Let's just try to find them by inspecting elements
    String issuer = 'Unknown';
    String subject = 'Unknown';
    String validFrom = 'Unknown';
    String validTo = 'Unknown';

    // Skip version (tagged 0) if present
    int index = 0;
    if ((tbsCertificate.elements[0].tag & 0xC0) == 0x80) {
      index++; // Skip version
    }
    index++; // Skip Serial Number (Integer)
    index++; // Skip Signature (Sequence)

    if (index < tbsCertificate.elements.length) {
      final issuerSeq = tbsCertificate.elements[index];
      if (issuerSeq is ASN1Sequence) {
        issuer = _formatDN(issuerSeq);
      }
      index++; // Move to Validity
    }

    if (index < tbsCertificate.elements.length) {
      final validitySeq = tbsCertificate.elements[index];
      if (validitySeq is ASN1Sequence && validitySeq.elements.length >= 2) {
        validFrom = _formatTime(validitySeq.elements[0]);
        validTo = _formatTime(validitySeq.elements[1]);
      }
      index++; // Move to Subject
    }

    if (index < tbsCertificate.elements.length) {
      final subjectSeq = tbsCertificate.elements[index];
      if (subjectSeq is ASN1Sequence) {
        subject = _formatDN(subjectSeq);
      }
    }

    return '$label Details:\n  Subject:    $subject\n  Issuer:     $issuer\n  Valid From: $validFrom\n  Valid To:   $validTo';
  } catch (e) {
    return 'Error parsing certificate: $e';
  }
}

String _formatTime(ASN1Object time) {
  if (time is ASN1UtcTime) {
    return time.dateTimeValue.toIso8601String();
  } else if (time is ASN1GeneralizedTime) {
    return time.dateTimeValue.toIso8601String();
  }
  return 'Unknown Time Format';
}

String _formatDN(ASN1Sequence dnSequence) {
  final parts = <String>[];
  for (final set in dnSequence.elements) {
    if (set is ASN1Set && set.elements.isNotEmpty) {
      final seq = set.elements.first as ASN1Sequence;
      if (seq.elements.length >= 2) {
        final oid = seq.elements[0] as ASN1ObjectIdentifier;
        final value = seq.elements[1];

        String label = oid.identifier ?? 'Unknown';
        // Map common OIDs to names
        if (label == '2.5.4.3') {
          label = 'CN';
        } else if (label == '2.5.4.10') {
          label = 'O';
        } else if (label == '2.5.4.11') {
          label = 'OU';
        } else if (label == '2.5.4.6') {
          label = 'C';
        } else if (label == '2.5.4.8') {
          label = 'ST';
        } else if (label == '2.5.4.7') {
          label = 'L';
        }

        String valStr = '';
        if (value is ASN1UTF8String) {
          valStr = value.utf8StringValue;
        } else if (value is ASN1PrintableString) {
          valStr = value.stringValue;
        } else if (value is ASN1IA5String) {
          valStr = value.stringValue;
        } else {
          valStr = value.toString();
        }

        parts.add('$label=$valStr');
      }
    }
  }
  return parts.join(', ');
}

/// CORS middleware for cross-origin requests
shelf.Middleware _corsMiddleware() {
  return shelf.createMiddleware(
    requestHandler: (shelf.Request request) {
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('', headers: _corsHeaders);
      }
      return null;
    },
    responseHandler: (shelf.Response response) {
      return response.change(headers: _corsHeaders);
    },
  );
}

final _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};
