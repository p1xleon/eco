import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/privacy/transaction_visibility.dart';
import '../../core/utils/group_transactions.dart';
import '../../features/categories/data/models/category_model.dart';
import '../../features/categories/presentation/providers/category_provider.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../../features/transactions/data/providers/transaction_repository_provider.dart';
import '../../features/transactions/presentation/providers/transaction_provider.dart';
import 'transaction_card.dart';

class TransactionListGrouped extends ConsumerWidget {
  final List<TransactionModel> transactions;

  const TransactionListGrouped({super.key, required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = groupTransactionsByMonth(transactions);
    final categoriesByIdAsync = ref.watch(categoriesByIdProvider);
    final visibility = ref.watch(transactionVisibilityProvider);

    return categoriesByIdAsync.when(
      data: (categoriesById) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final group = grouped[index];
          return _MonthSection(
            group: group,
            categoriesById: categoriesById,
            visibility: visibility,
          );
        },
      ),
      loading: () => ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: transactions.length,
        itemBuilder: (context, index) =>
            TransactionCard(transaction: transactions[index]),
      ),
      error: (_, _) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: transactions.length,
        itemBuilder: (context, index) =>
            TransactionCard(transaction: transactions[index]),
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  final TransactionMonthGroup group;
  final Map<int, CategoryModel> categoriesById;
  final TransactionVisibilityState visibility;

  const _MonthSection({
    required this.group,
    required this.categoriesById,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            group.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Text(
                visibility.displayAmount(
                  "+ ₹${group.income.toStringAsFixed(2)}",
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                visibility.displayAmount(
                  "- ₹${group.expense.toStringAsFixed(2)}",
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...group.transactions.map(
          (tx) =>
              _TransactionTile(tx: tx, category: categoriesById[tx.categoryId]),
        ),
      ],
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final TransactionModel tx;
  final CategoryModel? category;

  const _TransactionTile({required this.tx, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(transactionRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDeleteTransaction(context),
      onDismissed: (_) async {
        try {
          await repo.delete(tx.id);
          ref.invalidate(transactionsProvider);
        } catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete transaction: $error')),
          );
        }
      },
      child: TransactionCard(transaction: tx, category: category),
    );
  }
}

Future<bool> _confirmDeleteTransaction(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Transaction'),
      content: const Text('Are you sure you want to delete this transaction?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  return confirmed == true;
}
