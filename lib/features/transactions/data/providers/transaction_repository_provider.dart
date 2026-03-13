import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/transaction_repository.dart';
import 'transaction_remote_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final remote = ref.read(transactionRemoteSourceProvider);
  return TransactionRepository(remote);
});
