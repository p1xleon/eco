import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/categories/presentation/providers/category_provider.dart';
import 'package:eco/features/settings/data/models/transaction_preset_model.dart';
import 'package:eco/features/settings/presentation/providers/transaction_preset_provider.dart';
import 'package:eco/features/transactions/bulk/presentation/bulk_add_page.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';
import 'package:eco/features/transactions/data/providers/transaction_repository_provider.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StoredRepository implements TransactionRepository {
  final stored = <TransactionModel>[];

  @override
  Future<List<TransactionModel>> getLocalAll() async => stored;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _StoredRepository repository;

  setUp(() => repository = _StoredRepository());

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final salary = CategoryModel()
      ..id = 1
      ..name = 'Salary'
      ..type = CategoryType.income
      ..color = 0xFF64B5F6;
    final rent = CategoryModel()
      ..id = 2
      ..name = 'Rent'
      ..type = CategoryType.expense
      ..color = 0xFF64B5F6;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
          categoriesProvider.overrideWith((ref) async => [salary, rent]),
          paymentMethodPresetsProvider.overrideWith(
            (ref) async => <TransactionPresetModel>[],
          ),
          payeePresetsProvider.overrideWith(
            (ref) async => <TransactionPresetModel>[],
          ),
        ],
        child: const MaterialApp(home: BulkAddPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a yearly default range counts 13 monthly entries', (
    tester,
  ) async {
    await pumpPage(tester);

    // Default range is one year back to today, monthly: 13 dates inclusive.
    expect(find.text('13 entries'), findsOneWidget);
    expect(find.text('Review 13 entries'), findsOneWidget);
  });

  testWidgets('frequency chips change the count', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();
    expect(find.text('5 entries'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.text('2 entries'), findsOneWidget);
  });

  testWidgets('custom frequency shows its own step controls', (tester) async {
    await pumpPage(tester);
    expect(find.text('Every'), findsNothing);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Every'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '0');
    await tester.pumpAndSettle();
    expect(find.text('Repeat every must be at least 1.'), findsOneWidget);
  });

  testWidgets('missing fields stop the review step with a message', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Review 13 entries'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a title, an amount above zero, and a category.'),
      findsOneWidget,
    );
    expect(find.text('Review entries'), findsNothing);
  });

  testWidgets('filled form opens the review with every generated row', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Salary');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5000');
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review 13 entries'));
    await tester.pumpAndSettle();

    expect(find.text('Review entries'), findsOneWidget);
    expect(find.textContaining('of 13 ticked'), findsOneWidget);
  });
}
