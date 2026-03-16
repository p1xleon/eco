import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../recurring/presentation/pages/recurring_transactions_page.dart';
import '../../../../shared/widgets/transaction_list_grouped.dart';
import '../providers/transaction_filter_provider.dart';
import '../providers/transaction_provider.dart';
import '../../data/models/transaction_model.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _isRecurringTab => _tabController.index == 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: _isRecurringTab
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterDialog(context, ref),
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
            Tab(text: 'Recurring'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_isRecurringTab)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search transactions...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  ref.read(transactionFilterProvider.notifier).setSearch(value);
                },
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(
                  transactionsAsync: transactionsAsync,
                  filter: (transactions) => transactions,
                ),
                _buildTransactionsTab(
                  transactionsAsync: transactionsAsync,
                  filter: (transactions) => transactions
                      .where((tx) => tx.type == TransactionType.expense)
                      .toList(),
                ),
                _buildTransactionsTab(
                  transactionsAsync: transactionsAsync,
                  filter: (transactions) => transactions
                      .where((tx) => tx.type == TransactionType.income)
                      .toList(),
                ),
                const RecurringTransactionsView(showInlineAddButton: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab({
    required AsyncValue<List<TransactionModel>> transactionsAsync,
    required List<TransactionModel> Function(List<TransactionModel>) filter,
  }) {
    return transactionsAsync.when(
      data: (transactions) => _buildTransactionList(filter(transactions)),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  Widget _buildTransactionList(List<TransactionModel> transactions) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions found'));
    }
    return TransactionListGrouped(transactions: transactions);
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
