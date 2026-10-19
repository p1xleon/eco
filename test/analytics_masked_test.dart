import 'package:eco/core/privacy/transaction_visibility.dart';
import 'package:eco/features/analytics/domain/analytics_aggregation.dart';
import 'package:eco/features/analytics/presentation/widgets/analytics_charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  const masked = TransactionVisibilityState(
    mode: TransactionVisibilityMode.masked,
  );
  const normal = TransactionVisibilityState();
  final slices = [
    const DonutSlice(label: 'Food', amount: 70, color: Colors.red),
    const DonutSlice(label: 'Rent', amount: 30, color: Colors.blue),
  ];
  final buckets = [
    BucketTotal(DateTime(2026, 1), expense: 10),
    BucketTotal(DateTime(2026, 2), expense: 90),
  ];

  testWidgets('masked mode replaces every chart with a notice', (tester) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            CategoryDonutCard(slices: slices, visibility: masked),
            TrendLineCard(
              buckets: buckets,
              daily: false,
              expense: true,
              color: Colors.red,
              visibility: masked,
            ),
            CashFlowCard(
              buckets: buckets,
              weekly: false,
              incomeColor: Colors.green,
              expenseColor: Colors.red,
              visibility: masked,
            ),
            WeekdayBarsCard(
              totals: const [1, 2, 3, 4, 5, 6, 7],
              color: Colors.red,
              visibility: masked,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(PieChart), findsNothing);
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Hidden while amounts are masked.'), findsNWidgets(4));
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('normal mode still draws the charts', (tester) async {
    await tester.pumpWidget(
      host(CategoryDonutCard(slices: slices, visibility: normal)),
    );

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('70%'), findsWidgets);
  });
}
