import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

/// Provider for the AppDatabase instance.
/// This is the single source of truth for database access.
/// Access DAOs directly: ref.watch(databaseProvider).projectDao
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  // Dispose database when provider is disposed
  ref.onDispose(() {
    database.close();
  });

  return database;
});
