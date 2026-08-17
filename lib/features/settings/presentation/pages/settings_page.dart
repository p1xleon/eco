import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/database/isar_service.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/theme/theme_mode_setting.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../categories/presentation/pages/categories_page.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../recurring/domain/services/recurring_recovery_service.dart';
import '../../../recurring/presentation/pages/recurring_transactions_page.dart';
import '../../../recurring/presentation/providers/recurring_transaction_provider.dart';
import '../../../transactions/import/pages/import_transactions_page.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../providers/transaction_preset_provider.dart';
import 'transaction_presets_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final visibility = ref.watch(transactionVisibilityProvider);
    final visibilityNotifier = ref.read(transactionVisibilityProvider.notifier);
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
          const _SyncSection(),
          const SizedBox(height: 16),
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
                icon: Icons.upload_file_outlined,
                title: 'Import Transactions',
                subtitle:
                    'Upload a CSV, map columns, review rows, and save only after final confirmation',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportTransactionsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _SettingsActionTile(
                icon: Icons.event_repeat_outlined,
                title: 'Recurring Transactions',
                subtitle:
                    '$recurringCount template${recurringCount == 1 ? '' : 's'}',
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
                        const Icon(Icons.visibility_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Transaction Visibility',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Control how transaction data appears across the app',
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
                    SegmentedButton<TransactionVisibilityMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: TransactionVisibilityMode.normal,
                          label: Text('Normal'),
                        ),
                        ButtonSegment(
                          value: TransactionVisibilityMode.masked,
                          label: Text('Masked'),
                        ),
                        ButtonSegment(
                          value: TransactionVisibilityMode.invisible,
                          label: Text('Invisible'),
                        ),
                      ],
                      selected: {visibility.mode},
                      onSelectionChanged: (selection) {
                        final nextMode = selection.first;
                        visibilityNotifier.setMode(
                          nextMode,
                          existingTransactions:
                              transactionsAsync.valueOrNull ?? const [],
                          existingRecurringTemplates:
                              recurringAsync.valueOrNull ?? const [],
                        );
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                'Transaction visibility: ${_visibilityShortLabel(nextMode)}',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _visibilityDescription(visibility.mode),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Shortcut: long-press the Settings tab icon to cycle Normal, Masked, and Invisible modes from anywhere in the app.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
          const _RecurringRecoverySection(),
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

  String _visibilityDescription(TransactionVisibilityMode mode) {
    return switch (mode) {
      TransactionVisibilityMode.normal =>
        'Show transaction names, amounts, dashboard stats, and analytics normally.',
      TransactionVisibilityMode.masked =>
        'Keep transactions visible while replacing sensitive values with masked placeholders.',
      TransactionVisibilityMode.invisible =>
        'Hide existing transactions and analytics until new transactions are added in this mode.',
    };
  }

  String _visibilityShortLabel(TransactionVisibilityMode mode) {
    return switch (mode) {
      TransactionVisibilityMode.normal => 'Normal',
      TransactionVisibilityMode.masked => 'Masked',
      TransactionVisibilityMode.invisible => 'Invisible',
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
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.82),
            scheme.secondaryContainer.withValues(alpha: 0.62),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.28),
        ),
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

/// Connection state, how much is still queued, and a way to retry now.
class _SyncSection extends ConsumerStatefulWidget {
  const _SyncSection();

  @override
  ConsumerState<_SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<_SyncSection> {
  bool _isSyncing = false;

  Future<void> _retryFailed() => _runSync(retryFailedSync);

  Future<void> _syncNow() => _runSync(syncNow);

  Future<void> _runSync(Future<void> Function(WidgetRef ref) action) async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    try {
      await action(ref);
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }

    if (!mounted) return;

    final remaining = await ref.read(pendingSyncCountProvider.future);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            remaining == 0
                ? 'Everything is synced'
                : '$remaining change${remaining == 1 ? '' : 's'} still waiting to sync',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOnline = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final failures =
        ref.watch(syncFailuresProvider).valueOrNull ?? const <SyncFailure>[];

    final statusColor = isOnline ? scheme.primary : scheme.onSurfaceVariant;
    final statusLabel = isOnline ? 'Connected' : 'Offline';
    final detail = !isOnline
        ? 'Everything you do is saved on this device and uploaded once you are back online.'
        : pending == 0
        ? 'All local changes have reached the server.'
        : '$pending change${pending == 1 ? '' : 's'} waiting to upload.';

    return _SectionCard(
      title: 'Sync',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isOnline
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: _isSyncing ? null : _syncNow,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_isSyncing ? 'Syncing…' : 'Sync now'),
                ),
              ),
            ],
          ),
        ),
        if (failures.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SyncFailureList(failures: failures, onRetry: _retryFailed),
        ],
      ],
    );
  }
}

