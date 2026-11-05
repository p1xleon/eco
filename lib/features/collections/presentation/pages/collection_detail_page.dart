import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/transaction_list_grouped.dart';
import '../../../transactions/presentation/pages/add_transaction_page.dart';
import '../../../transactions/presentation/providers/transaction_filter_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../domain/collection_totals.dart';
import '../providers/collection_provider.dart';
import 'collections_page.dart';

class CollectionDetailPage extends ConsumerWidget {
  final int collectionId;

  const CollectionDetailPage({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref
        .watch(collectionsByIdProvider)
        .valueOrNull?[collectionId];
    final visibility = ref.watch(transactionVisibilityProvider);
    final members =
        (ref.watch(visibleTransactionsProvider).valueOrNull ?? const [])
            .where((tx) => tx.collectionId == collectionId)
            .toList();
    final total =
        totalsByCollection(members)[collectionId] ??
        const CollectionTotals(income: 0, expense: 0);

    // Deleted here or on another device while open.
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This collection no longer exists.')),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AddTransactionPage(lockedCollectionId: collectionId),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                showCollectionEditor(context, ref, collection: collection),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                  'In',
                  visibility.displayAmount(formatMoney(total.income)),
                ),
                _Stat(
                  'Out',
                  visibility.displayAmount(formatMoney(total.expense)),
                ),
                _Stat('Net', visibility.displayAmount(formatMoney(total.net))),
              ],
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? const Center(
                    child: Text('No transactions yet. Tap Add transaction.'),
                  )
                : TransactionListGrouped(transactions: members),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete collection?'),
        content: const Text(
          'Its transactions are kept. They just leave the collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(collectionRepositoryProvider).delete(collectionId);
    if (ref.read(transactionFilterProvider).collectionId == collectionId) {
      ref.read(transactionFilterProvider.notifier).setCollection(null);
    }
    ref.invalidate(collectionsProvider);
    ref.invalidate(transactionsProvider);
    if (context.mounted) Navigator.pop(context);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
