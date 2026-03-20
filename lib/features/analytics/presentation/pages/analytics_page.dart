import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        body: transactionsAsync.when(
          data: (transactions) {
            return categoriesAsync.when(
              data: (categories) {
                final categoriesById = {
                  for (final category in categories) category.id: category,
                };

                return TabBarView(
                  children: [
                    _AnalyticsBreakdownView(
                      type: TransactionType.expense,
                      transactions: transactions
                          .where((tx) => tx.type == TransactionType.expense)
                          .toList(),
                      categoriesById: categoriesById,
                    ),
                    _AnalyticsBreakdownView(
                      type: TransactionType.income,
                      transactions: transactions
                          .where((tx) => tx.type == TransactionType.income)
                          .toList(),
                      categoriesById: categoriesById,
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
        ),
      ),
    );
  }
}

class _AnalyticsBreakdownView extends StatelessWidget {
  final TransactionType type;
  final List<TransactionModel> transactions;
  final Map<int, CategoryModel> categoriesById;

  const _AnalyticsBreakdownView({
    required this.type,
    required this.transactions,
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
            subtitle: 'No $label data available yet.',
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
    final categoryItems = _buildBreakdownItems(
      transactions,
      labelFor: (tx) => categoriesById[tx.categoryId]?.name ?? 'Unknown',
      colorFor: (tx) {
        final category = categoriesById[tx.categoryId];
        return category != null ? Color(category.color) : accent;
      },
    );
    final paymentMethodItems = _buildBreakdownItems(
      transactions,
      labelFor: (tx) => _normalizedValue(tx.paymentMethod),
      colorFor: (_) => scheme.secondary,
    );
    final payeeItems = _buildBreakdownItems(
      transactions,
      labelFor: (tx) => _normalizedValue(tx.payee),
      colorFor: (_) => scheme.tertiary,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _AnalyticsHeroCard(
          title: '$label Analytics',
          subtitle: type == TransactionType.expense
              ? 'Track where money is going and who gets paid.'
              : 'Track where money comes from and how it lands.',
          accent: accent,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AnalyticsStatCard(
              label: 'Total',
              value: '₹${total.toStringAsFixed(2)}',
              accent: accent,
            ),
            _AnalyticsStatCard(
              label: 'Average',
              value: '₹${average.toStringAsFixed(2)}',
              accent: scheme.secondary,
            ),
            _AnalyticsStatCard(
              label: 'Entries',
              value: transactions.length.toString(),
              accent: scheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _HighlightCard(
          title: type == TransactionType.expense
              ? 'Largest expense'
              : 'Largest income',
          value: highest.title,
          meta: '₹${highest.amount.toStringAsFixed(2)}',
          accent: accent,
        ),
        const SizedBox(height: 16),
        _BreakdownSection(
          title: 'By Category',
          subtitle: 'Which categories dominate this side of your cash flow.',
          items: categoryItems,
        ),
        const SizedBox(height: 16),
        _BreakdownSection(
          title: 'By Payment Method',
          subtitle: 'How these transactions are usually handled.',
          items: paymentMethodItems,
        ),
        const SizedBox(height: 16),
        _BreakdownSection(
          title: type == TransactionType.expense ? 'Paid To' : 'Received From',
          subtitle: type == TransactionType.expense
              ? 'Who takes most of the money.'
              : 'Who contributes most of the income.',
          items: payeeItems,
        ),
      ],
    );
  }

  List<_BreakdownItemData> _buildBreakdownItems(
    List<TransactionModel> source, {
    required String Function(TransactionModel tx) labelFor,
    required Color Function(TransactionModel tx) colorFor,
  }) {
    final totals = <String, double>{};
    final colors = <String, Color>{};

    for (final tx in source) {
      final label = labelFor(tx);
      totals[label] = (totals[label] ?? 0) + tx.amount;
      colors[label] ??= colorFor(tx);
    }

    final items = totals.entries
        .map(
          (entry) => _BreakdownItemData(
            label: entry.key,
            amount: entry.value,
            color: colors[entry.key]!,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return items.take(6).toList();
  }

  String _normalizedValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Unspecified';
    }

    return value.trim();
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.32)),
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

  const _AnalyticsStatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 160,
      child: Container(
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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

class _BreakdownSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_BreakdownItemData> items;

  const _BreakdownSection({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxAmount = items.isEmpty
        ? 0.0
        : items
              .map((item) => item.amount)
              .reduce((current, next) => current > next ? current : next);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          ...items.map((item) => _BreakdownRow(item: item, maxAmount: maxAmount)),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final _BreakdownItemData item;
  final double maxAmount;

  const _BreakdownRow({required this.item, required this.maxAmount});

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
                '₹${item.amount.toStringAsFixed(2)}',
                style: TextStyle(color: item.color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
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
