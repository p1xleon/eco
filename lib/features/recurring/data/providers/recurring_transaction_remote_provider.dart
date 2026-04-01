import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../remote/recurring_transaction_remote_source.dart';

final recurringTransactionRemoteSourceProvider =
    Provider<RecurringTransactionRemoteSource>((ref) {
      final client = ref.read(supabaseClientProvider);
      return RecurringTransactionRemoteSource(client);
    });
