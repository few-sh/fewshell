class SettingsFlattener {
  static Map<String, dynamic> flatten(Map<String, dynamic> json) {
    final result = <String, dynamic>{};
    _flattenRecursive(json, '', result);
    return result;
  }

  static void _flattenRecursive(
      dynamic current, String prefix, Map<String, dynamic> result) {
    if (current is Map) {
      current.forEach((key, value) {
        final escapedKey = _escape(key.toString());
        final newKey = prefix.isEmpty ? escapedKey : '$prefix.$escapedKey';
        _flattenRecursive(value, newKey, result);
      });
    } else if (current is List) {
      for (var i = 0; i < current.length; i++) {
        final item = current[i];
        String key;
        if (item is Map && item.containsKey('identifier')) {
          key = item['identifier'].toString();
        } else {
          key = i.toString();
        }
        final escapedKey = _escape(key);
        final newKey = prefix.isEmpty ? escapedKey : '$prefix.$escapedKey';
        _flattenRecursive(item, newKey, result);
      }
    } else {
      result[prefix] = current;
    }
  }

  static Map<String, dynamic> unflatten(Map<String, dynamic> flatMap) {
    final result = <String, dynamic>{};
    for (final entry in flatMap.entries) {
      _setPath(result, _splitPath(entry.key), entry.value);
    }
    return result;
  }

  static void _setPath(
      Map<String, dynamic> target, List<String> path, dynamic value) {
    if (path.isEmpty) return;
    final key = path.first;
    if (path.length == 1) {
      target[key] = value;
    } else {
      if (!target.containsKey(key) || target[key] is! Map) {
        target[key] = <String, dynamic>{};
      }
      _setPath(target[key], path.sublist(1), value);
    }
  }

  static String _escape(String key) {
    return key.replaceAll('\\', '\\\\').replaceAll('.', '\\.');
  }

  static List<String> _splitPath(String path) {
    final result = <String>[];
    var current = StringBuffer();
    var escaped = false;

    for (var i = 0; i < path.length; i++) {
      final char = path[i];
      if (escaped) {
        current.write(char);
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '.') {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }
}
