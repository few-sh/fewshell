import 'package:dio/dio.dart';

class FeedbackSubmitter {
  static const String _feedbackUrl = 'https://shell-feedback-api.few.sh/submit';

  static Future<void> submitFeedback({
    required String type, // 'feature' or 'bug'
    required String text,
    bool includeLogs = false,
    String? name,
    String? email,
    bool canContact = false,
  }) async {
    final dio = Dio();

    final data = {
      'type': type,
      'text': text,
      'includeLogs': includeLogs,
      'name': name,
      'email': email,
      'canContact': canContact,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await dio.post(_feedbackUrl, data: data);
  }
}
