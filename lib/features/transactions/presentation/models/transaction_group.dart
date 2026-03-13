import '../../data/models/transaction_model.dart';

class TransactionGroup {
  final DateTime date;
  final List<TransactionModel> transactions;

  TransactionGroup({required this.date, required this.transactions});
}
