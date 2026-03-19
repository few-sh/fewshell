import 'dart:async';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  /// Ethernet LED state: ON for a fixed pulse per activity hit.
  bool _ledOn = false;
  Timer? _ledTimer;
  StreamSubscription<bool>? _syncSubscription;

  /// Fixed LED-on duration per activity hit, like an ethernet port LED.
  static const _ledPulseDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }

  void _subscribeSyncStream(SyncService syncService) {
    _syncSubscription?.cancel();
    _syncSubscription = syncService.isSyncing.listen((active) {
      if (active) _triggerLed();
    });
  }

  /// Fire the LED ON for [_ledPulseDuration], then OFF.
  /// Activity during ON is ignored — every pulse completes its full cycle,
  /// producing visible blinks even at high packet rates.
  void _triggerLed() {
    if (!mounted || _ledOn) return;
    setState(() => _ledOn = true);
    _ledTimer = Timer(_ledPulseDuration, () {
      if (mounted) setState(() => _ledOn = false);
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _ledTimer?.cancel();
    _syncSubscription?.cancel();
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
      _syncSubscription?.cancel();
      _syncSubscription = null;
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
      _syncSubscription?.cancel();
      _syncSubscription = null;
      return ShadTooltip(
        builder: (context) => const Text('Disconnected'),
        child: Icon(
          LucideIcons.cloudOff,
          size: 16,
          color: theme.colorScheme.destructive,
        ),
      );
    }

    // Connected state — ethernet LED style activity indicator.
    final syncService = ref.watch(syncServiceProvider);
    if (_syncSubscription == null) {
      _subscribeSyncStream(syncService);
    }

    return ShadTooltip(
      builder: (context) => Text(_ledOn ? 'Syncing...' : 'Synced'),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cloud icon — dimmed at rest, brightens on activity
            Opacity(
              opacity: _ledOn ? 0.7 : 0.4,
              child: Icon(
                LucideIcons.cloud,
                size: 20,
                color: theme.colorScheme.foreground,
              ),
            ),
            // Activity LED — bottom-center up/down arrows, snaps on/off
            Positioned(
              bottom: 5,
              left: 4,
              child: Opacity(
                opacity: _ledOn ? 1.0 : 0.0,
                child: Icon(
                  LucideIcons.activity,
                  size: 10,
                  color: theme.colorScheme.accentForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
