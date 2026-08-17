import 'package:isar_community/isar.dart';

import '../../../../core/database/isar_service.dart';
import '../../../../core/sync/sync_state.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../data/models/recurring_transaction_model.dart';

class RecurringRecoveryInspection {
  final int existingTemplateCount;
  final int linkedTransactionCount;
  final List<MissingRecurringTemplateCandidate> missingCandidates;

  const RecurringRecoveryInspection({
    required this.existingTemplateCount,
    required this.linkedTransactionCount,
    required this.missingCandidates,
  });

  bool get hasMissingCandidates => missingCandidates.isNotEmpty;
}

class MissingRecurringTemplateCandidate {
  final int templateId;
  final String title;
  final TransactionType type;
  final int categoryId;
  final String? note;
  final double? defaultAmount;
  final RecurringAmountType amountType;
  final DateTime nextDueDate;
  final DateTime createdAt;
  final int linkedTransactionCount;

  const MissingRecurringTemplateCandidate({
    required this.templateId,
    required this.title,
    required this.type,
    required this.categoryId,
    required this.note,
    required this.defaultAmount,
    required this.amountType,
    required this.nextDueDate,
    required this.createdAt,
    required this.linkedTransactionCount,
  });

  RecurringTransactionModel toTemplate(DateTime updatedAt) {
    return RecurringTransactionModel()
      ..id = templateId
      ..title = title
      ..type = type
      ..defaultAmount = defaultAmount
      ..amountType = amountType
      ..categoryId = categoryId
      ..accountId = null
      ..intervalType = RecurringIntervalType.monthly
      ..intervalCount = 1
      ..nextDueDate = nextDueDate
      ..endDate = null
      ..isActive = false
      ..note = note
      ..createdAt = createdAt
      ..updatedAt = updatedAt
      // Rebuilt from local transactions, so the server has never seen it.
      ..syncState = SyncState.pendingCreate
      ..localUpdatedAt = updatedAt;
  }
}

class RecurringRecoveryResult {
  final int recoveredCount;
  final List<MissingRecurringTemplateCandidate> recoveredCandidates;

  const RecurringRecoveryResult({
    required this.recoveredCount,
    required this.recoveredCandidates,
  });
}

class RecurringRecoveryService {
  const RecurringRecoveryService();

  Future<RecurringRecoveryInspection> inspect() async {
    final isar = IsarService.isar;
    final allTemplates = await isar.recurringTransactionModels
        .where()
        .anyId()
        .findAll();
    final allTransactions = await isar.transactionModels
        .where()
        .anyId()
        .findAll();

    // Records awaiting a delete are on their way out, so they neither count as
    // present nor justify rebuilding anything.
    final templates = allTemplates
        .where((template) => template.syncState.isVisible)
        .toList();
    final transactions = allTransactions
        .where((transaction) => transaction.syncState.isVisible)
        .toList();

    // Deleted templates keep their ids reserved so a pending delete is not
    // undone by recovering the very template the user just removed.
    final existingTemplateIds = allTemplates
        .map((template) => template.id)
        .toSet();
    final grouped = <int, List<TransactionModel>>{};
    var linkedTransactionCount = 0;

    for (final transaction in transactions) {
      final templateId = _resolveTemplateId(transaction);
      if (templateId == null) {
        continue;
      }

      linkedTransactionCount++;
      if (existingTemplateIds.contains(templateId)) {
        continue;
      }

      grouped
          .putIfAbsent(templateId, () => <TransactionModel>[])
          .add(transaction);
    }

    final missingCandidates =
        grouped.entries
            .map((entry) => _buildCandidate(entry.key, entry.value))
            .toList()
          ..sort((a, b) => a.templateId.compareTo(b.templateId));

    return RecurringRecoveryInspection(
      existingTemplateCount: templates.length,
      linkedTransactionCount: linkedTransactionCount,
      missingCandidates: missingCandidates,
    );
  }

  Future<RecurringRecoveryResult> recoverMissingTemplates() async {
    final inspection = await inspect();
    final now = DateTime.now().toUtc();
    final isar = IsarService.isar;

    if (!inspection.hasMissingCandidates) {
      return const RecurringRecoveryResult(
        recoveredCount: 0,
        recoveredCandidates: [],
      );
    }

    await isar.writeTxn(() async {
      for (final candidate in inspection.missingCandidates) {
        await isar.recurringTransactionModels.put(candidate.toTemplate(now));
      }
    });

    return RecurringRecoveryResult(
      recoveredCount: inspection.missingCandidates.length,
      recoveredCandidates: inspection.missingCandidates,
    );
  }

  MissingRecurringTemplateCandidate _buildCandidate(
    int templateId,
    List<TransactionModel> transactions,
  ) {
    final sorted = [...transactions]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first;
    final latest = sorted.last;
    final nonEmptyNote = sorted
        .map((tx) => tx.note?.trim())
        .whereType<String>()
        .where((note) => note.isNotEmpty)
        .lastOrNull;
    final distinctAmounts = sorted.map((tx) => tx.amount).toSet();
    final fixedAmount = distinctAmounts.length == 1 ? latest.amount : null;

    return MissingRecurringTemplateCandidate(
      templateId: templateId,
      title: latest.title.trim().isEmpty
          ? 'Recovered template #$templateId'
          : latest.title.trim(),
      type: latest.type,
      categoryId: latest.categoryId,
      note: nonEmptyNote,
      defaultAmount: fixedAmount ?? latest.amount,
      amountType: distinctAmounts.length == 1
          ? RecurringAmountType.fixed
          : RecurringAmountType.variable,
      nextDueDate: latest.date,
      createdAt: first.createdAt,
      linkedTransactionCount: sorted.length,
    );
  }

  int? _resolveTemplateId(TransactionModel transaction) {
    if (transaction.recurringTemplateId != null &&
        transaction.recurringTemplateId! > 0) {
      return transaction.recurringTemplateId;
    }

    final recurringId = transaction.recurringId?.trim();
    if (recurringId == null || recurringId.isEmpty) {
      return null;
    }

    return int.tryParse(recurringId);
  }
}
