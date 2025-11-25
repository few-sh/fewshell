import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Health check endpoint handler
Response healthHandler(Request request) {
  final response = {
    'status': 'healthy',
    'service': 'decamp-agent',
    'timestamp': DateTime.now().toIso8601String(),
  };

  return Response.ok(
    jsonEncode(response),
    headers: {'Content-Type': 'application/json'},
  );
}
