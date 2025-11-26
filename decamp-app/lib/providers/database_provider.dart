import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Provider for the AppDatabase instance.
/// This is the single source of truth for database access.
/// Access DAOs directly: ref.watch(databaseProvider).projectDao
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(_openConnection());

  // Dispose database when provider is disposed
  ref.onDispose(() {
    database.close();
  });

  return database;
});

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'decamp.db'));
    return NativeDatabase(file);
  });
}