/// Records the server rejected often enough that automatic retries stopped.
class _SyncFailureList extends StatelessWidget {
  final List<SyncFailure> failures;
  final VoidCallback onRetry;

  const _SyncFailureList({required this.failures, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_problem_outlined, color: scheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${failures.length} item${failures.length == 1 ? '' : 's'} could not be synced',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These stay on this device and are no longer retried automatically.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final failure in failures.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${failure.collection}: ${failure.label}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (failure.error != null)
                    Text(
                      failure.error!,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          if (failures.length > 5)
            Text(
              'and ${failures.length - 5} more',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
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

class _RecurringRecoverySection extends ConsumerStatefulWidget {
  const _RecurringRecoverySection();

  @override
  ConsumerState<_RecurringRecoverySection> createState() =>
      _RecurringRecoverySectionState();
}

class _RecurringRecoverySectionState
    extends ConsumerState<_RecurringRecoverySection> {
  bool _isInspecting = false;
  bool _isRecovering = false;
  RecurringRecoveryInspection? _lastInspection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _SectionCard(
      title: 'Maintenance',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.build_circle_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recurring Recovery',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Inspect this device for recurring templates that were lost while linked transactions still exist.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Recovery recreates only missing templates and marks them paused. Interval settings are reset to monthly placeholders and may need manual correction.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (_lastInspection != null) ...[
                const SizedBox(height: 12),
                Text(
                  _inspectionSummary(_lastInspection!),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isInspecting || _isRecovering ? null : _inspect,
                    icon: _isInspecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_outlined),
                    label: const Text('Inspect Device Data'),
                  ),
                  FilledButton.icon(
                    onPressed: _isInspecting || _isRecovering ? null : _recover,
                    icon: _isRecovering
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.restore_outlined),
                    label: const Text('Recover Missing Templates'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _inspect() async {
    setState(() {
      _isInspecting = true;
    });

    try {
      final inspection = await ref
          .read(recurringRecoveryServiceProvider)
          .inspect();
      if (!mounted) return;

      setState(() {
        _lastInspection = inspection;
      });

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recurring Recovery Check'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Text(_inspectionDetails(inspection)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showSnackBar('Failed to inspect recurring data: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isInspecting = false;
        });
      }
    }
  }

  Future<void> _recover() async {
    final inspection =
        _lastInspection ??
        await ref.read(recurringRecoveryServiceProvider).inspect();

    if (!mounted) return;

    setState(() {
      _lastInspection = inspection;
    });

    if (!inspection.hasMissingCandidates) {
      _showSnackBar(
        'No missing recurring templates were found on this device.',
      );
      return;
    }

    final shouldRecover = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recover Missing Templates'),
        content: Text(
          'Recover ${inspection.missingCandidates.length} missing recurring template${inspection.missingCandidates.length == 1 ? '' : 's'} as paused placeholders on this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recover'),
          ),
        ],
      ),
    );

    if (shouldRecover != true) {
      return;
    }

    setState(() {
      _isRecovering = true;
    });

