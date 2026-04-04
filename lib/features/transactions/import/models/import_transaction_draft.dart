import '../../data/models/transaction_model.dart';

class ImportTransactionDraft {
  final String id;
  final Map<String, String> raw;
  final String? title;
  final double? amount;
  final DateTime? date;
  final TransactionType type;
  final int? categoryId;
  final String? payee;
  final String? note;
  final String? paymentMethod;
  final int? recurringTemplateId;
  final List<String> errors;
  final bool isValid;
  final bool isSelected;

  const ImportTransactionDraft({
    required this.id,
    required this.raw,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.categoryId,
    required this.payee,
    required this.note,
    required this.paymentMethod,
    required this.recurringTemplateId,
    required this.errors,
    required this.isValid,
    required this.isSelected,
  });

  ImportTransactionDraft copyWith({
    String? id,
    Map<String, String>? raw,
    String? title,
    bool clearTitle = false,
    double? amount,
    bool clearAmount = false,
    DateTime? date,
    bool clearDate = false,
    TransactionType? type,
    int? categoryId,
    bool clearCategoryId = false,
    String? payee,
    bool clearPayee = false,
    String? note,
    bool clearNote = false,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    int? recurringTemplateId,
    bool clearRecurringTemplateId = false,
    List<String>? errors,
    bool? isValid,
    bool? isSelected,
  }) {
    return ImportTransactionDraft(
      id: id ?? this.id,
      raw: raw ?? this.raw,
      title: clearTitle ? null : (title ?? this.title),
      amount: clearAmount ? null : (amount ?? this.amount),
      date: clearDate ? null : (date ?? this.date),
      type: type ?? this.type,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      payee: clearPayee ? null : (payee ?? this.payee),
      note: clearNote ? null : (note ?? this.note),
      paymentMethod: clearPaymentMethod
          ? null
          : (paymentMethod ?? this.paymentMethod),
      recurringTemplateId: clearRecurringTemplateId
          ? null
          : (recurringTemplateId ?? this.recurringTemplateId),
      errors: errors ?? this.errors,
      isValid: isValid ?? this.isValid,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
