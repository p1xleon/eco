import 'package:flutter/material.dart';
import '../../core/utils/money.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/privacy/transaction_visibility.dart';
import '../../core/utils/group_transactions.dart';
import '../../features/categories/data/models/category_model.dart';
import '../../features/collections/presentation/providers/collection_provider.dart';
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
  final Set<int> _selectedTransactionIds = <int>{};
  static final NumberFormat _amountFormat = NumberFormat('#,##0.00');

  bool get _isSelectionMode => _selectedTransactionIds.isNotEmpty;

  void _startSelectionMode(TransactionModel transaction) {
    setState(() {
      _selectedTransactionIds
        ..clear()
        ..add(transaction.id);
    });
  }

  void _toggleSelected(TransactionModel transaction) {
    setState(() {
      if (_selectedTransactionIds.contains(transaction.id)) {
        _selectedTransactionIds.remove(transaction.id);
      } else {
        _selectedTransactionIds.add(transaction.id);
      }
    });
  }

  Future<void> _moveSelectedToCollection() async {
    final collections = ref.read(collectionsProvider).valueOrNull ?? const [];
    final messenger = ScaffoldMessenger.of(context);
    if (collections.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Create a collection first')),
      );
      return;
    }
    // -1 = remove from its collection; null = sheet dismissed.
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in collections)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(c.name),
                onTap: () => Navigator.pop(context, c.id),
              ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Remove from collection'),
              onTap: () => Navigator.pop(context, -1),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;

    final repo = ref.read(transactionRepositoryProvider);
    final selected = widget.transactions
        .where((tx) => _selectedTransactionIds.contains(tx.id))
        .toList();
    try {
      for (final tx in selected) {
        tx.collectionId = picked == -1 ? null : picked;
        await repo.update(tx);
      }
      ref.invalidate(transactionsProvider);
      if (!mounted) return;
      _exitSelectionMode();
      messenger.showSnackBar(
        SnackBar(content: Text('Updated ${selected.length} transactions')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update transactions: $error')),
      );
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedTransactionIds.clear();
    });
  }

  double _selectedTotal(List<TransactionModel> transactions) {
    if (_selectedTransactionIds.isEmpty) return 0;
    return transactions
        .where((tx) => _selectedTransactionIds.contains(tx.id))
        .fold<double>(
          0,
          (sum, tx) =>
              sum +
              (tx.type == TransactionType.expense ? -tx.amount : tx.amount),
        );
  }

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

    if (_selectedTransactionIds.isNotEmpty) {
      final idsInList = widget.transactions.map((tx) => tx.id).toSet();
      _selectedTransactionIds.removeWhere((id) => !idsInList.contains(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupTransactionsByMonth(widget.transactions);
    final categoriesByIdAsync = ref.watch(categoriesByIdProvider);
    final visibility = ref.watch(transactionVisibilityProvider);

    return categoriesByIdAsync.when(
      data: (categoriesById) {
        final selectedTotal = _selectedTotal(widget.transactions);
        return Column(
          children: [
            if (_isSelectionMode)
              _SelectionSummaryBar(
                count: _selectedTransactionIds.length,
                total: selectedTotal,
                visibility: visibility,
                onDone: _exitSelectionMode,
                onAddToCollection: _moveSelectedToCollection,
              ),
            Expanded(
              child: ListView.builder(
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
                    isSelectionMode: _isSelectionMode,
                    selectedTransactionIds: _selectedTransactionIds,
                    onStartSelection: _startSelectionMode,
                    onToggleSelection: _toggleSelected,
                  );
                },
              ),
            ),
          ],
        );
      },
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
  final bool isSelectionMode;
  final Set<int> selectedTransactionIds;
  final ValueChanged<TransactionModel> onStartSelection;
  final ValueChanged<TransactionModel> onToggleSelection;

  const _MonthSection({
    required this.group,
    required this.isCollapsed,
    required this.onToggle,
    required this.categoriesById,
    required this.visibility,
    required this.isSelectionMode,
    required this.selectedTransactionIds,
    required this.onStartSelection,
    required this.onToggleSelection,
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
                                  "+ ${formatMoney(group.income)}",
                                ),
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                visibility.displayAmount(
                                  "- ${formatMoney(group.expense)}",
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
                isSelectionMode: isSelectionMode,
                isSelected: selectedTransactionIds.contains(tx.id),
                onStartSelection: onStartSelection,
                onToggleSelection: onToggleSelection,
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
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<TransactionModel> onStartSelection;
  final ValueChanged<TransactionModel> onToggleSelection;

  const _TransactionTile({
    required this.tx,
    required this.category,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onStartSelection,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(transactionRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    final card = TransactionCard(
      transaction: tx,
      category: category,
      isSelectionMode: isSelectionMode,
      isSelected: isSelected,
      onTapOverride: isSelectionMode ? () => onToggleSelection(tx) : null,
      onLongPressOverride: isSelectionMode ? () => onToggleSelection(tx) : null,
      onSelectMultiple: onStartSelection,
    );

    if (isSelectionMode) {
      return card;
    }

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
      child: card,
    );
  }
}

class _SelectionSummaryBar extends StatelessWidget {
  final int count;
  final double total;
  final TransactionVisibilityState visibility;
  final VoidCallback onDone;
  final VoidCallback onAddToCollection;

  const _SelectionSummaryBar({
    required this.count,
    required this.total,
    required this.visibility,
    required this.onDone,
    required this.onAddToCollection,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sign = total >= 0 ? '+' : '−';
    // The sign alone would tell income from expense, so masked hides the whole label.
    final amountLabel = visibility.displayAmount(
      '$sign ₹${_TransactionListGroupedState._amountFormat.format(total.abs())}',
    );
    final countLabel = '$count selected';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selection mode',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$countLabel • Total $amountLabel',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add to collection',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: onAddToCollection,
          ),
          TextButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
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
