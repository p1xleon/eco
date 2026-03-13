import '../../data/models/transaction_model.dart';

class MonthGroup {
  final String month;
  final double income;
  final double expense;
  final List<TransactionModel> transactions;

  const MonthGroup({
    required this.month,
    required this.income,
    required this.expense,
    required this.transactions,
  });
}
