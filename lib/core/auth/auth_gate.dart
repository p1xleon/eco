import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/presentation/providers/transaction_provider.dart';
import '../../features/auth/pages/login_page.dart';
import '../../shared/widgets/app_shell.dart';
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

class _AuthenticatedAppShellState extends ConsumerState<_AuthenticatedAppShell> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hadConnection = true;

  @override
  void initState() {
    super.initState();
    _initializeConnectivityListener();
  }

  Future<void> _initializeConnectivityListener() async {
    final connectivity = Connectivity();
    final current = await connectivity.checkConnectivity();
    _hadConnection = _hasNetworkConnection(current);

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) async {
      final hasConnection = _hasNetworkConnection(results);
      if (!_hadConnection && hasConnection) {
        await refreshTransactions(ref);
      }

      _hadConnection = hasConnection;
    });
  }

  bool _hasNetworkConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const AppShell();
  }
}
