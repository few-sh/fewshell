import 'dart:async';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// Executes HTTP fetch requests.
///
/// Uses the http package which works on all Dart platforms (server and Flutter).
class FetchExecutor {
  final http.Client _client;

  FetchExecutor({http.Client? client}) : _client = client ?? http.Client();

  /// Execute an HTTP request
  ///
  /// [url] - The URL to fetch
  /// [method] - HTTP method (GET, POST, PUT, DELETE, etc.)
  /// [headers] - Optional HTTP headers
  /// [body] - Optional request body for POST/PUT
  /// [timeoutSeconds] - Request timeout in seconds (default 30)
  Future<Map<String, dynamic>> execute({
    required String url,
    String method = 'GET',
    Map<String, String>? headers,
    String? body,
    int timeoutSeconds = 30,
  }) async {
    developer.log(
      'Executing $method request to $url',
      name: 'FetchExecutor',
    );

    try {
      final uri = Uri.parse(url);
      final request = http.Request(method.toUpperCase(), uri);

      if (headers != null) {
        request.headers.addAll(headers);
      }

      if (body != null) {
        request.body = body;
        // Set content-type if not provided
        if (!request.headers.containsKey('content-type') &&
            !request.headers.containsKey('Content-Type')) {
          request.headers['content-type'] = 'application/json';
        }
      }

      final streamedResponse = await _client
          .send(request)
          .timeout(Duration(seconds: timeoutSeconds));

      final response = await http.Response.fromStream(streamedResponse);

      final statusCode = response.statusCode;
      final isSuccess = statusCode >= 200 && statusCode < 300;

      developer.log(
        'Request completed with status $statusCode',
        name: 'FetchExecutor',
      );

      return {
        'success': isSuccess,
        'data': {
          'statusCode': statusCode,
          'headers': response.headers,
          'body': response.body,
          'url': url,
          'method': method.toUpperCase(),
        },
        'error': isSuccess ? null : 'HTTP $statusCode',
      };
    } on TimeoutException {
      developer.log('Request timed out', name: 'FetchExecutor');
      return {
        'success': false,
        'data': {
          'statusCode': 0,
          'headers': <String, String>{},
          'body': '',
          'url': url,
          'method': method.toUpperCase(),
        },
        'error': 'Request timed out after $timeoutSeconds seconds',
      };
    } catch (e) {
      developer.log('Request failed: $e', name: 'FetchExecutor');
      return {
        'success': false,
        'data': {
          'statusCode': 0,
          'headers': <String, String>{},
          'body': '',
          'url': url,
          'method': method.toUpperCase(),
        },
        'error': e.toString(),
      };
    }
  }

  /// Close the HTTP client
  void close() {
    _client.close();
  }
}
