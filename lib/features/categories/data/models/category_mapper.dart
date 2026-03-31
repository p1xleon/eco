import 'category_model.dart';

extension CategoryMapper on CategoryModel {
  Map<String, dynamic> toJson(String userId) {
    return <String, dynamic>{
      'user_id': userId,
      'name': name,
      'type': type.name,
      'color': color,
      'icon': icon,
    };
  }

  static CategoryModel fromJson(Map<String, dynamic> json) {
    final category = CategoryModel();

    category.remoteId = json['id'] as String?;
    category.name = json['name'] as String;
    category.type = json['type'] == 'income'
        ? CategoryType.income
        : CategoryType.expense;
    category.color = (json['color'] as num).toInt();
    category.icon = json['icon'] as String?;

    return category;
  }
}
