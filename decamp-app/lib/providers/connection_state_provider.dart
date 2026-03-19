import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-layer connection status.
enum LayerConnectionState { disconnected, connecting, connected }

/// Immutable snapshot of all three connection layers.
@immutable
class SyncConnectionState {
  final LayerConnectionState tunnel;
  final LayerConnectionState global;
  final LayerConnectionState project;

  const SyncConnectionState({
    this.tunnel = LayerConnectionState.disconnected,
    this.global = LayerConnectionState.disconnected,
    this.project = LayerConnectionState.disconnected,
  });

  /// Aggregate state shown by the indicator icon.
  ///
  /// - **connecting** if any layer is connecting, or if global is connected
  ///   but project hasn't reached connected yet (project will follow).
  /// - **connected** only when project sync is fully up.
  /// - **disconnected** otherwise.
  LayerConnectionState get aggregate {
    if (tunnel == LayerConnectionState.connecting ||
        global == LayerConnectionState.connecting ||
        project == LayerConnectionState.connecting) {
      return LayerConnectionState.connecting;
    }
    if (project == LayerConnectionState.connected) {
      return LayerConnectionState.connected;
    }
    // Global is up but project hasn't started yet — treat as connecting
    // so the user sees continuous progress.
    if (global == LayerConnectionState.connected) {
      return LayerConnectionState.connecting;
    }
    return LayerConnectionState.disconnected;
  }

  SyncConnectionState copyWith({
    LayerConnectionState? tunnel,
    LayerConnectionState? global,
    LayerConnectionState? project,
  }) {
    return SyncConnectionState(
      tunnel: tunnel ?? this.tunnel,
      global: global ?? this.global,
      project: project ?? this.project,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncConnectionState &&
          tunnel == other.tunnel &&
          global == other.global &&
          project == other.project;

  @override
  int get hashCode => Object.hash(tunnel, global, project);

  @override
  String toString() =>
      'SyncConnectionState(tunnel: $tunnel, global: $global, project: $project, '
      'aggregate: $aggregate)';
}

/// Notifier that holds per-layer connection states and derives the aggregate.
class ConnectionStateNotifier extends StateNotifier<SyncConnectionState> {
  ConnectionStateNotifier() : super(const SyncConnectionState());

  void setTunnel(LayerConnectionState value) {
    _deferred(() => state = state.copyWith(tunnel: value));
  }

  void setGlobal(LayerConnectionState value) {
    _deferred(() => state = state.copyWith(global: value));
  }

  void setProject(LayerConnectionState value) {
    _deferred(() => state = state.copyWith(project: value));
  }

  /// Reset all layers to disconnected.
  void reset() {
    _deferred(() => state = const SyncConnectionState());
  }

  /// Schedule [fn] as a microtask so the mutation never lands inside
  /// a widget build frame (Riverpod forbids that).
  void _deferred(void Function() fn) {
    scheduleMicrotask(() {
      if (mounted) fn();
    });
  }
}

/// Full per-layer connection state (use `ref.watch` for detailed breakdown).
final connectionStateProvider =
    StateNotifierProvider<ConnectionStateNotifier, SyncConnectionState>((ref) {
      return ConnectionStateNotifier();
    });

/// Convenience selector: the single aggregate value for the indicator widget.
final aggregateConnectionStateProvider = Provider<LayerConnectionState>((ref) {
  return ref.watch(connectionStateProvider.select((s) => s.aggregate));
});
