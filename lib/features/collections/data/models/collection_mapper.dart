import '../../../../core/crypto/field_cipher.dart';
import 'collection_model.dart';

extension CollectionMapper on CollectionModel {
  /// Builds the server row. Only `name` is encrypted, as with categories.
  Map<String, dynamic> toJson(String userId, {FieldCipher? cipher}) {
    return <String, dynamic>{
      'user_id': userId,
      'name': cipher == null ? name : cipher.encrypt(name),
      'color': color,
      'icon': icon,
      'separate': separate,
    };
  }

  static CollectionModel fromJson(
    Map<String, dynamic> json, {
    FieldCipher? cipher,
  }) {
    return CollectionModel()
      ..remoteId = json['id'] as String?
      ..name = FieldCipher.readString(cipher, json['name'])!
      ..color = (json['color'] as num).toInt()
      ..icon = json['icon'] as String?
      ..separate = json['separate'] as bool? ?? false;
  }
}
