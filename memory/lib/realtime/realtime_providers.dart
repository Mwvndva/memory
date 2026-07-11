import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'realtime_coordinator.dart';
import 'realtime_event.dart';

// ─── Coordinator ─────────────────────────────────────────────────────────────

/// The single [RealtimeCoordinator] instance for the application lifetime.
///
/// Feature modules read this provider to emit outbound frames:
/// ```dart
/// ref.read(realtimeCoordinatorProvider).emit({...});
/// ```
final realtimeCoordinatorProvider = Provider<RealtimeCoordinator>((ref) {
  final coordinator = RealtimeCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

// ─── Connection state ─────────────────────────────────────────────────────────

/// The current WebSocket connection state.
///
/// Widgets and providers can watch this to react to connect/disconnect events:
/// ```dart
/// final state = ref.watch(connectionStateProvider);
/// ```
final connectionStateProvider = StreamProvider<RealtimeConnectionState>((ref) {
  final coordinator = ref.watch(realtimeCoordinatorProvider);
  return coordinator.connectionStateStream;
});

// ─── Event stream ─────────────────────────────────────────────────────────────

/// Broadcast stream of all incoming typed [RealtimeEvent] values.
///
/// Feature state managers subscribe and filter for the events they own:
/// ```dart
/// ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventStreamProvider, (_, next) {
///   next.whenData((event) {
///     if (event is NewMessageEvent) _handleMessage(event);
///   });
/// });
/// ```
final realtimeEventStreamProvider = StreamProvider<RealtimeEvent>((ref) {
  final coordinator = ref.watch(realtimeCoordinatorProvider);
  return coordinator.eventStream;
});
