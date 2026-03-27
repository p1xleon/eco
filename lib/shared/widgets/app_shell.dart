import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/privacy/transaction_visibility.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/transactions/presentation/pages/add_transaction_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/transactions/presentation/providers/transaction_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;

  final pages = const [
    DashboardPage(),
    TransactionsPage(),
    AnalyticsPage(),
    SettingsPage(),
  ];

  void onTap(int i) {
    setState(() {
      index = i;
    });
  }

  void _cycleVisibilityMode() {
    final visibility = ref.read(transactionVisibilityProvider);
    final notifier = ref.read(transactionVisibilityProvider.notifier);
    final transactions = ref.read(transactionsProvider).valueOrNull ?? const [];
    final nextMode = switch (visibility.mode) {
      TransactionVisibilityMode.normal => TransactionVisibilityMode.masked,
      TransactionVisibilityMode.masked => TransactionVisibilityMode.invisible,
      TransactionVisibilityMode.invisible => TransactionVisibilityMode.normal,
    };

    notifier.setMode(nextMode, existingTransactions: transactions);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Transaction visibility: ${_modeLabel(nextMode)}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _modeLabel(TransactionVisibilityMode mode) {
    return switch (mode) {
      TransactionVisibilityMode.normal => 'Normal',
      TransactionVisibilityMode.masked => 'Masked',
      TransactionVisibilityMode.invisible => 'Invisible',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      floatingActionButton: FloatingActionButton(
        shape: CircleBorder(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionPage()),
          );
        },
        child: const Icon(Icons.add),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _cycleVisibilityMode,
              child: const Icon(Icons.settings_outlined),
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
