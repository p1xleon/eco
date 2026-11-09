import 'package:eco/core/privacy/transaction_visibility.dart';
import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:eco/features/collections/presentation/pages/collection_detail_page.dart';
import 'package:eco/features/collections/presentation/pages/collections_page.dart';
import 'package:eco/features/collections/presentation/providers/collection_provider.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/presentation/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final trip = CollectionModel()
    ..id = 1
    ..name = 'Lisbon trip'
    ..color = 0xFF3B82F6;
  final hotel = TransactionModel()
    ..id = 10
    ..title = 'Hotel'
    ..amount = 120
    ..type = TransactionType.expense
    ..date = DateTime.utc(2026, 10, 1)
    ..categoryId = 1
    ..collectionId = 1
    ..createdAt = DateTime.utc(2026, 10, 1);

  Widget app({List<Override> extra = const []}) => ProviderScope(
    overrides: [
      collectionsProvider.overrideWith((ref) async => [trip]),
      transactionsProvider.overrideWith((ref) async => [hotel]),
      ...extra,
    ],
    child: const MaterialApp(home: CollectionsPage()),
  );

  testWidgets('new collection lives in the app bar, not a second FAB', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // The app shell already owns the floating button.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('New collection'), findsOneWidget);
  });

  testWidgets('lists collections with their net total', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Lisbon trip'), findsOneWidget);
    expect(find.textContaining('120'), findsWidgets);
  });

  testWidgets('masked mode hides the totals', (tester) async {
    await tester.pumpWidget(
      app(
        extra: [
          transactionVisibilityProvider.overrideWith(
            (ref) => TransactionVisibilityNotifier(
              const TransactionVisibilityState(
                mode: TransactionVisibilityMode.masked,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lisbon trip'), findsOneWidget);
    expect(find.textContaining('120'), findsNothing);
    expect(find.textContaining('•••'), findsWidgets);
  });

  testWidgets('detail page offers adding a transaction', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionsProvider.overrideWith((ref) async => [trip]),
          transactionsProvider.overrideWith((ref) async => [hotel]),
        ],
        child: const MaterialApp(home: CollectionDetailPage(collectionId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add transaction'), findsOneWidget);
  });
}
