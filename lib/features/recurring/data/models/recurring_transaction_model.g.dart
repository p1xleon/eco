// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_transaction_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRecurringTransactionModelCollection on Isar {
  IsarCollection<RecurringTransactionModel> get recurringTransactionModels =>
      this.collection();
}

const RecurringTransactionModelSchema = CollectionSchema(
  name: r'RecurringTransactionModel',
  id: 6130514885703977993,
  properties: {
    r'accountId': PropertySchema(
      id: 0,
      name: r'accountId',
      type: IsarType.string,
    ),
    r'amountType': PropertySchema(
      id: 1,
      name: r'amountType',
      type: IsarType.byte,
      enumMap: _RecurringTransactionModelamountTypeEnumValueMap,
    ),
    r'categoryId': PropertySchema(
      id: 2,
      name: r'categoryId',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'defaultAmount': PropertySchema(
      id: 4,
      name: r'defaultAmount',
      type: IsarType.double,
    ),
    r'intervalCount': PropertySchema(
      id: 5,
      name: r'intervalCount',
      type: IsarType.long,
    ),
    r'intervalType': PropertySchema(
      id: 6,
      name: r'intervalType',
      type: IsarType.byte,
      enumMap: _RecurringTransactionModelintervalTypeEnumValueMap,
    ),
    r'isActive': PropertySchema(id: 7, name: r'isActive', type: IsarType.bool),
    r'nextDueDate': PropertySchema(
      id: 8,
      name: r'nextDueDate',
      type: IsarType.dateTime,
    ),
    r'note': PropertySchema(id: 9, name: r'note', type: IsarType.string),
    r'title': PropertySchema(id: 10, name: r'title', type: IsarType.string),
    r'type': PropertySchema(
      id: 11,
      name: r'type',
      type: IsarType.byte,
      enumMap: _RecurringTransactionModeltypeEnumValueMap,
    ),
    r'updatedAt': PropertySchema(
      id: 12,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _recurringTransactionModelEstimateSize,
  serialize: _recurringTransactionModelSerialize,
  deserialize: _recurringTransactionModelDeserialize,
  deserializeProp: _recurringTransactionModelDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _recurringTransactionModelGetId,
  getLinks: _recurringTransactionModelGetLinks,
  attach: _recurringTransactionModelAttach,
  version: '3.3.0',
);

int _recurringTransactionModelEstimateSize(
  RecurringTransactionModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.accountId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _recurringTransactionModelSerialize(
  RecurringTransactionModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accountId);
  writer.writeByte(offsets[1], object.amountType.index);
  writer.writeLong(offsets[2], object.categoryId);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeDouble(offsets[4], object.defaultAmount);
  writer.writeLong(offsets[5], object.intervalCount);
  writer.writeByte(offsets[6], object.intervalType.index);
  writer.writeBool(offsets[7], object.isActive);
  writer.writeDateTime(offsets[8], object.nextDueDate);
  writer.writeString(offsets[9], object.note);
  writer.writeString(offsets[10], object.title);
  writer.writeByte(offsets[11], object.type.index);
  writer.writeDateTime(offsets[12], object.updatedAt);
}

RecurringTransactionModel _recurringTransactionModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = RecurringTransactionModel();
  object.accountId = reader.readStringOrNull(offsets[0]);
  object.amountType =
      _RecurringTransactionModelamountTypeValueEnumMap[reader.readByteOrNull(
        offsets[1],
      )] ??
      RecurringAmountType.fixed;
  object.categoryId = reader.readLong(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.defaultAmount = reader.readDoubleOrNull(offsets[4]);
  object.id = id;
  object.intervalCount = reader.readLong(offsets[5]);
  object.intervalType =
      _RecurringTransactionModelintervalTypeValueEnumMap[reader.readByteOrNull(
        offsets[6],
      )] ??
      RecurringIntervalType.daily;
  object.isActive = reader.readBool(offsets[7]);
  object.nextDueDate = reader.readDateTime(offsets[8]);
  object.note = reader.readStringOrNull(offsets[9]);
  object.title = reader.readString(offsets[10]);
  object.type =
      _RecurringTransactionModeltypeValueEnumMap[reader.readByteOrNull(
        offsets[11],
      )] ??
      TransactionType.income;
  object.updatedAt = reader.readDateTimeOrNull(offsets[12]);
  return object;
}

P _recurringTransactionModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (_RecurringTransactionModelamountTypeValueEnumMap[reader
                  .readByteOrNull(offset)] ??
              RecurringAmountType.fixed)
          as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (_RecurringTransactionModelintervalTypeValueEnumMap[reader
                  .readByteOrNull(offset)] ??
              RecurringIntervalType.daily)
          as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (_RecurringTransactionModeltypeValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              TransactionType.income)
          as P;
    case 12:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _RecurringTransactionModelamountTypeEnumValueMap = {
  'fixed': 0,
  'variable': 1,
};
const _RecurringTransactionModelamountTypeValueEnumMap = {
  0: RecurringAmountType.fixed,
  1: RecurringAmountType.variable,
};
const _RecurringTransactionModelintervalTypeEnumValueMap = {
  'daily': 0,
  'weekly': 1,
  'monthly': 2,
  'yearly': 3,
};
const _RecurringTransactionModelintervalTypeValueEnumMap = {
  0: RecurringIntervalType.daily,
  1: RecurringIntervalType.weekly,
  2: RecurringIntervalType.monthly,
  3: RecurringIntervalType.yearly,
};
const _RecurringTransactionModeltypeEnumValueMap = {'income': 0, 'expense': 1};
const _RecurringTransactionModeltypeValueEnumMap = {
  0: TransactionType.income,
  1: TransactionType.expense,
};

Id _recurringTransactionModelGetId(RecurringTransactionModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _recurringTransactionModelGetLinks(
  RecurringTransactionModel object,
) {
  return [];
}

void _recurringTransactionModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  RecurringTransactionModel object,
) {
  object.id = id;
}

extension RecurringTransactionModelQueryWhereSort
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QWhere
        > {
  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterWhere
  >
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension RecurringTransactionModelQueryWhere
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QWhereClause
        > {
  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterWhereClause
  >
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterWhereClause
  >
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterWhereClause
  >
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterWhereClause
  >
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension RecurringTransactionModelQueryFilter
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QFilterCondition
        > {
  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'accountId'),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'accountId'),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'accountId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'accountId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'accountId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'accountId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'accountId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'accountId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'accountId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'accountId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'accountId', value: ''),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  accountIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'accountId', value: ''),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  amountTypeEqualTo(RecurringAmountType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'amountType', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  amountTypeGreaterThan(RecurringAmountType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'amountType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  amountTypeLessThan(RecurringAmountType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'amountType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  amountTypeBetween(
    RecurringAmountType lower,
    RecurringAmountType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'amountType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  categoryIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'categoryId', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  categoryIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'categoryId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  categoryIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'categoryId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  categoryIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'categoryId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  defaultAmountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'defaultAmount'),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  defaultAmountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'defaultAmount'),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  defaultAmountEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'defaultAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  defaultAmountGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'defaultAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  defaultAmountLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'defaultAmount',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  defaultAmountBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'defaultAmount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  intervalCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'intervalCount', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  intervalCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'intervalCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  intervalCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'intervalCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  intervalCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'intervalCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  intervalTypeEqualTo(RecurringIntervalType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'intervalType', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  intervalTypeGreaterThan(RecurringIntervalType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'intervalType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  intervalTypeLessThan(RecurringIntervalType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'intervalType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  intervalTypeBetween(
    RecurringIntervalType lower,
    RecurringIntervalType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'intervalType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  isActiveEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isActive', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  nextDueDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'nextDueDate', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  nextDueDateGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nextDueDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  nextDueDateLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nextDueDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  nextDueDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nextDueDate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'note'),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'note'),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'note',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'note',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'note', value: ''),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'note', value: ''),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  typeEqualTo(TransactionType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  typeGreaterThan(TransactionType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  typeLessThan(TransactionType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  typeBetween(
    TransactionType lower,
    TransactionType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'updatedAt'),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  updatedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  updatedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterFilterCondition
  >
  updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension RecurringTransactionModelQueryObject
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QFilterCondition
        > {}

extension RecurringTransactionModelQueryLinks
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QFilterCondition
        > {}

extension RecurringTransactionModelQuerySortBy
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QSortBy
        > {
  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByAmountType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountType', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByAmountTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountType', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByCategoryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByDefaultAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultAmount', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByDefaultAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultAmount', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByIntervalCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalCount', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByIntervalCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalCount', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByIntervalType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalType', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByIntervalTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalType', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByNextDueDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextDueDate', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByNextDueDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextDueDate', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension RecurringTransactionModelQuerySortThenBy
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QSortThenBy
        > {
  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByAccountId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByAccountIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accountId', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByAmountType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountType', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByAmountTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountType', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByCategoryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByDefaultAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultAmount', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByDefaultAmountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultAmount', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByIntervalCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalCount', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByIntervalCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalCount', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByIntervalType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalType', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByIntervalTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intervalType', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByIsActiveDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isActive', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByNextDueDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextDueDate', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByNextDueDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nextDueDate', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringTransactionModel,
    QAfterSortBy
  >
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension RecurringTransactionModelQueryWhereDistinct
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QDistinct
        > {
  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByAccountId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accountId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByAmountType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amountType');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoryId');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByDefaultAmount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultAmount');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByIntervalCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intervalCount');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByIntervalType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intervalType');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByIsActive() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isActive');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByNextDueDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nextDueDate');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringTransactionModel, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension RecurringTransactionModelQueryProperty
    on
        QueryBuilder<
          RecurringTransactionModel,
          RecurringTransactionModel,
          QQueryProperty
        > {
  QueryBuilder<RecurringTransactionModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<RecurringTransactionModel, String?, QQueryOperations>
  accountIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accountId');
    });
  }

  QueryBuilder<RecurringTransactionModel, RecurringAmountType, QQueryOperations>
  amountTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amountType');
    });
  }

  QueryBuilder<RecurringTransactionModel, int, QQueryOperations>
  categoryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoryId');
    });
  }

  QueryBuilder<RecurringTransactionModel, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<RecurringTransactionModel, double?, QQueryOperations>
  defaultAmountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultAmount');
    });
  }

  QueryBuilder<RecurringTransactionModel, int, QQueryOperations>
  intervalCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intervalCount');
    });
  }

  QueryBuilder<
    RecurringTransactionModel,
    RecurringIntervalType,
    QQueryOperations
  >
  intervalTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intervalType');
    });
  }

  QueryBuilder<RecurringTransactionModel, bool, QQueryOperations>
  isActiveProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isActive');
    });
  }

  QueryBuilder<RecurringTransactionModel, DateTime, QQueryOperations>
  nextDueDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nextDueDate');
    });
  }

  QueryBuilder<RecurringTransactionModel, String?, QQueryOperations>
  noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<RecurringTransactionModel, String, QQueryOperations>
  titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<RecurringTransactionModel, TransactionType, QQueryOperations>
  typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<RecurringTransactionModel, DateTime?, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
