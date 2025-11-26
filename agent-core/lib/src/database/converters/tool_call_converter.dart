import 'dart:convert';
import 'dart:developer' as developer;
import 'package:drift/drift.dart';
import 'package:llm_dart/llm_dart.dart';

/// Type converter for `List<ToolCall>` to/from JSON string
/// Provides type-safe serialization of tool calls for database storage
class ToolCallListConverter extends TypeConverter<List<ToolCall>?, String?> {
  const ToolCallListConverter();

  @override
  List<ToolCall>? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) return null;

    try {
      final json = jsonDecode(fromDb) as List;
      return json
          .map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Log error but return null to prevent crashes
      developer.log(
        'Error deserializing tool calls: $e',
        name: 'ToolCallConverter',
      );
      return null;
    }
  }

  @override
  String? toSql(List<ToolCall>? value) {
    if (value == null || value.isEmpty) return null;

    try {
      return jsonEncode(value.map((tc) => tc.toJson()).toList());
    } catch (e) {
      // Log error but return null to prevent crashes
      developer.log(
        'Error serializing tool calls: $e',
        name: 'ToolCallConverter',
      );
      return null;
    }
  }
}
