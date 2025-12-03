import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';

class SyncIndicator extends ConsumerStatefulWidget {
  const SyncIndicator({super.key});

  @override
  ConsumerState<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends ConsumerState<SyncIndicator>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.watch(syncServiceProvider);

    return StreamBuilder<SyncConnectionState>(
      stream: syncService.connectionState,
      initialData: syncService.currentConnectionState,
      builder: (context, connectionSnapshot) {
        final connectionState = connectionSnapshot.data!;

        if (connectionState == SyncConnectionState.connecting) {
          if (!_spinController.isAnimating) {
            _spinController.repeat();
          }
          return RotationTransition(
            turns: _spinController,
            child: const Icon(Icons.refresh, size: 16),
          );
        } else {
          if (_spinController.isAnimating) {
            _spinController.stop();
            _spinController.reset();
          }
        }

        if (connectionState == SyncConnectionState.disconnected) {
          return Icon(
            Icons.cloud_off,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          );
        }

        // Connected state
        return StreamBuilder<bool>(
          stream: syncService.isSyncing,
          initialData: false,
          builder: (context, syncingSnapshot) {
            final isSyncing = syncingSnapshot.data ?? false;

            if (isSyncing) {
              if (!_pulseController.isAnimating) {
                _pulseController.repeat(reverse: true);
              }
            } else {
              if (_pulseController.isAnimating) {
                _pulseController.stop();
                _pulseController.value =
                    0.0; // Reset to fully visible (or dimmed)
              }
            }

            // When syncing, pulse between 1.0 and 0.5
            // When idle, stay at 0.5 (dimmed)

            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                double opacity;
                if (isSyncing) {
                  // Pulse between 0.5 and 1.0
                  opacity = 0.5 + (_pulseController.value * 0.5);
                } else {
                  // Idle dimmed state
                  opacity = 0.5;
                }

                return Opacity(
                  opacity: opacity,
                  child: const Icon(Icons.cloud_queue, size: 16),
                );
              },
            );
          },
        );
      },
    );
  }
}
