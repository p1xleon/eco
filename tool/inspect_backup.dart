// Read-only inspection of a recovered Isar backup. Prints counts and sync
// state only — never record contents.
//
// Usage: dart run tool/inspect_backup.dart <dir containing default.isar>
import 'dart:ffi';

import 'package:isar_community/isar.dart';

import 'package:eco/core/sync/sync_state.dart';
import 'package:eco/features/categories/data/models/category_model.dart';
import 'package:eco/features/recurring/data/models/recurring_transaction_model.dart';
import 'package:eco/features/settings/data/models/transaction_preset_model.dart';
import 'package:eco/features/transactions/data/models/transaction_model.dart';

Future<void> main(List<String> args) async {
  await Isar.initializeIsarCore(libraries: {Abi.macosArm64: 'libisar.dylib'});

  final isar = await Isar.open(
    [
      RecurringTransactionModelSchema,
      TransactionModelSchema,
      CategoryModelSchema,
      TransactionPresetModelSchema,
    ],
    directory: args.first,
    name: Isar.defaultName,
    inspector: false,
  );

  final transactions = await isar.transactionModels.where().findAll();
  final categories = await isar.categoryModels.where().findAll();
  final templates = await isar.recurringTransactionModels.where().findAll();
  final presets = await isar.transactionPresetModels.count();

  print('transactions: ${transactions.length}');
  print('categories:   ${categories.length}');
  print('recurring:    ${templates.length}');
  print('presets:      $presets');

  if (transactions.isNotEmpty) {
    final dates = transactions.map((t) => t.date).toList()..sort();
    String day(DateTime value) => value.toIso8601String().split('T').first;
    print('date range:   ${day(dates.first)} .. ${day(dates.last)}');
    print('with remoteId: ${transactions.where((t) => t.remoteId != null).length}');

    final byState = <SyncState, int>{};
    for (final t in transactions) {
      byState[t.syncState] = (byState[t.syncState] ?? 0) + 1;
    }
    print('sync states:  $byState');
  }

  await isar.close();
}
