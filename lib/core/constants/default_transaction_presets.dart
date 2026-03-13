import '../../features/settings/data/models/transaction_preset_model.dart';

class DefaultTransactionPresets {
  static List<TransactionPresetModel> getAll() {
    return [
      TransactionPresetModel()
        ..type = TransactionPresetType.paymentMethod
        ..value = 'UPI',
      TransactionPresetModel()
        ..type = TransactionPresetType.paymentMethod
        ..value = 'Card',
      TransactionPresetModel()
        ..type = TransactionPresetType.paymentMethod
        ..value = 'Cash',
      TransactionPresetModel()
        ..type = TransactionPresetType.paymentMethod
        ..value = 'PhonePe',
      TransactionPresetModel()
        ..type = TransactionPresetType.paymentMethod
        ..value = 'Google Pay',
      TransactionPresetModel()
        ..type = TransactionPresetType.payee
        ..value = 'Amazon',
      TransactionPresetModel()
        ..type = TransactionPresetType.payee
        ..value = 'Local Store',
      TransactionPresetModel()
        ..type = TransactionPresetType.payee
        ..value = 'Swiggy',
      TransactionPresetModel()
        ..type = TransactionPresetType.payee
        ..value = 'Rent',
    ];
  }
}
