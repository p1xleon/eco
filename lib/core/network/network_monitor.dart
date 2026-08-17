import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Single source of truth for whether remote calls are worth attempting.
///
/// `connectivity_plus` only reports the network *interface*, so a captive
/// portal or a dead uplink still reads as online. Remote sources report their
/// outcome back through [reportFailure] / [reportSuccess]; a failure parks the
/// monitor offline for [_failureBackoff] so screens stop paying an HTTP
/// timeout on every read.
///
/// Follows the same static-instance shape as `IsarService`.
class NetworkMonitor {
  NetworkMonitor._();

  static final NetworkMonitor instance = NetworkMonitor._();

  static const _failureBackoff = Duration(seconds: 30);

  final _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _hasInterface = true;
  DateTime? _unreachableUntil;
  bool _lastBroadcast = true;

  /// Whether a remote call should be attempted right now.
  bool get isOnline => _hasInterface && !_isBackingOff;

  /// Interface state only, ignoring the reachability backoff. Used by the UI so
  /// a single failed request does not claim the device has no connection.
  bool get hasInterface => _hasInterface;

  /// Emits whenever [isOnline] changes.
  Stream<bool> get onStatusChanged => _controller.stream;

  bool get _isBackingOff {
    final until = _unreachableUntil;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;

    _unreachableUntil = null;
    return false;
  }

  Future<void> init() async {
    if (_subscription != null) return;

    final connectivity = Connectivity();

    try {
      _hasInterface = _hasConnection(await connectivity.checkConnectivity());
    } catch (_) {
      // Assume online: a false negative here would block syncing entirely,
      // while a false positive only costs one timed-out request.
      _hasInterface = true;
    }
    _lastBroadcast = isOnline;

    _subscription = connectivity.onConnectivityChanged.listen((results) {
      _hasInterface = _hasConnection(results);
      if (_hasInterface) {
        // A new interface deserves a fresh attempt.
        _unreachableUntil = null;
      }
      _broadcast();
    });
  }

  /// Called after a remote call fails for a reason that looks like the network.
  void reportFailure() {
    _unreachableUntil = DateTime.now().add(_failureBackoff);
    _broadcast();
  }

  /// Called after any successful remote call.
  void reportSuccess() {
    if (_unreachableUntil == null) return;

    _unreachableUntil = null;
    _broadcast();
  }

  /// Clears the backoff so the next call goes out immediately. Used by manual
  /// "sync now" style actions, where the user has asked us to try again.
  void resetBackoff() => reportSuccess();

  void _broadcast() {
    final current = isOnline;
    if (current == _lastBroadcast) return;

    _lastBroadcast = current;
    if (!_controller.isClosed) {
      _controller.add(current);
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
