import 'dart:mirrors';
import 'dart:developer' as developer;
import 'package:sql_crdt/sql_crdt.dart'; // Try importing sql_crdt directly
import 'package:test/test.dart';

void main() {
  test('Inspect SqlCrdt API', () {
    try {
      final mirror = reflectClass(SqlCrdt);
      developer.log('Methods of SqlCrdt:');
      for (var key in mirror.instanceMembers.keys) {
        developer.log(MirrorSystem.getName(key));
      }
    } catch (e) {
      developer.log('SqlCrdt not found: $e');
    }
  });
}
