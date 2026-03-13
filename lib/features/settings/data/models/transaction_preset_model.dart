import 'package:isar_community/isar.dart';

part 'transaction_preset_model.g.dart';

enum TransactionPresetType { paymentMethod, payee }

@collection
class TransactionPresetModel {
  Id id = Isar.autoIncrement;

  @enumerated
  late TransactionPresetType type;

  late String value;
}
