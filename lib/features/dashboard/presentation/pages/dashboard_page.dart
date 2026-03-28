import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/privacy/transaction_visibility.dart';
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
    final visibility = ref.watch(transactionVisibilityProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final transactionsAsync = ref.watch(visibleTransactionsProvider);

    if (visibility.isInvisible) {
      return Scaffold(
        appBar: AppBar(title: const Text("Dashboard")),
        body: RefreshIndicator(
          onRefresh: () => _refreshDashboard(ref),
          child: const _DashboardEmptyState(
            title: 'Dashboard Hidden',
            message:
                'Invisible mode hides existing transaction activity. Add a new transaction to see it in the Transactions tab.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: RefreshIndicator(
        onRefresh: () => _refreshDashboard(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            statsAsync.when(
              data: (stats) {
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Overview',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: "Expense",
                            value: visibility.displayAmount(
                              '₹${stats.expense.toStringAsFixed(2)}',
                            ),
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            label: "Income",
                            value: visibility.displayAmount(
                              '₹${stats.income.toStringAsFixed(2)}',
                            ),
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _refreshDashboard(WidgetRef ref) async {
  ref.invalidate(dashboardRecurringProvider);
  ref.invalidate(recurringTransactionsProvider);
  ref.invalidate(dueRecurringTransactionsProvider);
  await Future.wait([
    refreshTransactions(ref),
    ref.read(recurringTransactionsProvider.future),
  ]);
}

class _DashboardRecurringSection extends ConsumerWidget {
  const _DashboardRecurringSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(transactionVisibilityProvider);
    final recurringAsync = ref.watch(dashboardRecurringProvider);
    final scheme = Theme.of(context).colorScheme;

    if (visibility.isMasked) {
      return const _DashboardMaskedNoticeCard(
        title: 'Recurring',
        message: 'Recurring details are hidden in masked mode.',
      );
    }

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
    final visibleGroups = groups
        .where((group) => group.totalCount > 0)
        .toList();
    final totalVisibleCount = visibleGroups.fold<int>(
      0,
      (sum, group) => sum + group.totalCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.46),
                scheme.secondaryContainer.withValues(alpha: 0.24),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.event_repeat_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recurring',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.isEmpty
                          ? 'Nothing needs attention right now.'
                          : '$totalVisibleCount scheduled item${totalVisibleCount == 1 ? '' : 's'} in view',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RecurringOverviewPill(
                label: 'Overdue',
                count: snapshot.overdue.totalCount,
                color: scheme.error,
              ),
              _RecurringOverviewPill(
                label: 'Due Today',
                count: snapshot.dueToday.totalCount,
                color: scheme.primary,
              ),
              _RecurringOverviewPill(
                label: 'Upcoming',
                count: snapshot.upcoming.totalCount,
                color: scheme.tertiary,
              ),
            ],
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
    final scheme = theme.colorScheme;
    final title = switch (group.status) {
      DashboardRecurringStatus.overdue => 'Overdue',
      DashboardRecurringStatus.dueToday => 'Due Today',
      DashboardRecurringStatus.upcoming => 'Upcoming',
    };
    final accent = switch (group.status) {
      DashboardRecurringStatus.overdue => scheme.error,
      DashboardRecurringStatus.dueToday => scheme.primary,
      DashboardRecurringStatus.upcoming => scheme.tertiary,
    };
    final icon = switch (group.status) {
      DashboardRecurringStatus.overdue => Icons.warning_amber_rounded,
      DashboardRecurringStatus.dueToday => Icons.today_rounded,
      DashboardRecurringStatus.upcoming => Icons.schedule_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$title (${group.totalCount})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
          const SizedBox(height: 10),
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
      ),
    );
  }
}

class _DashboardRecurringItemTile extends ConsumerWidget {
  final RecurringTransactionModel item;
  final DashboardRecurringStatus status;

  const _DashboardRecurringItemTile({required this.item, required this.status});

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
    final typeLabel = item.type == TransactionType.expense
        ? 'Expense'
        : 'Income';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showRecurringActionDialog(context, ref, item),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusChip(status: status),
                        Text(
                          dueLabel,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      amountText,
                      style: TextStyle(
                        color: amountColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (item.note != null && item.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.note!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Confirm or skip',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
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
                    Navigator.pop(
                      dialogContext,
                      _RecurringDashboardAction.skip,
                    );
                  },
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsedAmount = double.tryParse(
                      amountController.text.trim(),
                    );
                    final hasAmountText = amountController.text
                        .trim()
                        .isNotEmpty;

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

class _RecurringOverviewPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _RecurringOverviewPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label · $count',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
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
      DashboardRecurringStatus.upcoming => ('Upcoming', scheme.tertiary),
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

class _DashboardEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _DashboardEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [_DashboardMaskedNoticeCard(title: title, message: message)],
    );
  }
}

class _DashboardMaskedNoticeCard extends StatelessWidget {
  final String title;
  final String message;

  const _DashboardMaskedNoticeCard({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
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
              value,
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
