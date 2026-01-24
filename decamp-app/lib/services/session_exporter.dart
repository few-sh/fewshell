import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:agent_core/agent_core.dart';
import 'providers/providers.dart';

import 'package:decamp/utils/message_formatter.dart';
import 'package:file_selector/file_selector.dart';

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
  /// Returns the written [File] object, or null if cancelled.
  /// Throws [SessionExportException] if export fails.
  Future<File?> exportSessionToJson(String sessionId) async {
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

      String? path;

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'JSON',
              extensions: ['json'],
              mimeTypes: ['application/json'],
            ),
          ],
        );
        path = result?.path;
        if (path == null) return null;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        path = '${directory.path}/$fileName';
      }

      final file = File(path);

      return await file.writeAsString(content);
    } catch (e, stackTrace) {
      if (e is SessionExportException) rethrow;
      // Wrap other errors
      throw SessionExportException('Failed to export session: $e', stackTrace);
    }
  }

  /// Exports session messages to a Markdown file.
  ///
  /// Returns the written [File] object, or null if cancelled.
  /// Throws [SessionExportException] if export fails.
  Future<File?> exportSessionToMarkdown(String sessionId) async {
    try {
      final messages = await _messageDao.getMessagesBySession(sessionId);

      if (messages.isEmpty) {
        throw SessionExportException('Cannot export empty session');
      }

      final buffer = StringBuffer();
      buffer.writeln('# Session Export');
      buffer.writeln('Session ID: $sessionId');
      buffer.writeln('Date: ${DateTime.now().toLocal()}');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();

      for (final msg in messages) {
        final content = MessageFormatter.formatMessageContent(msg);
        buffer.writeln(content);
        buffer.writeln();

        buffer.writeln('${msg.userName} | ${msg.timestamp.toLocal()}');
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
        buffer.writeln();
      }

      final content = buffer.toString();
      final fileName =
          'session_${sessionId}_${DateTime.now().millisecondsSinceEpoch}.md';

      String? path;

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'Markdown',
              extensions: ['md'],
              mimeTypes: ['text/markdown', 'text/plain'],
            ),
          ],
        );
        path = result?.path;
        if (path == null) return null;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        path = '${directory.path}/$fileName';
      }

      final file = File(path);

      return await file.writeAsString(content);
    } catch (e, stackTrace) {
      if (e is SessionExportException) rethrow;
      throw SessionExportException('Failed to export session: $e', stackTrace);
    }
  }
}
