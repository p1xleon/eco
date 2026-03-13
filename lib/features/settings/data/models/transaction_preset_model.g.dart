// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_preset_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTransactionPresetModelCollection on Isar {
  IsarCollection<TransactionPresetModel> get transactionPresetModels =>
      this.collection();
}

const TransactionPresetModelSchema = CollectionSchema(
  name: r'TransactionPresetModel',
  id: -5556744931243854630,
  properties: {
    r'type': PropertySchema(
      id: 0,
      name: r'type',
      type: IsarType.byte,
      enumMap: _TransactionPresetModeltypeEnumValueMap,
    ),
    r'value': PropertySchema(id: 1, name: r'value', type: IsarType.string),
  },

  estimateSize: _transactionPresetModelEstimateSize,
  serialize: _transactionPresetModelSerialize,
  deserialize: _transactionPresetModelDeserialize,
  deserializeProp: _transactionPresetModelDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _transactionPresetModelGetId,
  getLinks: _transactionPresetModelGetLinks,
  attach: _transactionPresetModelAttach,
  version: '3.3.0',
);

int _transactionPresetModelEstimateSize(
  TransactionPresetModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.value.length * 3;
  return bytesCount;
}

void _transactionPresetModelSerialize(
  TransactionPresetModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeByte(offsets[0], object.type.index);
  writer.writeString(offsets[1], object.value);
}

TransactionPresetModel _transactionPresetModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TransactionPresetModel();
  object.id = id;
  object.type =
      _TransactionPresetModeltypeValueEnumMap[reader.readByteOrNull(
        offsets[0],
      )] ??
      TransactionPresetType.paymentMethod;
  object.value = reader.readString(offsets[1]);
  return object;
}

P _transactionPresetModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (_TransactionPresetModeltypeValueEnumMap[reader.readByteOrNull(
                offset,
              )] ??
              TransactionPresetType.paymentMethod)
          as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _TransactionPresetModeltypeEnumValueMap = {
  'paymentMethod': 0,
  'payee': 1,
};
const _TransactionPresetModeltypeValueEnumMap = {
  0: TransactionPresetType.paymentMethod,
  1: TransactionPresetType.payee,
};

Id _transactionPresetModelGetId(TransactionPresetModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _transactionPresetModelGetLinks(
  TransactionPresetModel object,
) {
  return [];
}

void _transactionPresetModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  TransactionPresetModel object,
) {
  object.id = id;
}

extension TransactionPresetModelQueryWhereSort
    on QueryBuilder<TransactionPresetModel, TransactionPresetModel, QWhere> {
  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TransactionPresetModelQueryWhere
    on
        QueryBuilder<
          TransactionPresetModel,
          TransactionPresetModel,
          QWhereClause
        > {
  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterWhereClause
  >
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
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
    TransactionPresetModel,
    TransactionPresetModel,
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
    TransactionPresetModel,
    TransactionPresetModel,
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
    TransactionPresetModel,
    TransactionPresetModel,
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

extension TransactionPresetModelQueryFilter
    on
        QueryBuilder<
          TransactionPresetModel,
          TransactionPresetModel,
          QFilterCondition
        > {
  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
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
    TransactionPresetModel,
    TransactionPresetModel,
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
    TransactionPresetModel,
    TransactionPresetModel,
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
    TransactionPresetModel,
    TransactionPresetModel,
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
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  typeEqualTo(TransactionPresetType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: value),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  typeGreaterThan(TransactionPresetType value, {bool include = false}) {
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
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  typeLessThan(TransactionPresetType value, {bool include = false}) {
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
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  typeBetween(
    TransactionPresetType lower,
    TransactionPresetType upper, {
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
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'value',
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
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'value',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'value',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'value', value: ''),
      );
    });
  }

  QueryBuilder<
    TransactionPresetModel,
    TransactionPresetModel,
    QAfterFilterCondition
  >
  valueIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'value', value: ''),
      );
    });
  }
}

extension TransactionPresetModelQueryObject
    on
        QueryBuilder<
          TransactionPresetModel,
          TransactionPresetModel,
          QFilterCondition
        > {}

extension TransactionPresetModelQueryLinks
    on
        QueryBuilder<
          TransactionPresetModel,
          TransactionPresetModel,
          QFilterCondition
        > {}

extension TransactionPresetModelQuerySortBy
    on QueryBuilder<TransactionPresetModel, TransactionPresetModel, QSortBy> {
  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  sortByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  sortByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension TransactionPresetModelQuerySortThenBy
    on
        QueryBuilder<
          TransactionPresetModel,
          TransactionPresetModel,
          QSortThenBy
        > {
  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  thenByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QAfterSortBy>
  thenByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension TransactionPresetModelQueryWhereDistinct
    on QueryBuilder<TransactionPresetModel, TransactionPresetModel, QDistinct> {
  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QDistinct>
  distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetModel, QDistinct>
  distinctByValue({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'value', caseSensitive: caseSensitive);
    });
  }
}

extension TransactionPresetModelQueryProperty
    on
        QueryBuilder<
          TransactionPresetModel,
          TransactionPresetModel,
          QQueryProperty
        > {
  QueryBuilder<TransactionPresetModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TransactionPresetModel, TransactionPresetType, QQueryOperations>
  typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<TransactionPresetModel, String, QQueryOperations>
  valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'value');
    });
  }
}
