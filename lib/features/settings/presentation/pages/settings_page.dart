import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/theme/theme_mode_setting.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../categories/presentation/pages/categories_page.dart';
import 'transaction_presets_page.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Manage Categories"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoriesPage()),
              );
            },
          ),

          ListTile(
            title: const Text("Transaction Presets"),
            subtitle: const Text("Payment methods and stores / payees"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionPresetsPage(),
                ),
              );
            },
          ),

          const Divider(),

          ListTile(
            title: const Text("Theme"),
            subtitle: Text(theme.name),
            trailing: DropdownButton<ThemeModeSetting>(
              value: theme,
              underline: const SizedBox(),
              items: ThemeModeSetting.values
                  .map(
                    (mode) =>
                        DropdownMenuItem(value: mode, child: Text(mode.name)),
                  )
                  .toList(),
              onChanged: (mode) {
                if (mode != null) notifier.setTheme(mode);
              },
            ),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            textColor: Theme.of(context).colorScheme.error,
            iconColor: Theme.of(context).colorScheme.error,
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Logout"),
        content: const Text(
          "This will clear all local data on this device and sign you out.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      );
    },
  );

  if (shouldLogout != true) return;

  final auth = ref.read(authRepositoryProvider);

  await IsarService.resetLocalData();
  await auth.signOut();

  ref.invalidate(transactionsProvider);
  ref.invalidate(categoriesProvider);
}
