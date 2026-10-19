import 'dart:convert';

import 'package:eco/core/privacy/transaction_visibility.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/categories/data/repositories/category_repository.dart';
import 'package:eco/features/transactions/data/repositories/transaction_repository.dart';
import 'package:eco/features/transactions/import/providers/import_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_remote_sources.dart';
import 'support/test_isar.dart';

void main() {
  late TransactionRepository repository;
  late List<CategoryModel> categories;

  setUp(() async {
    await TestIsar.open();
    setNetwork(online: false);

    final categoryRepository = CategoryRepository(FakeCategoryRemoteSource());
    await categoryRepository.add(
      CategoryModel()
        ..name = 'Food'
        ..type = CategoryType.expense
        ..color = 0xFF64B5F6,
    );
    categories = await categoryRepository.getAll();

    repository = TransactionRepository(
      FakeTransactionRemoteSource(),
      categoryRepository: categoryRepository,
    );
  });

  tearDown(() async {
    setNetwork(online: true);
    await TestIsar.close();
  });

  Future<ImportController> controllerFor(String csv) async {
    final controller = ImportController(repository);
    await controller.loadFile(
      fileName: 'bank.csv',
      bytes: utf8.encode(csv),
      categories: categories,
    );
    return controller;
  }

  const csv =
      'Date,Amount,Title,Category\n'
      '05/01/2026,100,Coffee,Food\n'
      '05/01/2026,100,Coffee,Food\n'
      '06/01/2026,250,Lunch,Food\n';

  test('two identical rows inside one file are both imported', () async {
    final saved = await (await controllerFor(
      csv,
    )).commit(skipInvalidDrafts: false, categories: categories);

    expect(saved, hasLength(3));
  });

  test('importing the same file again adds nothing', () async {
    await (await controllerFor(
      csv,
    )).commit(skipInvalidDrafts: false, categories: categories);

    final again = await controllerFor(csv);
    await expectLater(
      again.commit(skipInvalidDrafts: false, categories: categories),
      throwsStateError,
    );

    expect(again.lastSkippedDuplicates, 3);
    expect(await repository.getLocalAll(), hasLength(3));
  });

  test('only new rows from an overlapping file are added', () async {
    await (await controllerFor(
      csv,
    )).commit(skipInvalidDrafts: false, categories: categories);

    final overlapping = await controllerFor('${csv}07/01/2026,40,Tea,Food\n');
    final saved = await overlapping.commit(
      skipInvalidDrafts: false,
      categories: categories,
    );

    expect(saved, hasLength(1));
    expect(overlapping.lastSkippedDuplicates, 3);
    expect(await repository.getLocalAll(), hasLength(4));
  });

  test(
    'rows matching a hidden transaction are imported, not revealed',
    () async {
      await (await controllerFor(
        csv,
      )).commit(skipInvalidDrafts: false, categories: categories);
      final stored = await repository.getLocalAll();

      final hiding = ImportController(
        repository,
        visibility: () => TransactionVisibilityState(
          mode: TransactionVisibilityMode.invisible,
          hiddenTransactionKeys: {
            for (final tx in stored) ...transactionVisibilityKeys(tx),
          },
        ),
      );
      await hiding.loadFile(
        fileName: 'bank.csv',
        bytes: utf8.encode(csv),
        categories: categories,
      );
      final saved = await hiding.commit(
        skipInvalidDrafts: false,
        categories: categories,
      );

      expect(saved, hasLength(3));
      expect(hiding.lastSkippedDuplicates, 0);
    },
  );
}
