import 'package:isar_community/isar.dart';

part 'category_model.g.dart';

enum CategoryType { income, expense }

@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late String name;

  @enumerated
  late CategoryType type;

  late int color;

  String? icon;
}
