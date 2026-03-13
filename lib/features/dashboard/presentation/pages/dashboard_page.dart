import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../transactions/data/models/transaction_model.dart';
import '../providers/dashboard_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          statsAsync.when(
            data: (stats) {
              return Column(
                children: [
                  _BalanceCard(balance: stats.balance),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: "Income",
                          value: stats.income,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: "Expense",
                          value: stats.expense,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text(e.toString()),
          ),

          const SizedBox(height: 24),

          const Text(
            "Recent Transactions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          transactionsAsync.when(
            data: (transactions) {
              final recent = transactions.take(5).toList();

              if (recent.isEmpty) {
                return const Text("No transactions yet");
              }

              return Column(
                children: recent.map((tx) => _RecentTile(tx)).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text(e.toString()),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Total Balance"),
            const SizedBox(height: 8),
            Text(
              "₹${balance.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label),
            const SizedBox(height: 6),
            Text(
              "₹${value.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final TransactionModel tx;

  const _RecentTile(this.tx);

  @override
  Widget build(BuildContext context) {
    final isExpense = tx.type == TransactionType.expense;
    final detailParts = [tx.payee, tx.paymentMethod]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();

    return ListTile(
      contentPadding: EdgeInsets.zero,
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
    );
  }
}
