import 'dart:async';
import 'package:drift/drift.dart';
import 'package:agent_core/agent_core.dart';

part 'session_mutex_dao.g.dart';

/// Data Access Object for Session Mutexes table.
/// Provides locking mechanisms.
@DriftAccessor(tables: [SessionMutexes])
class SessionMutexDao extends DatabaseAccessor<ProjectDatabase>
    with _$SessionMutexDaoMixin {
  SessionMutexDao(super.db);

  static const lockTimeout = Duration(minutes: 15);

  /// Tries to acquire a lock for the given [id].
  /// Returns true if the lock was acquired, false otherwise.
  ///
  /// The lock is acquired if:
  /// - No lock exists for [id]
  /// - An existing lock has timed out (older than 15 minutes)
  Future<bool> acquireLock(String id) {
    return transaction(() async {
      final now = DateTime.now();
      final timeoutThreshold = now.subtract(lockTimeout);

      final existing = await (select(sessionMutexes)
            ..where((t) =>
                t.id.equals(id) &
                const CustomExpression<bool>('is_deleted').equals(false)))
          .getSingleOrNull();

      if (existing != null) {
        if (existing.timestamp.isBefore(timeoutThreshold)) {
          // Lock expired, take it
          await update(sessionMutexes)
              .replace(SessionMutexEntity(id: id, timestamp: now));
          return true;
        } else {
          // Locked by someone else (or us, but active)
          return false;
        }
      } else {
        // No lock (or deleted), take it
        await into(sessionMutexes).insert(
          SessionMutexEntity(id: id, timestamp: now),
          mode: InsertMode.insertOrReplace,
        );
        return true;
      }
    });
  }

  /// Unlocks the mutex for [id].
  Future<void> unlock(String id) async {
    await (delete(sessionMutexes)..where((t) => t.id.equals(id))).go();
  }

  /// Unlocks all mutexes by deleting all lock entries.
  /// Returns the number of mutexes that were cleaned up.
  Future<int> cleanupAll() {
    return delete(sessionMutexes).go();
  }

  /// Refreshes the lock for [id] by updating the timestamp.
  /// Returns true if the lock existed and was updated.
  Future<bool> refreshLock(String id) async {
    final now = DateTime.now();
    final rowsAffected = await (update(sessionMutexes)
          ..where((t) =>
              t.id.equals(id) &
              const CustomExpression<bool>('is_deleted').equals(false)))
        .write(SessionMutexEntityCompanion(timestamp: Value(now)));

    return rowsAffected > 0;
  }

  /// Watch the lock status for a specific session [id].
  /// Returns true if the session is locked and the lock is valid (not timed out).
  /// Emits false automatically when the lock expires.
  Stream<bool> watchLock(String id) {
    late StreamController<bool> controller;
    StreamSubscription<SessionMutexEntity?>? dbSubscription;
    Timer? timer;

    void check(SessionMutexEntity? entity) {
      timer?.cancel();

      if (entity == null) {
        controller.add(false);
        return;
      }

      final now = DateTime.now();
      final expiry = entity.timestamp.add(lockTimeout);

      if (now.isAfter(expiry)) {
        controller.add(false);
      } else {
        controller.add(true);
        final duration = expiry.difference(now);
        timer = Timer(duration, () {
          if (!controller.isClosed) controller.add(false);
        });
      }
    }

    controller = StreamController<bool>(
      onListen: () {
        dbSubscription = (select(sessionMutexes)
              ..where((t) =>
                  t.id.equals(id) &
                  const CustomExpression<bool>('is_deleted').equals(false)))
            .watchSingleOrNull()
            .listen(check);
      },
      onCancel: () {
        timer?.cancel();
        dbSubscription?.cancel();
      },
    );

    return controller.stream;
  }
}
