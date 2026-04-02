import 'dart:async';
import 'package:crdt/crdt.dart';
import 'package:logging/logging.dart';

/// Adapts a [Crdt] to track when merge operations are in progress.
/// This allows synchronizing external events with the CRDT merge stream.
class CrdtFlowAdapter implements Crdt {
  static final _log = Logger('CrdtFlowAdapter');
  final Crdt _inner;
  Future<void> _lastMerge = Future.value();

  /// When set, [getLastModified] with `exceptNodeId` is rewritten to
  /// `onlyNodeId: peerNodeId` so the CrdtSync handshake only reports
  /// what we know about this specific peer — not the max HLC from all
  /// non-local nodes. Without this, connecting to a new server after
  /// syncing with another causes the handshake to report a misleadingly
  /// high HLC, making the new server skip its initial changeset.
  String? peerNodeId;

  CrdtFlowAdapter(this._inner, {this.peerNodeId});

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
  FutureOr<Hlc> getLastModified({String? onlyNodeId, String? exceptNodeId}) {
    // When peerNodeId is set and CrdtSync asks for "everything except me",
    // rewrite to "only from the peer" so the handshake accurately reflects
    // what we know about this specific server, not the global max HLC.
    if (peerNodeId != null && exceptNodeId != null && onlyNodeId == null) {
      return _inner.getLastModified(onlyNodeId: peerNodeId);
    }
    return _inner.getLastModified(
        onlyNodeId: onlyNodeId, exceptNodeId: exceptNodeId);
  }

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
