import 'dart:async';

/// Prevents the same real-time event from being processed more than once.
///
/// Events are keyed by their [eventId]. A seen entry is automatically evicted
/// after [ttl] (default 60 seconds) to avoid unbounded memory growth.
class EventDeduplicator {
  EventDeduplicator({this.ttl = const Duration(seconds: 60)});

  final Duration ttl;

  final Map<String, DateTime> _seen = {};
  Timer? _evictionTimer;

  /// Returns `true` if [eventId] has not been seen before.
  /// Automatically marks it as seen.
  bool isNew(String eventId) {
    _ensureEvictionTimer();
    if (_seen.containsKey(eventId)) return false;
    _seen[eventId] = DateTime.now();
    return true;
  }

  /// Manually mark an event id as seen (e.g. when processing from the queue).
  void markSeen(String eventId) {
    _seen[eventId] = DateTime.now();
    _ensureEvictionTimer();
  }

  /// Remove entries older than [ttl].
  void evictExpired() {
    final cutoff = DateTime.now().subtract(ttl);
    _seen.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  void _ensureEvictionTimer() {
    if (_evictionTimer?.isActive ?? false) return;
    _evictionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      evictExpired();
    });
  }

  void dispose() {
    _evictionTimer?.cancel();
    _evictionTimer = null;
    _seen.clear();
  }
}
