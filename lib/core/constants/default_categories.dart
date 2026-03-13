import '../../features/categories/data/models/category_model.dart';

class DefaultCategories {
  static List<CategoryModel> getAll() {
    return [
      // Expense
      CategoryModel()
        ..name = 'Food'
        ..type = CategoryType.expense
        ..color = 0xFFE57373,

      CategoryModel()
        ..name = 'Transport'
        ..type = CategoryType.expense
        ..color = 0xFF64B5F6,

      CategoryModel()
        ..name = 'Shopping'
        ..type = CategoryType.expense
        ..color = 0xFFBA68C8,

      CategoryModel()
        ..name = 'Bills'
        ..type = CategoryType.expense
        ..color = 0xFFFFB74D,

      CategoryModel()
        ..name = 'Entertainment'
        ..type = CategoryType.expense
        ..color = 0xFF4DB6AC,

      // Income
      CategoryModel()
        ..name = 'Salary'
        ..type = CategoryType.income
        ..color = 0xFF81C784,

      CategoryModel()
        ..name = 'Freelance'
        ..type = CategoryType.income
        ..color = 0xFF4CAF50,

      CategoryModel()
        ..name = 'Investment'
        ..type = CategoryType.income
        ..color = 0xFF388E3C,
    ];
  }
}
