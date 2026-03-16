import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../recurring/presentation/pages/recurring_transactions_page.dart';
import '../../../recurring/presentation/providers/recurring_transaction_provider.dart';
import '../../../recurring/domain/services/recurring_transaction_service.dart';
import '../../../recurring/data/models/recurring_transaction_model.dart';
import '../../../../shared/widgets/transaction_card.dart';
import '../providers/dashboard_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';
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

          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: _DashboardRecurringSection(),
          ),

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
                children: recent
                    .map(
                      (tx) => TransactionCard(
                        transaction: tx,
                        margin: const EdgeInsets.only(bottom: 12),
                      ),
                    )
                    .toList(),
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

class _DashboardRecurringSection extends ConsumerWidget {
  const _DashboardRecurringSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(dashboardRecurringProvider);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: recurringAsync.when(
          data: (snapshot) => _DashboardRecurringContent(snapshot: snapshot),
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_repeat_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recurring',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ),
          error: (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_repeat_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recurring',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(e.toString(), style: TextStyle(color: scheme.error)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardRecurringContent extends StatelessWidget {
  final DashboardRecurringSnapshot snapshot;

  const _DashboardRecurringContent({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM');
    final groups = [snapshot.overdue, snapshot.dueToday, snapshot.upcoming];
    final visibleGroups = groups.where((group) => group.totalCount > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_repeat_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recurring',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (snapshot.isEmpty) ...[
          Text(
            'Recurring — No bills due soon',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (snapshot.nextUpcomingItem != null) ...[
            const SizedBox(height: 6),
            Text(
              'Next up: ${snapshot.nextUpcomingItem!.title} on ${dateFormat.format(snapshot.nextUpcomingItem!.nextDueDate)}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ] else ...[
          Text(
            'A few recurring items from each status bucket are shown below.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ...visibleGroups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _DashboardRecurringGroupSection(group: group),
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardRecurringGroupSection extends StatelessWidget {
  final DashboardRecurringGroup group;

  const _DashboardRecurringGroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (group.status) {
      DashboardRecurringStatus.overdue => 'Overdue',
      DashboardRecurringStatus.dueToday => 'Due Today',
      DashboardRecurringStatus.upcoming => 'Upcoming',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$title (${group.totalCount})',
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecurringTransactionsPage(),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...group.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DashboardRecurringItemTile(
              item: item,
              status: group.status,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardRecurringItemTile extends ConsumerWidget {
  final RecurringTransactionModel item;
  final DashboardRecurringStatus status;

  const _DashboardRecurringItemTile({
    required this.item,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dueLabel = DateFormat('EEE, dd MMM').format(item.nextDueDate);
    final amountText = item.defaultAmount != null
        ? '₹${item.defaultAmount!.toStringAsFixed(2)}'
        : 'Set amount';
    final amountColor = item.type == TransactionType.expense
        ? scheme.error
        : scheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showRecurringActionDialog(context, ref, item),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(status: status),
                        Text(
                          dueLabel,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to confirm',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecurringActionDialog(
    BuildContext context,
    WidgetRef ref,
    RecurringTransactionModel template,
  ) async {
    final amountController = TextEditingController(
      text: template.defaultAmount?.toStringAsFixed(2) ?? '',
    );
    String? errorText;

    final action = await showDialog<_RecurringDashboardAction>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(template.title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Confirm this recurring transaction or skip it.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      errorText: errorText,
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, _RecurringDashboardAction.skip);
                  },
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsedAmount = double.tryParse(
                      amountController.text.trim(),
                    );
                    final hasAmountText = amountController.text.trim().isNotEmpty;

                    if (hasAmountText &&
                        (parsedAmount == null || parsedAmount <= 0)) {
                      setDialogState(() {
                        errorText = 'Enter a valid amount';
                      });
                      return;
                    }

                    if (!hasAmountText &&
                        template.amountType == RecurringAmountType.variable) {
                      setDialogState(() {
                        errorText = 'Amount is required';
                      });
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      _RecurringDashboardAction.confirm,
                    );
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (action == null) {
      amountController.dispose();
      return;
    }

    final service = ref.read(recurringTransactionServiceProvider);
    try {
      if (action == _RecurringDashboardAction.skip) {
        await service.skipRecurringTransaction(template);
      } else {
        final amount = double.tryParse(amountController.text.trim());
        await service.confirmRecurringTransaction(template, amount: amount);
      }
      _refreshDashboardData(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_buildErrorMessage(error))));
    } finally {
      amountController.dispose();
    }
  }

  void _refreshDashboardData(WidgetRef ref) {
    ref.invalidate(recurringTransactionsProvider);
    ref.invalidate(dueRecurringTransactionsProvider);
    ref.invalidate(dashboardRecurringProvider);
    ref.invalidate(transactionsProvider);
  }

  String _buildErrorMessage(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'Failed to confirm recurring transaction.';
    }

    return message;
  }
}

class _StatusChip extends StatelessWidget {
  final DashboardRecurringStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      DashboardRecurringStatus.overdue => ('Overdue', scheme.error),
      DashboardRecurringStatus.dueToday => ('Due today', scheme.primary),
      DashboardRecurringStatus.upcoming => (
        'Upcoming',
        scheme.tertiary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum _RecurringDashboardAction { confirm, skip }

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
