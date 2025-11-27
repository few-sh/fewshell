import 'dart:mirrors';
import 'package:sql_crdt/sql_crdt.dart'; // Try importing sql_crdt directly
import 'package:test/test.dart';

void main() {
  test('Inspect SqlCrdt API', () {
    try {
      final mirror = reflectClass(SqlCrdt);
      print('Methods of SqlCrdt:');
      for (var key in mirror.instanceMembers.keys) {
        print(MirrorSystem.getName(key));
      }
    } catch (e) {
      print('SqlCrdt not found: $e');
    }
  });
}
