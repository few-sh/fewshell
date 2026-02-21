import 'package:agent_core/src/utils/node_id_migration.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'package:test/test.dart';

/// Helper to get all raw `modified` values from a table.
Future<List<String>> getModifiedValues(SqliteCrdt crdt, String table) async {
  final rows = await crdt.query('SELECT modified FROM $table');
  return rows.map((r) => r['modified'] as String).toList();
}

/// Helper to get all raw records from a table (including CRDT columns).
Future<List<Map<String, Object?>>> getAllRecords(
    SqliteCrdt crdt, String table) async {
  return crdt.query('SELECT * FROM $table');
}

void main() {
  group('CRDT node ID migration behavior', () {
    late SqliteCrdt crdt;

    setUp(() async {
      crdt = await SqliteCrdt.openInMemory();
    });

    tearDown(() async {
      await crdt.close();
    });

    test('verify HLC format and initial node ID', () async {
      // SqliteCrdt.openInMemory() auto-generates a UUID node ID via init()
      final autoNodeId = crdt.nodeId;
      expect(autoNodeId, isNotEmpty);

      // Create tables and insert records
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS projects '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS snippets '
        '(id TEXT NOT NULL PRIMARY KEY, content TEXT NOT NULL)',
      );

      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p1', 'Project One')");
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p2', 'Project Two')");
      await crdt.execute(
          "INSERT INTO snippets (id, content) VALUES ('s1', 'echo hello')");

      // Verify the HLC format: <ISO8601>-<COUNTER_HEX>-<nodeId>
      final modified = await getModifiedValues(crdt, 'projects');
      expect(modified, hasLength(2));

      for (final m in modified) {
        // Should end with the auto-generated node ID
        expect(m, endsWith('-$autoNodeId'),
            reason: 'modified value "$m" should end with node ID');

        // Parse to verify it's a valid HLC
        final hlc = Hlc.parse(m);
        expect(hlc.nodeId, equals(autoNodeId));
        expect(hlc.counter, greaterThanOrEqualTo(0));
        expect(hlc.dateTime.year, greaterThanOrEqualTo(1970));
      }

      // Also verify snippets table
      final snippetModified = await getModifiedValues(crdt, 'snippets');
      expect(snippetModified, hasLength(1));
      expect(snippetModified.first, endsWith('-$autoNodeId'));
    });

    test('resetNodeId() updates all modified columns and canonicalTime',
        () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS projects '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS snippets '
        '(id TEXT NOT NULL PRIMARY KEY, content TEXT NOT NULL)',
      );

      final oldNodeId = crdt.nodeId;

      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p1', 'Project One')");
      await crdt.execute(
          "INSERT INTO snippets (id, content) VALUES ('s1', 'echo hello')");

      // Verify old values
      final beforeProjects = await getModifiedValues(crdt, 'projects');
      expect(beforeProjects.first, endsWith('-$oldNodeId'));

      // Reset the node ID using the built-in method
      const newNodeId = 'srv_test123';
      await crdt.resetNodeId(newNodeId);

      // Verify canonicalTime updated
      expect(crdt.nodeId, equals(newNodeId));

      // Verify all modified columns updated in projects
      final afterProjects = await getModifiedValues(crdt, 'projects');
      for (final m in afterProjects) {
        expect(m, endsWith('-$newNodeId'),
            reason: 'modified "$m" should end with new node ID');
        // Verify old node ID is NOT present anywhere in the string
        expect(m, isNot(contains(oldNodeId)),
            reason: 'old node ID should not appear in modified value');
      }

      // Verify snippets too
      final afterSnippets = await getModifiedValues(crdt, 'snippets');
      for (final m in afterSnippets) {
        expect(m, endsWith('-$newNodeId'));
      }

      // Verify records are visible in changeset
      final changeset = await crdt.getChangeset();
      expect(changeset, isNotEmpty);
      expect(changeset.containsKey('projects'), isTrue);
      expect(changeset.containsKey('snippets'), isTrue);
    });

    test('resetNodeId() is idempotent', () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS projects '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p1', 'Project One')");

      const newNodeId = 'srv_test123';
      await crdt.resetNodeId(newNodeId);

      // Capture state after first reset
      final afterFirst = await getModifiedValues(crdt, 'projects');
      final canonicalAfterFirst = crdt.canonicalTime.toString();

      // Reset again with the same node ID — should be a no-op
      await crdt.resetNodeId(newNodeId);

      final afterSecond = await getModifiedValues(crdt, 'projects');
      final canonicalAfterSecond = crdt.canonicalTime.toString();

      // Values should be identical — no unnecessary changes
      expect(afterSecond, equals(afterFirst));
      expect(canonicalAfterSecond, equals(canonicalAfterFirst));
    });

    test('migrateNodeId() updates all tables to new node ID', () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS projects '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS snippets '
        '(id TEXT NOT NULL PRIMARY KEY, content TEXT NOT NULL)',
      );

      // Reset to 'server' to simulate production state
      await crdt.resetNodeId('server');

      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p1', 'Project One')");
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p2', 'Project Two')");
      await crdt.execute(
          "INSERT INTO snippets (id, content) VALUES ('s1', 'echo hello')");

      // Verify pre-migration state
      final beforeProjects = await getModifiedValues(crdt, 'projects');
      for (final m in beforeProjects) {
        expect(m, endsWith('-server'));
      }

      // Run our custom migration
      const newNodeId = 'srv_test123';
      await migrateNodeId(crdt, newNodeId);

      // Verify canonicalTime updated
      expect(crdt.nodeId, equals(newNodeId));

      // Verify all modified columns updated in projects
      final afterProjects = await getModifiedValues(crdt, 'projects');
      for (final m in afterProjects) {
        expect(m, endsWith('-$newNodeId'),
            reason: 'modified "$m" should end with new node ID');

        // Verify the HLC is still valid
        final hlc = Hlc.parse(m);
        expect(hlc.nodeId, equals(newNodeId));
      }

      // Verify snippets too
      final afterSnippets = await getModifiedValues(crdt, 'snippets');
      for (final m in afterSnippets) {
        expect(m, endsWith('-$newNodeId'));
      }
    });

    test('migrateNodeId() makes records visible in changeset for sync',
        () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS projects '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );

      await crdt.resetNodeId('server');
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p1', 'Project One')");

      // Get changeset before migration
      final changesetBefore = await crdt.getChangeset();
      expect(changesetBefore['projects'], isNotNull);
      final recordBefore = changesetBefore['projects']!.first;
      expect(recordBefore['modified'] as String, endsWith('-server'));

      // Migrate
      const newNodeId = 'srv_test123';
      await migrateNodeId(crdt, newNodeId);

      // Get changeset after migration — records should have new node ID
      final changesetAfter = await crdt.getChangeset();
      expect(changesetAfter['projects'], isNotNull);
      final recordAfter = changesetAfter['projects']!.first;
      expect(recordAfter['modified'] as String, endsWith('-$newNodeId'),
          reason: 'Changeset must return records with the new node ID '
              'so CRDT sync propagates the change to clients');
    });

    test('migrateNodeId() is idempotent (no-op when already migrated)',
        () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS projects '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );

      await crdt.resetNodeId('server');
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p1', 'Project One')");

      const newNodeId = 'srv_test123';

      // First migration
      await migrateNodeId(crdt, newNodeId);
      final afterFirst = await getModifiedValues(crdt, 'projects');
      final canonicalAfterFirst = crdt.canonicalTime.toString();

      // Second migration — should early-return (nodeId already matches)
      await migrateNodeId(crdt, newNodeId);
      final afterSecond = await getModifiedValues(crdt, 'projects');
      final canonicalAfterSecond = crdt.canonicalTime.toString();

      // No changes
      expect(afterSecond, equals(afterFirst));
      expect(canonicalAfterSecond, equals(canonicalAfterFirst));
    });

    test('migrateNodeId() supports sequential node ID rotation', () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS projects '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );

      await crdt.resetNodeId('server');
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p1', 'Project One')");

      // First rotation: server → srv_aaa
      await migrateNodeId(crdt, 'srv_aaa');
      expect(crdt.nodeId, equals('srv_aaa'));

      final afterFirst = await getModifiedValues(crdt, 'projects');
      expect(afterFirst.first, endsWith('-srv_aaa'));

      // Insert another record under the new ID
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p2', 'Project Two')");

      // Second rotation: srv_aaa → srv_bbb
      await migrateNodeId(crdt, 'srv_bbb');
      expect(crdt.nodeId, equals('srv_bbb'));

      final afterSecond = await getModifiedValues(crdt, 'projects');
      for (final m in afterSecond) {
        expect(m, endsWith('-srv_bbb'),
            reason: 'All records should have the latest node ID');
      }
    });

    test('migrateNodeId() preserves record data', () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS projects '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );

      await crdt.resetNodeId('server');
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p1', 'Project One')");
      await crdt.execute(
          "INSERT INTO projects (id, name) VALUES ('p2', 'Project Two')");

      // Migrate
      await migrateNodeId(crdt, 'srv_new');

      // Verify record data is intact
      final records = await getAllRecords(crdt, 'projects');
      final p1 = records.firstWhere((r) => r['id'] == 'p1');
      final p2 = records.firstWhere((r) => r['id'] == 'p2');
      expect(p1['name'], equals('Project One'));
      expect(p2['name'], equals('Project Two'));
      expect(p1['is_deleted'], equals(0));
      expect(p2['is_deleted'], equals(0));
    });

    test('migrateNodeId() timestamps advance (expected with touch approach)',
        () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS test_table '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );

      await crdt.resetNodeId('server');
      await crdt
          .execute("INSERT INTO test_table (id, name) VALUES ('r1', 'Record')");

      // Capture HLC before migration
      final beforeModified = await getModifiedValues(crdt, 'test_table');
      final hlcBefore = Hlc.parse(beforeModified.first);

      // Migrate
      await migrateNodeId(crdt, 'srv_new_node');

      // HLC after migration
      final afterModified = await getModifiedValues(crdt, 'test_table');
      final hlcAfter = Hlc.parse(afterModified.first);

      // The touch approach creates a NEW HLC (not preserving the old one).
      // This is expected and desired — newer timestamps mean the records
      // will appear in changesets and replicate to clients.
      expect(hlcAfter.nodeId, equals('srv_new_node'));
      expect(hlcAfter, greaterThan(hlcBefore),
          reason: 'Touched records get newer HLCs, ensuring sync propagation');
    });

    test('migrateNodeId() works with empty tables', () async {
      await crdt.execute(
        'CREATE TABLE IF NOT EXISTS empty_table '
        '(id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );

      await crdt.resetNodeId('server');

      // Should not throw on empty tables
      await migrateNodeId(crdt, 'srv_new');
      expect(crdt.nodeId, equals('srv_new'));
    });
  });
}
