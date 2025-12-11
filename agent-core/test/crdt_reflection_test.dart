import 'dart:mirrors';
import 'package:logging/logging.dart';
import 'package:sql_crdt/sql_crdt.dart'; // Try importing sql_crdt directly
import 'package:test/test.dart';

final _log = Logger('CrdtReflectionTest');

void main() {
  test('Inspect SqlCrdt API', () {
    try {
      final mirror = reflectClass(SqlCrdt);
      _log.info('Methods of SqlCrdt:');
      for (var key in mirror.instanceMembers.keys) {
        _log.info(MirrorSystem.getName(key));
      }
    } catch (e) {
      _log.info('SqlCrdt not found: $e');
    }
  });
}
