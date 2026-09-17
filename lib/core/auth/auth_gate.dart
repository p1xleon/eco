import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/pages/login_page.dart';
import '../../features/recurring/presentation/providers/recurring_transaction_provider.dart';
import '../../features/transactions/presentation/providers/transaction_provider.dart';
import '../../shared/widgets/app_shell.dart';
import '../backup/backup_providers.dart';
import '../network/network_monitor.dart';
import '../sync/sync_providers.dart';
import 'auth_provider.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginPage();
        }

        return const _AuthenticatedAppShell();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          const Scaffold(body: Center(child: Text('Something went wrong'))),
    );
  }
}

class _AuthenticatedAppShell extends ConsumerStatefulWidget {
  const _AuthenticatedAppShell();

  @override
  ConsumerState<_AuthenticatedAppShell> createState() =>
      _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState
    extends ConsumerState<_AuthenticatedAppShell> {
  StreamSubscription<bool>? _connectivitySubscription;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();

    // Coming back online is the moment to replay whatever was queued offline.
    // The refresh runs a push before it pulls.
    _connectivitySubscription = NetworkMonitor.instance.onStatusChanged.listen((
      isOnline,
    ) {
      if (!isOnline || !mounted) return;

      unawaited(_guarded(() => syncNow(ref)));
    });

    // Opening the app is the first of the two moments a backup can run: there
    // is no background scheduler, so backups ride the lifecycle. The schedule
    // throttles to once a day and swallows its own failures.
    unawaited(_backUpIfDue());

    // Returning to the app is the other natural moment to catch up. This goes
    // through the plain refresh rather than [syncNow] so the per-collection
    // recency window still applies and a resume right after a reconnect does
    // not sync everything twice.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;

        unawaited(
          _guarded(() async {
            await refreshTransactions(ref);
            await refreshRecurringTransactions(ref);
          }),
        );

        unawaited(_backUpIfDue());
      },
    );
  }

  /// Runs the daily automatic backup, if one is due and encryption is set up.
  ///
  /// Null before the user has a key: backups are encrypted with it, so there is
  /// nothing to write yet. The setup gate is what resolves that, not a silent
  /// plaintext fallback.
  Future<void> _backUpIfDue() async {
    final schedule = ref.read(backupScheduleProvider);
    if (schedule == null || !mounted) return;

    await schedule.runIfDue();
  }

  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Nothing to surface here: whatever failed to push stays queued, and the
      // shell may have been torn down mid-sync by a sign-out.
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const AppShell();
  }
}