    try {
      final result = await ref
          .read(recurringRecoveryServiceProvider)
          .recoverMissingTemplates();

      ref.invalidate(recurringTransactionsProvider);
      ref.invalidate(dueRecurringTransactionsProvider);
      ref.invalidate(dashboardRecurringProvider);

      if (!mounted) return;

      _showSnackBar(
        result.recoveredCount == 0
            ? 'No missing recurring templates were recovered.'
            : 'Recovered ${result.recoveredCount} recurring template${result.recoveredCount == 1 ? '' : 's'} as paused placeholders.',
      );

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recovery Complete'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(child: Text(_recoveryDetails(result))),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showSnackBar('Failed to recover recurring templates: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isRecovering = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _inspectionSummary(RecurringRecoveryInspection inspection) {
    return 'Found ${inspection.existingTemplateCount} existing template${inspection.existingTemplateCount == 1 ? '' : 's'}, ${inspection.linkedTransactionCount} linked transaction${inspection.linkedTransactionCount == 1 ? '' : 's'}, and ${inspection.missingCandidates.length} missing template candidate${inspection.missingCandidates.length == 1 ? '' : 's'}.';
  }

  String _inspectionDetails(RecurringRecoveryInspection inspection) {
    final buffer = StringBuffer()
      ..writeln(_inspectionSummary(inspection))
      ..writeln()
      ..writeln(
        'Missing template candidates are inferred from transactions that still reference recurring template ids not present in the local recurring table.',
      );

    if (!inspection.hasMissingCandidates) {
      buffer
        ..writeln()
        ..write('No recoverable missing recurring templates were found.');
      return buffer.toString();
    }

    for (final candidate in inspection.missingCandidates) {
      buffer
        ..writeln()
        ..writeln('Template #${candidate.templateId}: ${candidate.title}')
        ..writeln('Linked transactions: ${candidate.linkedTransactionCount}')
        ..writeln('Recovered amount mode: ${candidate.amountType.name}')
        ..writeln(
          'Recovered default amount: ${candidate.defaultAmount?.toStringAsFixed(2) ?? '—'}',
        )
        ..writeln('Recovered next due placeholder: ${candidate.nextDueDate}');
    }

    return buffer.toString();
  }

  String _recoveryDetails(RecurringRecoveryResult result) {
    if (result.recoveredCount == 0) {
      return 'No missing recurring templates were recovered.';
    }

    final buffer = StringBuffer()
      ..writeln(
        'Recovered ${result.recoveredCount} template${result.recoveredCount == 1 ? '' : 's'}.',
      )
      ..writeln()
      ..writeln(
        'All recovered templates were created as paused placeholders to avoid accidental due items. Review interval settings before re-enabling them.',
      );

    for (final candidate in result.recoveredCandidates) {
      buffer
        ..writeln()
        ..write('Template #${candidate.templateId}: ${candidate.title}');
    }

    return buffer.toString();
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

enum _LogoutChoice { cancel, syncFirst, discard }

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final container = ProviderScope.containerOf(context, listen: false);

  // Logging out wipes local data, so anything that never reached the server is
  // about to be destroyed.
  final pending = await container.read(pendingSyncCountProvider.future);
  if (!context.mounted) return;

  final isOnline = container.read(isOnlineProvider);
  if (!context.mounted) return;

  final _LogoutChoice? choice;
  if (pending == 0) {
    choice = await _askToLogout(context);
  } else {
    choice = await _askToLogoutWithPendingChanges(
      context,
      pending: pending,
      isOnline: isOnline,
    );
  }

  if (choice == null || choice == _LogoutChoice.cancel) return;

  if (choice == _LogoutChoice.syncFirst) {
    var remaining = pending;
    try {
      await syncNow(ref);
      remaining = await container.read(pendingSyncCountProvider.future);
    } catch (_) {
      // Treated as "still pending" below.
    }

    if (remaining > 0) {
      // Stay logged in rather than destroy work that never got out.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '$remaining change${remaining == 1 ? '' : 's'} could not be synced. '
              'You are still signed in.',
            ),
          ),
        );
      return;
    }
  }

  final auth = container.read(authRepositoryProvider);

  await IsarService.resetLocalData();
  await auth.signOut();

  container.invalidate(transactionsProvider);
  container.invalidate(categoriesProvider);
  container.invalidate(paymentMethodPresetsProvider);
  container.invalidate(payeePresetsProvider);
}

Future<_LogoutChoice?> _askToLogout(BuildContext context) {
  return showDialog<_LogoutChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: const Text(
        'This will clear all local data on this device and sign you out.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _LogoutChoice.cancel),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _LogoutChoice.discard),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}

/// Losing unsynced work has to be a deliberate choice, not a side effect of
/// signing out.
Future<_LogoutChoice?> _askToLogoutWithPendingChanges(
  BuildContext context, {
  required int pending,
  required bool isOnline,
}) {
  final label = pending == 1 ? '1 change' : '$pending changes';

  return showDialog<_LogoutChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: Text(
        isOnline
            ? '$label on this device have not reached the server yet. Logging out '
                  'clears all local data, so they would be lost.'
            : '$label on this device have not reached the server yet, and you are '
                  'offline. Logging out clears all local data, so they would be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _LogoutChoice.cancel),
          child: const Text('Cancel'),
        ),
        if (isOnline)
          TextButton(
            onPressed: () => Navigator.pop(context, _LogoutChoice.syncFirst),
            child: const Text('Sync, then log out'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          onPressed: () => Navigator.pop(context, _LogoutChoice.discard),
          child: Text('Discard $label'),
        ),
      ],
    ),
  );
}
