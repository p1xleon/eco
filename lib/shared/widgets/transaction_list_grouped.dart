import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/group_transactions.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../../features/transactions/data/providers/transaction_repository_provider.dart';
import '../../features/transactions/presentation/providers/transaction_provider.dart';

class TransactionListGrouped extends ConsumerWidget {
  final List<TransactionModel> transactions;

  const TransactionListGrouped({super.key, required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = groupTransactionsByMonth(transactions);
    final months = grouped.entries.toList();

    return ListView.builder(
      itemCount: months.length,
      itemBuilder: (context, index) {
        final entry = months[index];

        return _MonthSection(month: entry.key, transactions: entry.value);
      },
    );
  }
}

class _MonthSection extends StatelessWidget {
  final String month;
  final List<TransactionModel> transactions;

  const _MonthSection({required this.month, required this.transactions});

  @override
  Widget build(BuildContext context) {
    double income = 0;
    double expense = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            month,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text(
                "+ ₹${income.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "- ₹${expense.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.deepOrangeAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        ...transactions.map((tx) => _TransactionTile(tx: tx)),
      ],
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final TransactionModel tx;

  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(transactionRepositoryProvider);
    final isExpense = tx.type == TransactionType.expense;
    final detailParts = [tx.payee, tx.paymentMethod]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await repo.delete(tx.id);
        ref.invalidate(transactionsProvider);
      },
      child: ListTile(
        title: Text(tx.title),
        subtitle: Text(
          [
            DateFormat("dd MMM yyyy").format(tx.date),
            if (detailParts.isNotEmpty) detailParts.join(' • '),
          ].join('\n'),
        ),
        isThreeLine: detailParts.isNotEmpty,
        trailing: Text(
          "₹${tx.amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: isExpense ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
