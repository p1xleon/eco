import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/transaction_list_grouped.dart';
import '../providers/transaction_filter_provider.dart';
import '../providers/transaction_provider.dart';
import '../../data/models/transaction_model.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context, ref),
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search transactions...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    ref
                        .read(transactionFilterProvider.notifier)
                        .setSearch(value);
                  },
                ),
              ),

              if (transactions.isEmpty)
                const Expanded(
                  child: Center(child: Text('No transactions found')),
                )
              else
                Expanded(
                  child: TransactionListGrouped(transactions: transactions),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}

void _showFilterDialog(BuildContext context, WidgetRef ref) {
  TransactionType? type;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Filters"),
        content: DropdownButtonFormField<TransactionType?>(
          initialValue: type,
          hint: const Text("Transaction Type"),
          items: [
            const DropdownMenuItem(value: null, child: Text("All")),
            ...TransactionType.values.map(
              (t) => DropdownMenuItem(value: t, child: Text(t.name)),
            ),
          ],
          onChanged: (v) {
            type = v;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(transactionFilterProvider.notifier).clear();
              Navigator.pop(context);
            },
            child: const Text("Clear"),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(transactionFilterProvider.notifier).setType(type);
              Navigator.pop(context);
            },
            child: const Text("Apply"),
          ),
        ],
      );
    },
  );
}
