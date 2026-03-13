import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/database/isar_service.dart';
import 'core/database/category_seeder.dart';
import 'core/database/transaction_preset_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await IsarService.init();
  await CategorySeeder.seed();
  await TransactionPresetSeeder.ensureDefaults();

  await Supabase.initialize(
    url: 'https://ygqdppxgsjnkhwknjijz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlncWRwcHhnc2pua2h3a25qaWp6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzMDgxNzMsImV4cCI6MjA4ODg4NDE3M30.EKvjh7cqseC2KHgGII4-irrlXtCzOKTabieC_U1oJ84',
  );

  runApp(const ProviderScope(child: Eco()));
}
