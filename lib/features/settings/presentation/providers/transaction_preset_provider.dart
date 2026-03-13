import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/transaction_preset_model.dart';
import '../../data/repositories/transaction_preset_repository.dart';

final transactionPresetRepositoryProvider = Provider(
  (ref) => TransactionPresetRepository(),
);

final paymentMethodPresetsProvider =
    FutureProvider<List<TransactionPresetModel>>((ref) async {
      final repo = ref.read(transactionPresetRepositoryProvider);
      return repo.getByType(TransactionPresetType.paymentMethod);
    });

final payeePresetsProvider =
    FutureProvider<List<TransactionPresetModel>>((ref) async {
      final repo = ref.read(transactionPresetRepositoryProvider);
      return repo.getByType(TransactionPresetType.payee);
    });
