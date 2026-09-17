// Re-parents a recovered Isar database onto a fresh Supabase project.
//
// Every record points at a `remoteId` from the deleted project. Left alone, the
// first pull deletes them all: the sync merge treats "synced, but the server
// has never heard of it" as deleted on another device. Clearing the ids turns
// each record back into a pending create, which the push path then uploads.
//
// Operates on a COPY pulled off the device, never on the device itself.
//
// Usage: dart run tool/reset_sync_state.dart <dir containing default.isar>
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

  // A local delete that the old server never confirmed. The row is gone from
  // the user's view already, so re-uploading it would resurrect it.
  final dropped = [
    ...transactions.where((t) => t.syncState == SyncState.pendingDelete),
  ];
  final droppedCategories = [
    ...categories.where((c) => c.syncState == SyncState.pendingDelete),
  ];
  final droppedTemplates = [
    ...templates.where((t) => t.syncState == SyncState.pendingDelete),
  ];

  final keptTransactions = transactions
      .where((t) => t.syncState != SyncState.pendingDelete)
      .toList();
  final keptCategories = categories
      .where((c) => c.syncState != SyncState.pendingDelete)
      .toList();
  final keptTemplates = templates
      .where((t) => t.syncState != SyncState.pendingDelete)
      .toList();

  for (final item in keptTransactions) {
    item.remoteId = null;
    item.syncState = SyncState.pendingCreate;
    item.syncAttempts = 0;
  }
  for (final item in keptCategories) {
    item.remoteId = null;
    item.syncState = SyncState.pendingCreate;
    item.syncAttempts = 0;
  }
  for (final item in keptTemplates) {
    item.remoteId = null;
    item.syncState = SyncState.pendingCreate;
    item.syncAttempts = 0;
  }

  await isar.writeTxn(() async {
    await isar.transactionModels.deleteAll([for (final t in dropped) t.id]);
    await isar.categoryModels
        .deleteAll([for (final c in droppedCategories) c.id]);
    await isar.recurringTransactionModels
        .deleteAll([for (final t in droppedTemplates) t.id]);

    await isar.transactionModels.putAll(keptTransactions);
    await isar.categoryModels.putAll(keptCategories);
    await isar.recurringTransactionModels.putAll(keptTemplates);
  });

  print('queued for upload:');
  print('  transactions: ${keptTransactions.length}');
  print('  categories:   ${keptCategories.length}');
  print('  recurring:    ${keptTemplates.length}');
  print('dropped local-only deletes: '
      '${dropped.length + droppedCategories.length + droppedTemplates.length}');

  await isar.close();
}
