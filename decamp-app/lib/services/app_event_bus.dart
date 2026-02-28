import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decamp/models/app_event.dart';

/// A simple broadcast event bus for app-wide events that require UI responses.
///
/// Any service can emit events via [emit]. The root [AppEventListener] widget
/// subscribes to [events] and dispatches UI actions (dialogs, toasts, etc.)
/// via pattern matching on the sealed [AppEvent] hierarchy.
class AppEventBus {
  final _controller = StreamController<AppEvent>.broadcast();

  /// Stream of app-wide events. Subscribe once at the root of the widget tree.
  Stream<AppEvent> get events => _controller.stream;

  /// Emit an event onto the bus.
  void emit(AppEvent event) => _controller.add(event);

  void dispose() => _controller.close();
}

final appEventBusProvider = Provider<AppEventBus>((ref) {
  final bus = AppEventBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});
