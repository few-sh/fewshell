import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/connection_state_provider.dart';
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
    final aggregate = ref.watch(aggregateConnectionStateProvider);
    final theme = ShadTheme.of(context);

    if (aggregate == LayerConnectionState.connecting) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
      return ShadTooltip(
        builder: (context) => const Text('Connecting...'),
        child: RotationTransition(
          turns: _spinController,
          child: Icon(
            LucideIcons.refreshCw,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      );
    } else {
      if (_spinController.isAnimating) {
        _spinController.stop();
        _spinController.reset();
      }
    }

    if (aggregate == LayerConnectionState.disconnected) {
      return ShadTooltip(
        builder: (context) => const Text('Disconnected'),
        child: Icon(
          LucideIcons.cloudOff,
          size: 16,
          color: theme.colorScheme.destructive,
        ),
      );
    }

    // Connected state
    final syncService = ref.watch(syncServiceProvider);
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
            _pulseController.value = 0.0;
          }
        }

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

            return ShadTooltip(
              builder: (context) => Text(isSyncing ? 'Syncing...' : 'Synced'),
              child: Opacity(
                opacity: opacity,
                child: Icon(
                  LucideIcons.cloud,
                  size: 16,
                  color: theme.colorScheme.foreground,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
