import 'package:dio/dio.dart';

class FetchTool {
  static Future<Map<String, dynamic>> execute(
      Map<String, dynamic> params) async {
    final url = params['url'] as String;
    final method = (params['method'] as String?)?.toUpperCase() ?? 'GET';
    final headers = params['headers'] as Map<String, dynamic>?;
    final body = params['body'] as String?;
    final timeoutSeconds = params['timeout'] as int? ?? 30;

    try {
      final dio = Dio();
      final response = await dio
          .request(
            url,
            data: body,
            options: Options(
              method: method,
              headers: headers,
              responseType: ResponseType.plain,
              validateStatus: (status) => true, // Accept all status codes
            ),
          )
          .timeout(Duration(seconds: timeoutSeconds));

      final isSuccess = response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;

      return {
        'success': isSuccess,
        'data': {
          'statusCode': response.statusCode ?? 0,
          'headers': response.headers.map,
          'body': response.data?.toString() ?? '',
          'url': url,
          'method': method,
        },
        'error': isSuccess ? null : 'HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'data': {
          'statusCode': 0,
          'headers': {},
          'body': '',
          'url': url,
          'method': method,
        },
        'error': e.toString(),
      };
    }
  }
}
