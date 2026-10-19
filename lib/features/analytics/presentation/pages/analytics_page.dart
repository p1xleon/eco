import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../domain/analytics_aggregation.dart';
import '../providers/analytics_period_provider.dart';
import '../widgets/analytics_charts.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(transactionVisibilityProvider);
    final transactionsAsync = ref.watch(visibleTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final period = ref.watch(analyticsPeriodProvider);
    final now = DateTime.now();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        body: visibility.isInvisible
            ? const _AnalyticsEmptyState(
                title: 'Analytics Hidden',
                message:
                    'Invisible mode hides dashboard insights until you add new transactions in this mode.',
              )
            : Column(
                children: [
                  const _PeriodSelector(),
                  Expanded(
                    child: transactionsAsync.when(
                      data: (transactions) {
                        return categoriesAsync.when(
                          data: (categories) {
                            final categoriesById = {
                              for (final category in categories)
                                category.id: category,
                            };
                            final current = inRange(
                              transactions,
                              period.range(now),
                            );
                            final hasPrevious =
                                period.previousRange(now) != null;
                            final previous = inRange(
                              transactions,
                              period.previousRange(now),
                            );

                            Widget breakdown(TransactionType type) {
                              bool isType(TransactionModel tx) =>
                                  tx.type == type;
                              return _AnalyticsBreakdownView(
                                type: type,
                                period: period,
                                now: now,
                                visibility: visibility,
                                transactions: current.where(isType).toList(),
                                previousTotal: hasPrevious
                                    ? sumAmounts(previous.where(isType))
                                    : null,
                                categoriesById: categoriesById,
                              );
                            }

                            return TabBarView(
                              children: [
                                _OverviewView(
                                  period: period,
                                  now: now,
                                  visibility: visibility,
                                  transactions: current,
                                ),
                                breakdown(TransactionType.expense),
                                breakdown(TransactionType.income),
                              ],
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text(e.toString())),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text(e.toString())),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(analyticsPeriodProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final period in AnalyticsPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(period.label),
                selected: period == selected,
                onSelected: (_) =>
                    ref.read(analyticsPeriodProvider.notifier).state = period,
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewView extends StatelessWidget {
  final AnalyticsPeriod period;
  final DateTime now;
  final TransactionVisibilityState visibility;
  final List<TransactionModel> transactions;

  const _OverviewView({
    required this.period,
    required this.now,
    required this.visibility,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (transactions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeroCard(
            title: 'Overview',
            subtitle: 'No transactions for ${period.label.toLowerCase()}.',
            accent: scheme.primary,
          ),
        ],
      );
    }

    final income = sumAmounts(
      transactions.where((tx) => tx.type == TransactionType.income),
    );
    final expense = sumAmounts(
      transactions.where((tx) => tx.type == TransactionType.expense),
    );
    final net = income - expense;
    final savingsRate = income == 0 ? null : net / income * 100;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _StatGrid(
          children: [
            _AnalyticsStatCard(
              label: 'Income',
              value: visibility.displayAmount('₹${income.toStringAsFixed(2)}'),
              accent: scheme.primary,
            ),
            _AnalyticsStatCard(
              label: 'Expense',
              value: visibility.displayAmount('₹${expense.toStringAsFixed(2)}'),
              accent: scheme.error,
            ),
            _AnalyticsStatCard(
              label: 'Net',
              value: visibility.displayAmount('₹${net.toStringAsFixed(2)}'),
              accent: net >= 0 ? scheme.primary : scheme.error,
            ),
            _AnalyticsStatCard(
              label: 'Savings rate',
              value: savingsRate == null
                  ? '—'
                  : visibility.displayAmount(
                      '${savingsRate.toStringAsFixed(0)}%',
                    ),
              accent: scheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        CashFlowCard(
          buckets: period.isDaily
              ? toWeeklyBuckets(buildBuckets(transactions, period, now))
              : buildBuckets(transactions, period, now),
          weekly: period.isDaily,
          incomeColor: scheme.primary,
          expenseColor: scheme.error,
          visibility: visibility,
        ),
      ],
    );
  }
}

class _AnalyticsBreakdownView extends StatelessWidget {
  final TransactionType type;
  final AnalyticsPeriod period;
  final DateTime now;
  final TransactionVisibilityState visibility;
  final List<TransactionModel> transactions;
  final double? previousTotal;
  final Map<int, CategoryModel> categoriesById;

  const _AnalyticsBreakdownView({
    required this.type,
    required this.period,
    required this.now,
    required this.visibility,
    required this.transactions,
    required this.previousTotal,
    required this.categoriesById,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = type == TransactionType.expense
        ? scheme.error
        : scheme.primary;
    final label = type == TransactionType.expense ? 'Expense' : 'Income';

    if (transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _AnalyticsHeroCard(
            title: '$label Analytics',
            subtitle: 'No $label data for ${period.label.toLowerCase()}.',
            accent: accent,
          ),
        ],
      );
    }

    var total = 0.0;
    var highest = transactions.first;
    for (final tx in transactions) {
      total += tx.amount;
      if (tx.amount > highest.amount) {
        highest = tx;
      }
    }

    final average = total / transactions.length;
    final allCategoryItems = _buildBreakdownItems(
      transactions,
      limit: null,
      labelFor: (tx) => visibility.displayCategory(
        categoriesById[tx.categoryId]?.name ?? 'Unknown',
        seed: 'category:${tx.categoryId}',
      ),
      colorFor: (tx) {
        final category = categoriesById[tx.categoryId];
        return category != null ? Color(category.color) : accent;
      },
    );
    final categoryItems = allCategoryItems.take(6).toList();
    final donutSlices = [
      for (final item in allCategoryItems.take(5))
        DonutSlice(label: item.label, amount: item.amount, color: item.color),
      if (allCategoryItems.length > 5)
        DonutSlice(
          label: 'Other',
          amount: allCategoryItems.skip(5).fold(0.0, (s, i) => s + i.amount),
          color: scheme.outline,
        ),
    ];
    final change = previousTotal == null
        ? null
        : percentChange(total, previousTotal!);
    final isExpense = type == TransactionType.expense;
    final changeIsGood =
        change != null && (isExpense ? change <= 0 : change >= 0);
    final paymentMethodItems = _buildBreakdownItems(
      transactions,
      labelFor: (tx) => visibility.displayText(
        tx.paymentMethod,
        seed: 'payment:${tx.paymentMethod ?? ''}',
        placeholder: 'Unspecified',
      ),
      colorFor: (_) => scheme.secondary,
    );
    final payeeItems = _buildBreakdownItems(
      transactions,
      labelFor: (tx) => visibility.displayText(
        tx.payee,
        seed: 'payee:${tx.payee ?? ''}',
        placeholder: 'Unspecified',
      ),
      colorFor: (_) => scheme.tertiary,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _StatGrid(
          children: [
            _AnalyticsStatCard(
              label: 'Total',
              value: visibility.displayAmount('₹${total.toStringAsFixed(2)}'),
              accent: accent,
              footer: change == null || visibility.isMasked
                  ? null
                  : '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% vs previous',
              footerColor: changeIsGood ? scheme.primary : scheme.error,
            ),
            _AnalyticsStatCard(
              label: 'Average',
              value: visibility.displayAmount('₹${average.toStringAsFixed(2)}'),
              accent: scheme.secondary,
            ),
            _AnalyticsStatCard(
              label: 'Entries',
              value: transactions.length.toString(),
              accent: scheme.tertiary,
            ),
            _AnalyticsStatCard(
              label: 'Top category',
              value: allCategoryItems.first.label,
              accent: allCategoryItems.first.color,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HighlightCard(
          title: isExpense ? 'Largest expense' : 'Largest income',
          value: visibility.displayTitle(highest),
          meta: visibility.displayAmount(
            '₹${highest.amount.toStringAsFixed(2)}',
          ),
          accent: accent,
        ),
        const SizedBox(height: 16),
        TrendLineCard(
          buckets: buildBuckets(transactions, period, now),
          daily: period.isDaily,
          expense: isExpense,
          color: accent,
          visibility: visibility,
        ),
        const SizedBox(height: 16),
        CategoryDonutCard(slices: donutSlices, visibility: visibility),
        const SizedBox(height: 16),
        WeekdayBarsCard(
          totals: weekdayTotals(transactions),
          color: accent,
          visibility: visibility,
        ),
        const SizedBox(height: 16),
        _BreakdownTabsCard(
          tabs: [
            _BreakdownTab('Category', categoryItems),
            _BreakdownTab('Payment', paymentMethodItems),
            _BreakdownTab(isExpense ? 'Paid to' : 'From', payeeItems),
          ],
          visibility: visibility,
        ),
      ],
    );
  }

  List<_BreakdownItemData> _buildBreakdownItems(
    List<TransactionModel> source, {
    required String Function(TransactionModel tx) labelFor,
    required Color Function(TransactionModel tx) colorFor,
    int? limit = 6,
  }) {
    final totals = <String, double>{};
    final colors = <String, Color>{};

    for (final tx in source) {
      final label = labelFor(tx);
      totals[label] = (totals[label] ?? 0) + tx.amount;
      colors[label] ??= colorFor(tx);
    }

    final items =
        totals.entries
            .map(
              (entry) => _BreakdownItemData(
                label: entry.key,
                amount: entry.value,
                color: colors[entry.key]!,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return limit == null ? items : items.take(limit).toList();
  }
}

class _AnalyticsHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;

  const _AnalyticsHeroCard({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.08),
            scheme.surfaceContainerHighest.withValues(alpha: 0.92),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _AnalyticsStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final String? footer;
  final Color? footerColor;

  const _AnalyticsStatCard({
    required this.label,
    required this.value,
    required this.accent,
    this.footer,
    this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: footerColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String value;
  final String meta;
  final Color accent;

  const _HighlightCard({
    required this.title,
    required this.value,
    required this.meta,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.insights_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Text(
            meta,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Two-column grid of stat cards that fills the width.
class _StatGrid extends StatelessWidget {
  final List<Widget> children;

  const _StatGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _BreakdownTab {
  final String label;
  final List<_BreakdownItemData> items;

  const _BreakdownTab(this.label, this.items);
}

/// One card with a Category / Payment / Payee switch instead of three tall cards.
class _BreakdownTabsCard extends StatefulWidget {
  final List<_BreakdownTab> tabs;
  final TransactionVisibilityState visibility;

  const _BreakdownTabsCard({required this.tabs, required this.visibility});

  @override
  State<_BreakdownTabsCard> createState() => _BreakdownTabsCardState();
}

class _BreakdownTabsCardState extends State<_BreakdownTabsCard> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = widget.tabs[_selected].items;
    final maxAmount = items.isEmpty
        ? 0.0
        : items.map((i) => i.amount).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakdown',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < widget.tabs.length; i++)
                  ButtonSegment(value: i, label: Text(widget.tabs[i].label)),
              ],
              selected: {_selected},
              onSelectionChanged: (value) =>
                  setState(() => _selected = value.first),
            ),
          ),
          const SizedBox(height: 16),
          for (final item in items)
            _BreakdownRow(
              item: item,
              maxAmount: maxAmount,
              visibility: widget.visibility,
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final _BreakdownItemData item;
  final double maxAmount;
  final TransactionVisibilityState visibility;

  const _BreakdownRow({
    required this.item,
    required this.maxAmount,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    final widthFactor = maxAmount == 0 ? 0.0 : item.amount / maxAmount;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                visibility.displayAmount('₹${item.amount.toStringAsFixed(2)}'),
                style: TextStyle(
                  color: item.color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          // Bar lengths are ratios of the real amounts, so masked mode drops them.
          if (!visibility.isMasked) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: widthFactor,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(item.color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownItemData {
  final String label;
  final double amount;
  final Color color;

  _BreakdownItemData({
    required this.label,
    required this.amount,
    required this.color,
  });
}

class _AnalyticsEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _AnalyticsEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _AnalyticsHeroCard(
          title: title,
          subtitle: message,
          accent: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}
