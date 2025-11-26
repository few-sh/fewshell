import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'secure_storage.dart';

class FileSecureStorageImpl implements SecureStorage {
  final File _file;
  Map<String, String>? _cache;

  FileSecureStorageImpl({File? file}) : _file = file ?? _getDefaultFile();

  static File _getDefaultFile() {
    String? home;
    if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'];
    } else {
      home = Platform.environment['HOME'];
    }

    if (home == null) {
      throw Exception('Could not find home directory');
    }

    final dir = Directory(p.join(home, '.decamp'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File(p.join(dir.path, 'secrets.json'));
  }

  Future<Map<String, String>> _readMap() async {
    if (_cache != null) return _cache!;

    if (!await _file.exists()) {
      _cache = {};
      return _cache!;
    }

    try {
      final content = await _file.readAsString();
      if (content.isEmpty) {
        _cache = {};
        return _cache!;
      }
      final json = jsonDecode(content) as Map<String, dynamic>;
      _cache = json.map((key, value) => MapEntry(key, value.toString()));
      return _cache!;
    } catch (e) {
      // If file is corrupted, return empty or throw?
      // For now, return empty but log error if we had a logger
      _cache = {};
      return _cache!;
    }
  }

  Future<void> _writeMap(Map<String, String> map) async {
    _cache = map;
    await _file.writeAsString(jsonEncode(map));
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final map = await _readMap();
    map[key] = value;
    await _writeMap(map);
  }

  @override
  Future<String?> read({required String key}) async {
    final map = await _readMap();
    return map[key];
  }

  @override
  Future<void> delete({required String key}) async {
    final map = await _readMap();
    if (map.containsKey(key)) {
      map.remove(key);
      await _writeMap(map);
    }
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map.from(await _readMap());
  }

  @override
  Future<void> deleteAll() async {
    await _writeMap({});
  }
}
