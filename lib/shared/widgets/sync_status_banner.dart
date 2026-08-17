import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_provider.dart';
import '../../core/sync/sync_providers.dart';

/// Thin strip that tells the user when the app is running on local data and
/// how much of it the server has not seen yet.
///
/// Collapses to nothing when online with everything pushed, which is the
/// normal case.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    if (isOnline && pending == 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final background = isOnline
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = isOnline
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Material(
      color: background,
      child: InkWell(
        onTap: isOnline ? null : () => syncNow(ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOnline ? Icons.cloud_sync_outlined : Icons.cloud_off_outlined,
                size: 16,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _message(isOnline: isOnline, pending: pending),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _message({required bool isOnline, required int pending}) {
    if (!isOnline) {
      return pending == 0
          ? 'Offline — changes are saved on this device'
          : 'Offline — ${_changes(pending)} waiting to sync';
    }

    return '${_changes(pending)} waiting to sync';
  }

  String _changes(int pending) {
    return pending == 1 ? '1 change' : '$pending changes';
  }
}
