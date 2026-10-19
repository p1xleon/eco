import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/settings/data/models/transaction_preset_model.dart';
import 'package:eco/features/settings/presentation/providers/transaction_preset_provider.dart';
import 'package:eco/features/transactions/bulk/domain/bulk_entry.dart';
import 'package:eco/features/transactions/bulk/presentation/bulk_review_page.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/providers/transaction_repository_provider.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only `addAll` is used by the review page; the real save path is covered by
/// the repository tests.
class _RecordingRepository implements TransactionRepository {
  final saved = <TransactionModel>[];

  @override
  Future<List<TransactionModel>> addAll(
    Iterable<TransactionModel> transactions,
  ) async {
    saved.addAll(transactions);
    return transactions.toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingRepository repository;
  late CategoryModel category;

  setUp(() {
    repository = _RecordingRepository();
    category = CategoryModel()
      ..id = 1
      ..name = 'Salary'
      ..type = CategoryType.income
      ..color = 0xFF64B5F6;
  });

  List<BulkEntry> threeMonths({Set<String> existing = const {}}) =>
      buildBulkEntries(
        dates: [
          DateTime(2026, 1, 5),
          DateTime(2026, 2, 5),
          DateTime(2026, 3, 5),
        ],
        amount: 1000,
        title: 'Salary',
        categoryId: category.id,
        existing: existing,
      );

  Future<void> pumpReview(
    WidgetTester tester,
    List<BulkEntry> entries, {
    Set<String> existing = const {},
    void Function(int? result)? onResult,
  }) async {
    // Tall enough that the editor sheet's Save button is built, not lazily off-screen.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          paymentMethodPresetsProvider.overrideWith(
            (ref) async => <TransactionPresetModel>[],
          ),
          payeePresetsProvider.overrideWith(
            (ref) async => <TransactionPresetModel>[],
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await Navigator.push<int>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BulkReviewPage(
                        type: TransactionType.income,
                        entries: entries,
                        existing: existing,
                        categories: [category],
                      ),
                    ),
                  );
                  onResult?.call(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('already-added rows start unticked and are not saved', (
    tester,
  ) async {
    final feb = BulkEntry(
      key: 0,
      date: DateTime(2026, 2, 5),
      amount: 1000,
      title: 'Salary',
      categoryId: 1,
    );
    final existing = {feb.fingerprint};
    int? result;

    await pumpReview(
      tester,
      threeMonths(existing: existing),
      existing: existing,
      onResult: (value) => result = value,
    );

    expect(find.text('2 of 3 ticked · ₹2,000.00'), findsOneWidget);
    expect(find.text('Already added'), findsOneWidget);

    await tester.tap(find.text('Add 2 transactions'));
    await tester.pumpAndSettle();

    expect(result, 2);
    expect(repository.saved.map((t) => t.date.month), unorderedEquals([1, 3]));
    expect(
      repository.saved.every((t) => t.status == TransactionStatus.paid),
      isTrue,
    );
    expect(
      repository.saved.every((t) => t.type == TransactionType.income),
      isTrue,
    );
  });

  testWidgets('an edited row is saved with its new amount', (tester) async {
    int? result;
    await pumpReview(tester, threeMonths(), onResult: (v) => result = v);

    await tester.tap(find.textContaining('5 Feb 2026'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '1250');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('₹1,250.00'), findsOneWidget);

    await tester.tap(find.text('Add 3 transactions'));
    await tester.pumpAndSettle();

    expect(result, 3);
    final feb = repository.saved.firstWhere((t) => t.date.month == 2);
    expect(feb.amount, 1250);
    expect(repository.saved.where((t) => t.amount == 1000), hasLength(2));
  });

  testWidgets('removing a row leaves it out', (tester) async {
    await pumpReview(tester, threeMonths());

    await tester.tap(find.textContaining('5 Mar 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 2 ticked · ₹2,000.00'), findsOneWidget);
  });

  testWidgets('a broken row blocks saving with a clear message', (
    tester,
  ) async {
    final rows = threeMonths();
    rows[0] = rows[0].copyWith(amount: 0);

    await pumpReview(tester, rows);
    await tester.tap(find.text('Add 3 transactions'));
    await tester.pumpAndSettle();

    expect(find.text('1 entry needs fixing first.'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });
}
