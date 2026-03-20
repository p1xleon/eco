import 'package:isar_community/isar.dart';

import '../../../../core/database/isar_service.dart';
import '../models/transaction_mapper.dart';
import '../models/transaction_model.dart';
import '../remote/transaction_remote_source.dart';

class TransactionRepository {
  final TransactionRemoteSource remote;

  final Isar _isar = IsarService.isar;

  TransactionRepository(this.remote);

  Future<List<TransactionModel>> getAll() async {
    if (!remote.isAuthenticated) {
      return _getLocalTransactions();
    }

    try {
      await _uploadPendingLocalTransactions();
      final remoteTransactions = await fetchRemoteTransactions();
      await _syncLocalCache(remoteTransactions);
    } catch (_) {
      // Keep local data available when remote sync fails.
    }

    return _getLocalTransactions();
  }

  Future<void> _uploadPendingLocalTransactions() async {
    final unsyncedLocal = await _isar.transactionModels
        .filter()
        .remoteIdIsNull()
        .findAll();

    for (final local in unsyncedLocal) {
      try {
        final saved = await uploadTransaction(local);
        saved.id = local.id;
        saved.recurringId = local.recurringId;
        saved.status = local.status;

        await _isar.writeTxn(() async {
          await _isar.transactionModels.put(saved);
        });
      } catch (_) {
        // Keep unsynced local entries intact and retry on the next sync.
      }
    }
  }

  Future<TransactionModel> add(TransactionModel tx) async {
    if (remote.isAuthenticated) {
      try {
        final saved = await uploadTransaction(tx);
        saved.status = tx.status;
        saved.recurringId = tx.recurringId;
        await _isar.writeTxn(() async {
          await _isar.transactionModels.put(saved);
        });
        return saved;
      } catch (_) {}
    }

    await _isar.writeTxn(() async {
      await _isar.transactionModels.put(tx);
    });

    return tx;
  }

  Future<TransactionModel> update(TransactionModel tx) async {
    if (remote.isAuthenticated && tx.remoteId != null) {
      final saved = await updateRemoteTransaction(tx);
      saved.id = tx.id;
      saved.status = tx.status;
      saved.recurringId = tx.recurringId;

      await _isar.writeTxn(() async {
        await _isar.transactionModels.put(saved);
      });

      return saved;
    }

    await _isar.writeTxn(() async {
      await _isar.transactionModels.put(tx);
    });

    return tx;
  }

  Future<void> delete(int id) async {
    final local = await _isar.transactionModels.get(id);
    if (local == null) return;

    if (remote.isAuthenticated && local.remoteId != null) {
      await deleteRemoteTransaction(local.remoteId!);
    }

    await _isar.writeTxn(() async {
      await _isar.transactionModels.delete(local.id);
    });
  }

  Future<List<TransactionModel>> _getLocalTransactions() {
    return _isar.transactionModels.where().sortByDateDesc().findAll();
  }

  Future<void> _syncLocalCache(List<TransactionModel> transactions) async {
    final syncedLocal = await _isar.transactionModels
        .filter()
        .remoteIdIsNotNull()
        .findAll();
    final unsyncedLocal = await _isar.transactionModels
        .filter()
        .remoteIdIsNull()
        .findAll();
    final recurringIdsByRemoteId = <String, String?>{
      for (final tx in syncedLocal)
        if (tx.remoteId != null) tx.remoteId!: tx.recurringId,
    };
    final statusByRemoteId = <String, TransactionStatus>{
      for (final tx in syncedLocal)
        if (tx.remoteId != null) tx.remoteId!: tx.status,
    };

    for (final tx in transactions) {
      final recurringId = recurringIdsByRemoteId[tx.remoteId];
      if (recurringId != null) {
        tx.recurringId = recurringId;
      }
      final status = statusByRemoteId[tx.remoteId];
      if (status != null) {
        tx.status = status;
      }
    }

    await _isar.writeTxn(() async {
      await _isar.transactionModels.clear();
      await _isar.transactionModels.putAll(transactions);
      await _isar.transactionModels.putAll(unsyncedLocal);
    });
  }

  Future<TransactionModel> uploadTransaction(TransactionModel tx) async {
    final user = remote.currentUser;
    if (user == null) {
      return tx;
    }

    final data = await remote.addTransaction(tx.toJson(user.id));
    return TransactionMapper.fromJson(data);
  }

  Future<TransactionModel> updateRemoteTransaction(TransactionModel tx) async {
    final user = remote.currentUser;
    if (user == null || tx.remoteId == null) {
      return tx;
    }

    final data = await remote.updateTransaction(tx.remoteId!, tx.toJson(user.id));
    return TransactionMapper.fromJson(data);
  }

  Future<List<TransactionModel>> fetchRemoteTransactions() async {
    final data = await remote.fetchTransactions();

    return data.map((json) => TransactionMapper.fromJson(json)).toList();
  }

  Future<void> deleteRemoteTransaction(String id) async {
    await remote.deleteTransaction(id);
  }
}
