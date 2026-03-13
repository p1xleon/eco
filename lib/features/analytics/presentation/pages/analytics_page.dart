import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Analytics")),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text("No data"));
          }

          double income = 0;
          double expense = 0;

          for (final tx in transactions) {
            if (tx.type == TransactionType.income) {
              income += tx.amount;
            } else {
              expense += tx.amount;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "Income vs Expense",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: income,
                          color: Colors.green,
                          title: "Income",
                        ),
                        PieChartSectionData(
                          value: expense,
                          color: Colors.red,
                          title: "Expense",
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                _Summary(income: income, expense: expense),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final double income;
  final double expense;

  const _Summary({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.green),
          title: const Text("Total Income"),
          trailing: Text("₹${income.toStringAsFixed(2)}"),
        ),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.red),
          title: const Text("Total Expense"),
          trailing: Text("₹${expense.toStringAsFixed(2)}"),
        ),
      ],
    );
  }
}
