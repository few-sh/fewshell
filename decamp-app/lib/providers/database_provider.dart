import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

/// Provider for the AppDatabase instance.
/// This is the single source of truth for database access.
/// All DAOs should be accessed through this provider.
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  // Dispose database when provider is disposed
  ref.onDispose(() {
    database.close();
  });

  return database;
});

/// Provider for ProjectDao
final projectDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.projectDao;
});

/// Provider for SessionDao
final sessionDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.sessionDao;
});

/// Provider for MessageDao
final messageDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.messageDao;
});
