import 'dart:async';
import 'package:crdt/crdt.dart';
import 'package:logging/logging.dart';

/// Adapts a [Crdt] to track when merge operations are in progress.
/// This allows synchronizing external events with the CRDT merge stream.
class CrdtFlowAdapter implements Crdt {
  static final _log = Logger('CrdtFlowAdapter');
  final Crdt _inner;
  Future<void> _lastMerge = Future.value();

  CrdtFlowAdapter(this._inner);

  /// Returns a future that completes when the last merge operation finishes.
  Future<void> get onIdle => _lastMerge;

  @override
  Hlc get canonicalTime => _inner.canonicalTime;

  @override
  set canonicalTime(Hlc value) {
    // Protected member, cannot delegate.
    // Should not be called by consumers.
    throw UnimplementedError();
  }

  @override
  String get nodeId => _inner.nodeId;

  @override
  Stream<({Hlc hlc, Iterable<String> tables})> get onTablesChanged =>
      _inner.onTablesChanged;

  @override
  FutureOr<Hlc> getLastModified({String? onlyNodeId, String? exceptNodeId}) =>
      _inner.getLastModified(
          onlyNodeId: onlyNodeId, exceptNodeId: exceptNodeId);

  @override
  FutureOr<CrdtChangeset> getChangeset({
    Iterable<String>? onlyTables,
    String? onlyNodeId,
    String? exceptNodeId,
    Hlc? modifiedOn,
    Hlc? modifiedAfter,
  }) =>
      _inner.getChangeset(
        onlyTables: onlyTables,
        onlyNodeId: onlyNodeId,
        exceptNodeId: exceptNodeId,
        modifiedOn: modifiedOn,
        modifiedAfter: modifiedAfter,
      );

  @override
  FutureOr<void> merge(CrdtChangeset changeset) {
    final result = _inner.merge(changeset);
    if (result is Future) {
      final future = result as Future<void>;
      _lastMerge = future.catchError((e, s) {
        _log.severe('CRDT merge failed', e, s);
      });
      return future;
    }
  }

  @override
  Hlc validateChangeset(CrdtChangeset changeset) {
    // Protected member, cannot delegate.
    // Should not be called by consumers.
    throw UnimplementedError();
  }

  @override
  void onDatasetChanged(Iterable<String> affectedTables, Hlc hlc) {
    // Protected member, cannot delegate.
    // Should not be called by consumers.
    throw UnimplementedError();
  }
}
