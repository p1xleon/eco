enum FieldType { title, amount, date, category, note, payee, paymentMethod }

extension FieldTypeX on FieldType {
  String get label {
    return switch (this) {
      FieldType.title => 'Title',
      FieldType.amount => 'Amount',
      FieldType.date => 'Date',
      FieldType.category => 'Category',
      FieldType.note => 'Note',
      FieldType.payee => 'Payee',
      FieldType.paymentMethod => 'Payment Method',
    };
  }

  List<String> get aliases {
    return switch (this) {
      FieldType.title => ['title', 'item', 'name', 'transaction', 'label'],
      FieldType.amount => ['amount', 'amt', 'value', 'debit', 'credit'],
      FieldType.date => ['date', 'transaction date', 'posted date'],
      FieldType.category => ['category', 'type', 'tag'],
      FieldType.note => ['note', 'notes', 'memo', 'description', 'details'],
      FieldType.payee => [
        'payee',
        'merchant',
        'store',
        'vendor',
        'shop',
        'seller',
      ],
      FieldType.paymentMethod => ['payment method', 'method', 'account'],
    };
  }
}
