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
      final remoteTransactions = await fetchRemoteTransactions();
      await _syncLocalCache(remoteTransactions);
    } catch (_) {
      // Keep local data available when remote sync fails.
    }

    return _getLocalTransactions();
  }

  Future<void> add(TransactionModel tx) async {
    if (remote.isAuthenticated) {
      try {
        final saved = await uploadTransaction(tx);
        await _isar.writeTxn(() async {
          await _isar.transactionModels.put(saved);
        });
        return;
      } catch (_) {}
    }

    await _isar.writeTxn(() async {
      await _isar.transactionModels.put(tx);
    });
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
    final unsyncedLocal = await _isar.transactionModels
        .filter()
        .remoteIdIsNull()
        .findAll();

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

  Future<List<TransactionModel>> fetchRemoteTransactions() async {
    final data = await remote.fetchTransactions();

    return data.map((json) => TransactionMapper.fromJson(json)).toList();
  }

  Future<void> deleteRemoteTransaction(String id) async {
    await remote.deleteTransaction(id);
  }
}
