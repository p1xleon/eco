import 'dart:async';

import 'network_monitor.dart';

const _defaultRemoteTimeout = Duration(seconds: 12);

/// Runs a remote call with a bounded timeout and feeds the outcome back to
/// [NetworkMonitor].
///
/// Without the timeout a dead-but-connected network (captive portal, DNS
/// blackhole) hangs whatever screen triggered the call. Without the reporting
/// the app keeps paying that timeout on every subsequent read.
///
/// Errors are rethrown either way — callers decide whether a failure is fatal
/// or just means "stay pending".
Future<T> remoteCall<T>(
  Future<T> Function() action, {
  Duration timeout = _defaultRemoteTimeout,
}) async {
  try {
    final result = await action().timeout(timeout);
    NetworkMonitor.instance.reportSuccess();
    return result;
  } catch (error) {
    if (isNetworkFailure(error)) {
      NetworkMonitor.instance.reportFailure();
    }
    rethrow;
  }
}

/// Whether an error means "could not reach the server" rather than "the server
/// rejected this request".
///
/// Matched by text so this stays free of `dart:io` and of transitive HTTP
/// package imports.
bool isNetworkFailure(Object error) {
  if (error is TimeoutException) return true;

  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('handshakeexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection closed') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('connection timed out') ||
      text.contains('network is unreachable') ||
      text.contains('no address associated with hostname');
}
