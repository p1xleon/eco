import '../../../../core/crypto/field_cipher.dart';
import 'category_model.dart';

extension CategoryMapper on CategoryModel {
  /// Builds the server row. See [TransactionMapper.toJson] for why [cipher] is
  /// optional and what stays readable.
  ///
  /// Only `name` is encrypted. `color` and `icon` say nothing about the user's
  /// finances, and `type` is needed as-is.
  Map<String, dynamic> toJson(String userId, {FieldCipher? cipher}) {
    return <String, dynamic>{
      'user_id': userId,
      'name': cipher == null ? name : cipher.encrypt(name),
      'type': type.name,
      'color': color,
      'icon': icon,
    };
  }

  static CategoryModel fromJson(
    Map<String, dynamic> json, {
    FieldCipher? cipher,
  }) {
    final category = CategoryModel();

    category.remoteId = json['id'] as String?;
    category.name = FieldCipher.readString(cipher, json['name'])!;
    category.type = json['type'] == 'income'
        ? CategoryType.income
        : CategoryType.expense;
    category.color = (json['color'] as num).toInt();
    category.icon = json['icon'] as String?;

    return category;
  }
}
