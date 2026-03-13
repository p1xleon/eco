import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../remote/transaction_remote_source.dart';

final transactionRemoteSourceProvider = Provider<TransactionRemoteSource>((
  ref,
) {
  final client = ref.read(supabaseClientProvider);

  return TransactionRemoteSource(client);
});
