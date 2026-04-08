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

class TransactionListGrouped extends ConsumerStatefulWidget {
  final List<TransactionModel> transactions;
  final int collapseAllSignal;

  const TransactionListGrouped({
    super.key,
    required this.transactions,
    this.collapseAllSignal = 0,
  });

  @override
  ConsumerState<TransactionListGrouped> createState() =>
      _TransactionListGroupedState();
}

class _TransactionListGroupedState
    extends ConsumerState<TransactionListGrouped> {
  final Set<int> _collapsedMonthKeys = <int>{};

  void _toggleMonth(int monthKey) {
    setState(() {
      if (_collapsedMonthKeys.contains(monthKey)) {
        _collapsedMonthKeys.remove(monthKey);
      } else {
        _collapsedMonthKeys.add(monthKey);
      }
    });
  }

  @override
  void didUpdateWidget(covariant TransactionListGrouped oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.collapseAllSignal != widget.collapseAllSignal) {
      final grouped = groupTransactionsByMonth(widget.transactions);
      _collapsedMonthKeys
        ..clear()
        ..addAll(grouped.map((group) => group.monthKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupTransactionsByMonth(widget.transactions);
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
            isCollapsed: _collapsedMonthKeys.contains(group.monthKey),
            onToggle: () => _toggleMonth(group.monthKey),
            categoriesById: categoriesById,
            visibility: visibility,
          );
        },
      ),
      loading: () => ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: widget.transactions.length,
        itemBuilder: (context, index) =>
            TransactionCard(transaction: widget.transactions[index]),
      ),
      error: (_, _) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: widget.transactions.length,
        itemBuilder: (context, index) =>
            TransactionCard(transaction: widget.transactions[index]),
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  final TransactionMonthGroup group;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final Map<int, CategoryModel> categoriesById;
  final TransactionVisibilityState visibility;

  const _MonthSection({
    required this.group,
    required this.isCollapsed,
    required this.onToggle,
    required this.categoriesById,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                visibility.displayAmount(
                                  "+ ₹${group.income.toStringAsFixed(2)}",
                                ),
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                visibility.displayAmount(
                                  "- ₹${group.expense.toStringAsFixed(2)}",
                                ),
                                style: TextStyle(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isCollapsed)
            ...group.transactions.map(
              (tx) => _TransactionTile(
                tx: tx,
                category: categoriesById[tx.categoryId],
              ),
            ),
        ],
      ),
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
