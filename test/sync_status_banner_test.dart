import 'package:eco/core/network/connectivity_provider.dart';
import 'package:eco/core/sync/sync_providers.dart';
import 'package:eco/shared/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpBanner(
  WidgetTester tester, {
  required bool isOnline,
  required int pending,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isOnlineProvider.overrideWithValue(isOnline),
        pendingSyncCountProvider.overrideWith((ref) async => pending),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SyncStatusBanner()),
      ),
    ),
  );

  // Let the pending count future resolve.
  await tester.pump();
}

void main() {
  testWidgets('stays out of the way when online and fully synced', (
    tester,
  ) async {
    await pumpBanner(tester, isOnline: true, pending: 0);

    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.textContaining('sync'), findsNothing);
  });

  testWidgets('says the app is offline and how much is queued', (tester) async {
    await pumpBanner(tester, isOnline: false, pending: 3);

    expect(find.text('Offline — 3 changes waiting to sync'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('reassures the user when offline with nothing queued', (
    tester,
  ) async {
    await pumpBanner(tester, isOnline: false, pending: 0);

    expect(
      find.text('Offline — changes are saved on this device'),
      findsOneWidget,
    );
  });

  testWidgets('reports a queue that is still draining while online', (
    tester,
  ) async {
    await pumpBanner(tester, isOnline: true, pending: 1);

    expect(find.text('1 change waiting to sync'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
  });
}
