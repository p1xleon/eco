import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../domain/analytics_aggregation.dart';

/// Slice of a donut chart.
class DonutSlice {
  final String label;
  final double amount;
  final Color color;

  const DonutSlice({
    required this.label,
    required this.amount,
    required this.color,
  });
}

String _money(TransactionVisibilityState v, double amount) =>
    v.displayAmount('₹${amount.toStringAsFixed(2)}');

/// Amount axes are omitted on purpose so masked mode never leaks values; tooltips are masked instead.
FlTitlesData _bottomTitles(List<DateTime> starts, bool daily) {
  final interval = daily
      ? 5.0
      : (starts.length / 6).ceilToDouble().clamp(1, 12).toDouble();
  return FlTitlesData(
    leftTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    topTitles: const AxisTitles(),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: interval,
        reservedSize: 28,
        getTitlesWidget: (value, meta) {
          final i = value.toInt();
          if (i < 0 || i >= starts.length) return const SizedBox.shrink();
          final text = daily
              ? '${starts[i].day}'
              : DateFormat('MMM').format(starts[i]);
          return SideTitleWidget(
            meta: meta,
            child: Text(text, style: const TextStyle(fontSize: 11)),
          );
        },
      ),
    ),
  );
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class CategoryDonutCard extends StatelessWidget {
  final List<DonutSlice> slices;
  final TransactionVisibilityState visibility;

  const CategoryDonutCard({
    super.key,
    required this.slices,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0.0, (sum, s) => sum + s.amount);
    final top = slices.first;

    return _ChartCard(
      title: 'Category Share',
      subtitle: 'How the total splits across categories.',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 62,
                    sections: [
                      for (final s in slices)
                        PieChartSectionData(
                          value: s.amount,
                          color: s.color,
                          radius: 30,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(top.amount / total * 100).round()}%',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      top.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in slices)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.label} ${(s.amount / total * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrendLineCard extends StatelessWidget {
  final List<BucketTotal> buckets;
  final bool daily;
  final bool expense;
  final Color color;
  final TransactionVisibilityState visibility;

  const TrendLineCard({
    super.key,
    required this.buckets,
    required this.daily,
    required this.expense,
    required this.color,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    final values = [for (final b in buckets) expense ? b.expense : b.income];
    final starts = [for (final b in buckets) b.start];
    final dateFormat = DateFormat(daily ? 'd MMM' : 'MMM yyyy');

    return _ChartCard(
      title: 'Trend',
      subtitle: daily ? 'Day by day.' : 'Month by month.',
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: _bottomTitles(starts, daily),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${dateFormat.format(starts[s.x.toInt()])}\n${_money(visibility, s.y)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < values.length; i++)
                    FlSpot(i.toDouble(), values[i]),
                ],
                isCurved: true,
                preventCurveOverShooting: true,
                color: color,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CashFlowCard extends StatelessWidget {
  final List<BucketTotal> buckets;
  final bool daily;
  final Color incomeColor;
  final Color expenseColor;
  final TransactionVisibilityState visibility;

  const CashFlowCard({
    super.key,
    required this.buckets,
    required this.daily,
    required this.incomeColor,
    required this.expenseColor,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    final starts = [for (final b in buckets) b.start];
    final dateFormat = DateFormat(daily ? 'd MMM' : 'MMM yyyy');
    final rodWidth = daily ? 3.0 : 8.0;

    return _ChartCard(
      title: 'Income vs Expense',
      subtitle: 'Cash in and cash out over the period.',
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: _bottomTitles(starts, daily),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${dateFormat.format(starts[group.x])}\n${_money(visibility, rod.toY)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < buckets.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 1,
                  barRods: [
                    BarChartRodData(
                      toY: buckets[i].income,
                      color: incomeColor,
                      width: rodWidth,
                    ),
                    BarChartRodData(
                      toY: buckets[i].expense,
                      color: expenseColor,
                      width: rodWidth,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeekdayBarsCard extends StatelessWidget {
  final List<double> totals;
  final Color color;
  final TransactionVisibilityState visibility;

  const WeekdayBarsCard({
    super.key,
    required this.totals,
    required this.color,
    required this.visibility,
  });

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final peak = totals.indexOf(totals.reduce((a, b) => a > b ? a : b));

    return _ChartCard(
      title: 'By Day of Week',
      subtitle: 'Busiest day: ${_days[peak]}.',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _days[value.toInt()],
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${_days[group.x]}\n${_money(visibility, rod.toY)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < totals.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: totals[i],
                      width: 18,
                      color: i == peak ? color : color.withValues(alpha: 0.4),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
