import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/crypto/crypto_providers.dart';
import 'core/crypto/data_key_store.dart';
import 'core/privacy/transaction_visibility.dart';
import 'core/privacy/transaction_visibility_storage.dart';
import 'core/database/isar_service.dart';
import 'core/database/category_seeder.dart';
import 'core/network/network_monitor.dart';
import 'core/sync/sync_backfill.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/theme_storage.dart';
import 'core/database/transaction_preset_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await IsarService.init();
  await CategorySeeder.seed();
  await TransactionPresetSeeder.ensureDefaults();
  // Queues anything the server has never seen, including rows written before
  // sync state was tracked and the categories just seeded above.
  await SyncBackfill.run();
  await NetworkMonitor.instance.init();

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception('Missing SUPABASE_URL in .env');
  }

  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('Missing SUPABASE_ANON_KEY in .env');
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  final initialTheme = await ThemeStorage.load();
  final initialVisibility = await TransactionVisibilityStorage.load();

  // Read before the first frame so the app knows straight away whether
  // encryption has been set up on this device, rather than flashing the setup
  // gate at someone who already has a key.
  final dataKeyStore = DataKeyStore();
  final initialDataKey = await dataKeyStore.load();

  runApp(
    ProviderScope(
      overrides: [
        dataKeyStoreProvider.overrideWithValue(dataKeyStore),
        dataKeyProvider.overrideWith(
          (ref) => DataKeyNotifier(initialDataKey, dataKeyStore),
        ),
        themeProvider.overrideWith((ref) => ThemeNotifier(initialTheme)),
        transactionVisibilityProvider.overrideWith(
          (ref) => TransactionVisibilityNotifier(
            initialVisibility,
            TransactionVisibilityStorage.save,
          ),
        ),
      ],
      child: const Eco(),
    ),
  );
}

//flutter build apk --profile
