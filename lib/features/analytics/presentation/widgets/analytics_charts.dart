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

String _short(TransactionVisibilityState v, double amount) =>
    v.displayAmount(compactAmount(amount));

const _tooltipStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w700,
);

/// Axes for a chart with [count] x positions. The value axis is dropped in masked
/// mode so axis labels never leak amounts; tooltips are masked instead.
FlTitlesData _titles({
  required TransactionVisibilityState visibility,
  required int count,
  required String Function(int index) labelFor,
  required double interval,
}) {
  return FlTitlesData(
    rightTitles: const AxisTitles(),
    topTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: !visibility.isMasked,
        reservedSize: 46,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(
            compactAmount(value),
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        interval: interval,
        reservedSize: 28,
        getTitlesWidget: (value, meta) {
          final i = value.toInt();
          if (i < 0 || i >= count) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            child: Text(labelFor(i), style: const TextStyle(fontSize: 11)),
          );
        },
      ),
    ),
  );
}

/// Axis and tooltip date formats that stay unambiguous: years for yearly
/// buckets, "MMM yy" once monthly buckets cross a year boundary.
({DateFormat axis, DateFormat tooltip}) _monthlyFormats(List<DateTime> starts) {
  if (starts.length > 1 && starts[1].difference(starts[0]).inDays >= 360) {
    return (axis: DateFormat('yyyy'), tooltip: DateFormat('yyyy'));
  }
  final crossesYears =
      starts.isNotEmpty && starts.first.year != starts.last.year;
  return (
    axis: DateFormat(crossesYears ? "MMM ''yy" : 'MMM'),
    tooltip: DateFormat('MMM yyyy'),
  );
}

/// Gives each monthly/yearly bucket its own slot so every label stays legible;
/// when the slots don't fit the card, the chart scrolls sideways from the latest end.
class _ScrollableChart extends StatelessWidget {
  final int count;
  final bool enabled;
  final Widget child;

  const _ScrollableChart({
    required this.count,
    required this.enabled,
    required this.child,
  });

  static const _slotWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = count * _slotWidth;
        if (needed <= constraints.maxWidth) return child;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: SizedBox(width: needed, child: child),
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final String? caption;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.caption,
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
          if (caption != null) ...[
            const SizedBox(height: 12),
            Text(
              caption!,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    final textTheme = Theme.of(context).textTheme;

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
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        top.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final s in slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _money(visibility, s.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${(s.amount / total * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
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
    final formats = _monthlyFormats(starts);
    final dateFormat = daily ? DateFormat('d MMM') : formats.tooltip;
    final total = values.fold(0.0, (a, b) => a + b);
    final peak = values.indexOf(values.reduce((a, b) => a > b ? a : b));

    return _ChartCard(
      title: 'Trend',
      subtitle: daily
          ? 'Day by day.'
          : (formats.axis.pattern == 'yyyy'
                ? 'Year by year.'
                : 'Month by month.'),
      caption:
          'Peak ${_short(visibility, values[peak])} on ${dateFormat.format(starts[peak])} · Total ${_short(visibility, total)}',
      child: SizedBox(
        height: 200,
        child: _ScrollableChart(
          count: starts.length,
          enabled: !daily,
          child: LineChart(
            LineChartData(
              minY: 0,
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: _titles(
                visibility: visibility,
                count: starts.length,
                interval: daily ? 5 : 1,
                labelFor: (i) =>
                    daily ? '${starts[i].day}' : formats.axis.format(starts[i]),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${dateFormat.format(starts[s.x.toInt()])}\n${_money(visibility, s.y)}',
                        _tooltipStyle,
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
      ),
    );
  }
}

/// Income vs expense. [weekly] means [buckets] are 7-day weeks (single-month period).
class CashFlowCard extends StatelessWidget {
  final List<BucketTotal> buckets;
  final bool weekly;
  final Color incomeColor;
  final Color expenseColor;
  final TransactionVisibilityState visibility;

  const CashFlowCard({
    super.key,
    required this.buckets,
    required this.weekly,
    required this.incomeColor,
    required this.expenseColor,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    final starts = [for (final b in buckets) b.start];
    final formats = _monthlyFormats(starts);
    final dateFormat = weekly ? DateFormat('d MMM') : formats.tooltip;
    final income = buckets.fold(0.0, (s, b) => s + b.income);
    final expense = buckets.fold(0.0, (s, b) => s + b.expense);
    final scheme = Theme.of(context).colorScheme;

    Widget key(Color c, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );

    return _ChartCard(
      title: 'Income vs Expense',
      subtitle: weekly
          ? 'Week by week.'
          : (formats.axis.pattern == 'yyyy'
                ? 'Year by year.'
                : 'Month by month.'),
      caption:
          'Income ${_short(visibility, income)} · Expense ${_short(visibility, expense)} · Net ${_short(visibility, income - expense)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            children: [
              key(incomeColor, 'Income'),
              key(expenseColor, 'Expense'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _ScrollableChart(
              count: buckets.length,
              enabled: !weekly,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: _titles(
                    visibility: visibility,
                    count: buckets.length,
                    interval: 1,
                    labelFor: (i) =>
                        weekly ? 'W${i + 1}' : formats.axis.format(starts[i]),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${weekly ? 'Week of ' : ''}${dateFormat.format(starts[group.x])}\n${_money(visibility, rod.toY)}',
                        _tooltipStyle,
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 2,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[i].income,
                            color: incomeColor,
                            width: weekly ? 14 : 8,
                          ),
                          BarChartRodData(
                            toY: buckets[i].expense,
                            color: expenseColor,
                            width: weekly ? 14 : 8,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      subtitle: 'Which weekday carries the most.',
      caption: 'Busiest: ${_days[peak]} (${_short(visibility, totals[peak])})',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: _titles(
              visibility: visibility,
              count: 7,
              interval: 1,
              labelFor: (i) => _days[i],
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${_days[group.x]}\n${_money(visibility, rod.toY)}',
                  _tooltipStyle,
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
