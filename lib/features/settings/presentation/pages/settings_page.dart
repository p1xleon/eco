import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/theme/theme_mode_setting.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../categories/presentation/pages/categories_page.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../recurring/presentation/pages/recurring_transactions_page.dart';
import '../../../recurring/presentation/providers/recurring_transaction_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../providers/transaction_preset_provider.dart';
import 'transaction_presets_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final authState = ref.watch(authStateProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodPresetsAsync = ref.watch(paymentMethodPresetsProvider);
    final payeePresetsAsync = ref.watch(payeePresetsProvider);
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final scheme = Theme.of(context).colorScheme;

    final categoryCount = categoriesAsync.valueOrNull?.length ?? 0;
    final recurringCount = recurringAsync.valueOrNull?.length ?? 0;
    final transactionCount = transactionsAsync.valueOrNull?.length ?? 0;
    final presetCount =
        (paymentMethodPresetsAsync.valueOrNull?.length ?? 0) +
        (payeePresetsAsync.valueOrNull?.length ?? 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: authState.when(
              data: (user) => _ProfileCard(user: user),
              loading: () => const _LoadingCard(),
              error: (_, _) => const _ProfileCard(user: null),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Transactions',
                    value: transactionCount.toString(),
                    icon: Icons.receipt_long_outlined,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Categories',
                    value: categoryCount.toString(),
                    icon: Icons.category_outlined,
                    color: scheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Recurring',
                    value: recurringCount.toString(),
                    icon: Icons.event_repeat_outlined,
                    color: scheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Customize',
            children: [
              _SettingsActionTile(
                icon: Icons.category_outlined,
                title: 'Manage Categories',
                subtitle: 'Update your income and expense buckets',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesPage()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _SettingsActionTile(
                icon: Icons.tune_outlined,
                title: 'Transaction Presets',
                subtitle: '$presetCount saved presets',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionPresetsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _SettingsActionTile(
                icon: Icons.event_repeat_outlined,
                title: 'Recurring Transactions',
                subtitle: '$recurringCount template${recurringCount == 1 ? '' : 's'}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecurringTransactionsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Appearance',
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.palette_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Theme',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Choose how the app should appear',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ThemeModeSetting>(
                      initialValue: theme,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: scheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: ThemeModeSetting.values
                          .map(
                            (mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(_themeLabel(mode)),
                            ),
                          )
                          .toList(),
                      onChanged: (mode) {
                        if (mode != null) notifier.setTheme(mode);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current: ${_themeLabel(theme)}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Account',
            children: [
              _DangerTile(
                title: 'Logout',
                subtitle: 'Clear local data on this device and sign out',
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeModeSetting mode) {
    return switch (mode) {
      ThemeModeSetting.system => 'System',
      ThemeModeSetting.light => 'Light',
      ThemeModeSetting.dark => 'Dark',
    };
  }
}

class _ProfileCard extends StatelessWidget {
  final User? user;

  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = user?.email ?? 'Not signed in';
    final name = _displayName(user);
    final joined = user?.createdAt != null
        ? _formatJoinDate(user!.createdAt)
        : 'Local profile';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.onPrimaryContainer.withValues(alpha: 0.10),
            child: Text(
              _initials(name),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: scheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                Text(
                  joined,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _displayName(User? user) {
    final metadata = user?.userMetadata;
    final raw =
        metadata?['full_name'] ??
        metadata?['name'] ??
        metadata?['user_name'] ??
        user?.email?.split('@').first ??
        'Guest User';
    return raw.toString();
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'G';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String _formatJoinDate(String createdAt) {
    final parsed = DateTime.tryParse(createdAt)?.toLocal();
    if (parsed == null) return 'Profile active';
    return 'Joined ${parsed.day}/${parsed.month}/${parsed.year}';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 18),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DangerTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(Icons.logout, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'This will clear all local data on this device and sign you out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      );
    },
  );

  if (shouldLogout != true) return;

  final auth = container.read(authRepositoryProvider);

  await IsarService.resetLocalData();
  await auth.signOut();

  container.invalidate(transactionsProvider);
  container.invalidate(categoriesProvider);
  container.invalidate(paymentMethodPresetsProvider);
  container.invalidate(payeePresetsProvider);
}
