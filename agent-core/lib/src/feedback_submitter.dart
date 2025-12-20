import 'dart:io';
import 'package:dio/dio.dart';
import 'services/sqlite_logger.dart';

class FeedbackSubmitter {
  static const String _feedbackUrl = 'https://shell-feedback-api.few.sh/submit';

  static Future<void> submitFeedback({
    required String type, // 'feature' or 'bug'
    required String text,
    bool includeLogs = false,
    String? name,
    String? email,
    bool canContact = false,
    SqliteLogger? logger,
  }) async {
    final dio = Dio();
    File? logFile;

    try {
      final Map<String, dynamic> dataMap = {
        'type': type,
        'text': text,
        'includeLogs': includeLogs,
        'name': name,
        'email': email,
        'canContact': canContact,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (includeLogs && logger != null) {
        try {
          logFile = await logger.createLogSnapshot();
          dataMap['logs'] = await MultipartFile.fromFile(
            logFile.path,
            filename: 'logs.db',
          );
        } catch (e) {
          // ignore: avoid_print
          print('Failed to attach logs: $e');
          // Continue without logs
        }
      }

      final formData = FormData.fromMap(dataMap);
      await dio.post(_feedbackUrl, data: formData);
    } finally {
      if (logFile != null) {
        try {
          if (await logFile.exists()) {
            // Delete the parent temp directory
            await logFile.parent.delete(recursive: true);
          }
        } catch (e) {
          // ignore: avoid_print
          print('Failed to cleanup log file: $e');
        }
      }
    }
  }
}
