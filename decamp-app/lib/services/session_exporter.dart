import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:agent_core/agent_core.dart';
import 'package:decamp/providers/database_provider.dart';

/// Provider for the SessionExporter service
final sessionExporterProvider = Provider<SessionExporter>((ref) {
  final messageDao = ref.read(databaseProvider).messageDao;
  return SessionExporter(messageDao: messageDao);
});

/// Service specific errors for SessionExporter
class SessionExportException implements Exception {
  final String message;
  final dynamic originalError;

  SessionExportException(this.message, [this.originalError]);

  @override
  String toString() =>
      'SessionExportException: $message ${originalError ?? ""}';
}

/// Service module for exporting session data
class SessionExporter {
  final MessageDao _messageDao;

  SessionExporter({required MessageDao messageDao}) : _messageDao = messageDao;

  /// Exports session messages to a JSON file.
  ///
  /// Returns the written [File] object.
  /// Throws [SessionExportException] if export fails.
  Future<File> exportSessionToJson(String sessionId) async {
    try {
      final messages = await _messageDao.getMessagesBySession(sessionId);

      if (messages.isEmpty) {
        throw SessionExportException('Cannot export empty session');
      }

      final List<Map<String, dynamic>> jsonList = messages
          .map((m) => m.toJson())
          .toList();
      final content = const JsonEncoder.withIndent('  ').convert(jsonList);

      final fileName =
          'session_${sessionId}_${DateTime.now().millisecondsSinceEpoch}.json';

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      return await file.writeAsString(content);
    } catch (e, stackTrace) {
      if (e is SessionExportException) rethrow;
      // Wrap other errors
      throw SessionExportException('Failed to export session: $e', stackTrace);
    }
  }
}
