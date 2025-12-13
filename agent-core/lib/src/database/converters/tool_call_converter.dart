import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:drift/drift.dart';
import 'package:llm_dart/llm_dart.dart';

/// Type converter for `List<ToolCall>` to/from JSON string
/// Provides type-safe serialization of tool calls for database storage
class ToolCallListConverter extends TypeConverter<List<ToolCall>?, String?>
    implements JsonTypeConverter2<List<ToolCall>?, String?, Object?> {
  static final _log = Logger('ToolCallListConverter');

  const ToolCallListConverter();

  @override
  List<ToolCall>? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) return null;

    try {
      final json = jsonDecode(fromDb);
      return fromJson(json);
    } catch (e) {
      // Log error but return null to prevent crashes
      _log.warning(
        'Error deserializing tool calls: $e',
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
      _log.warning(
        'Error serializing tool calls: $e',
      );
      return null;
    }
  }

  @override
  List<ToolCall>? fromJson(Object? json) {
    if (json == null) return null;
    if (json is String) {
      return fromSql(json);
    }
    if (json is List) {
      return json.map((e) {
        if (e is! Map) {
          _log.warning('Unexpected tool call format: $e');
          throw FormatException('Tool call must be a Map');
        }
        final map = Map<String, dynamic>.from(e);

        // Fix for when arguments is a Map instead of a String (e.g. from some LLM providers or middleware)
        if (map['function'] != null && map['function'] is Map) {
          final functionMap = Map<String, dynamic>.from(map['function'] as Map);
          if (functionMap['arguments'] is Map) {
            functionMap['arguments'] = jsonEncode(functionMap['arguments']);
            map['function'] = functionMap;
          }
        }
        return ToolCall.fromJson(map);
      }).toList();
    }
    return null;
  }

  @override
  Object? toJson(List<ToolCall>? value) {
    if (value == null) return null;
    return value.map((tc) => tc.toJson()).toList();
  }
}
