/// Recursively remove null values from a map
Map<String, dynamic> removeNullsFromMap(Map<String, dynamic> map) {
  final newMap = <String, dynamic>{};
  map.forEach((key, value) {
    if (value != null) {
      if (value is Map) {
        newMap[key] = removeNullsFromMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        newMap[key] = value.map((e) {
          if (e is Map) {
            return removeNullsFromMap(Map<String, dynamic>.from(e));
          }
          return e;
        }).toList();
      } else {
        newMap[key] = value;
      }
    }
  });
  return newMap;
}
