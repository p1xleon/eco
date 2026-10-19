import 'package:eco/core/privacy/transaction_visibility.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/presentation/providers/transaction_filter_provider.dart';
import 'package:eco/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel tx(int id, String title, {String? remoteId}) =>
    TransactionModel()
      ..id = id
      ..remoteId = remoteId
      ..title = title
      ..amount = 10
      ..date = DateTime(2026, 3, 1)
      ..type = TransactionType.expense
      ..categoryId = 1
      ..createdAt = DateTime(2026, 3, 1);

void main() {
  group('invisible mode', () {
    test('a row hidden before its first sync stays hidden after it', () {
      final notifier = TransactionVisibilityNotifier();
      final offline = tx(5, 'secret');
      notifier.setMode(
        TransactionVisibilityMode.invisible,
        existingTransactions: [offline],
      );

      // Sync assigns a server id; the local id is unchanged.
      offline.remoteId = 'abc';
      expect(notifier.state.isTransactionVisible(offline), isFalse);
    });

    test('a row added after switching is visible, hidden ones are not', () {
      final notifier = TransactionVisibilityNotifier();
      final old = tx(1, 'old', remoteId: 'r1');
      notifier.setMode(
        TransactionVisibilityMode.invisible,
        existingTransactions: [old],
      );

      final fresh = tx(2, 'fresh');
      expect(notifier.state.isTransactionVisible(old), isFalse);
      expect(notifier.state.isTransactionVisible(fresh), isTrue);
    });

    test('registering a new row as visible clears both of its keys', () {
      final notifier = TransactionVisibilityNotifier();
      final row = tx(3, 'row', remoteId: 'r3');
      notifier.setMode(
        TransactionVisibilityMode.invisible,
        existingTransactions: [row],
      );
      notifier.registerVisibleTransaction(row);

      expect(notifier.state.isTransactionVisible(row), isTrue);
    });
  });

  group('masked mode', () {
    ProviderContainer containerFor(TransactionVisibilityMode mode) {
      final container = ProviderContainer(
        overrides: [
          visibleTransactionsProvider.overrideWith(
            (ref) => AsyncData([tx(1, 'salary'), tx(2, 'rent')]),
          ),
          transactionVisibilityProvider.overrideWith(
            (ref) => TransactionVisibilityNotifier(
              TransactionVisibilityState(mode: mode),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(transactionFilterProvider.notifier).setSearch('salary');
      return container;
    }

    test('search is ignored so it cannot probe hidden text', () {
      final masked = containerFor(TransactionVisibilityMode.masked);
      expect(masked.read(filteredTransactionsProvider).value, hasLength(2));
    });

    test('search still works in normal mode', () {
      final normal = containerFor(TransactionVisibilityMode.normal);
      expect(normal.read(filteredTransactionsProvider).value, hasLength(1));
    });
  });
}
