import 'package:flutter/foundation.dart';

/// Server rows a pull had to skip because this device could not read them.
///
/// Skipping one bad row keeps sync alive for the rest, but the skip must be
/// visible: otherwise the user just sees missing data with no error.
class SyncIssues {
  const SyncIssues._();

  /// Total across collections, from each collection's latest pull.
  static final unreadable = ValueNotifier<int>(0);

  static final _byCollection = <String, int>{};

  static void reportUnreadable(String collection, int count) {
    _byCollection[collection] = count;
    unreadable.value = _byCollection.values.fold(0, (a, b) => a + b);
  }
}
