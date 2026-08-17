import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_monitor.dart';

/// Live view of [NetworkMonitor.isOnline], seeded with the current value so
/// widgets never render an "unknown" state.
final networkStatusProvider = StreamProvider<bool>((ref) async* {
  final monitor = NetworkMonitor.instance;

  yield monitor.isOnline;
  yield* monitor.onStatusChanged;
});

/// Convenience read of [networkStatusProvider] for widgets that only need the
/// boolean.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(networkStatusProvider).valueOrNull ??
      NetworkMonitor.instance.isOnline;
});
