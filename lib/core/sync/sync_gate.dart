import 'dart:async';

/// Collapses redundant replication passes over the same collection.
///
/// One reconnect refreshes several providers at once, and some of them sync the
/// same collection on the way (recurring templates pull categories first). Left
/// alone that is three or four round trips where one would do.
///
/// Concurrent callers join the pass already in flight; a caller arriving just
/// after one finished is served from what it wrote instead of repeating it.
class SyncGate {
  SyncGate({Duration window = const Duration(seconds: 2)}) : _window = window;

  final Duration _window;

  Future<void>? _inFlight;
  DateTime? _completedAt;

  Future<void> run(Future<void> Function() action) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final completedAt = _completedAt;
    if (completedAt != null &&
        DateTime.now().difference(completedAt) < _window) {
      return Future<void>.value();
    }

    // Only a pass that actually succeeded means the local cache is fresh, so a
    // failed one must not suppress the next attempt.
    final future = action().then((_) {
      _completedAt = DateTime.now();
    }).whenComplete(() {
      _inFlight = null;
    });

    _inFlight = future;
    return future;
  }

  /// Drops the recency window so the next call definitely goes out. Used when
  /// the user explicitly asks for a sync.
  void reset() => _completedAt = null;
}
