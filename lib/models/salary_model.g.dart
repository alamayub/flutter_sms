// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'salary_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSalaryModelCollection on Isar {
  IsarCollection<SalaryModel> get salaryModels => this.collection();
}

const SalaryModelSchema = CollectionSchema(
  name: r'SalaryModel',
  id: -1778308182849573843,
  properties: {
    r'amountPaid': PropertySchema(
      id: 0,
      name: r'amountPaid',
      type: IsarType.double,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.string,
    ),
    r'createdBy': PropertySchema(
      id: 2,
      name: r'createdBy',
      type: IsarType.long,
    ),
    r'isPaid': PropertySchema(
      id: 3,
      name: r'isPaid',
      type: IsarType.bool,
    ),
    r'paymentDate': PropertySchema(
      id: 4,
      name: r'paymentDate',
      type: IsarType.string,
    ),
    r'salaryMonth': PropertySchema(
      id: 5,
      name: r'salaryMonth',
      type: IsarType.string,
    ),
    r'staffId': PropertySchema(
      id: 6,
      name: r'staffId',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 7,
      name: r'updatedAt',
      type: IsarType.string,
    ),
    r'updatedBy': PropertySchema(
      id: 8,
      name: r'updatedBy',
      type: IsarType.long,
    )
  },
  estimateSize: _salaryModelEstimateSize,
  serialize: _salaryModelSerialize,
  deserialize: _salaryModelDeserialize,
  deserializeProp: _salaryModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'salaryMonth_staffId': IndexSchema(
      id: 5894828206859770396,
      name: r'salaryMonth_staffId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'salaryMonth',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'staffId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _salaryModelGetId,
  getLinks: _salaryModelGetLinks,
  attach: _salaryModelAttach,
  version: '3.1.0+1',
);

int _salaryModelEstimateSize(
  SalaryModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.createdAt.length * 3;
  {
    final value = object.paymentDate;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.salaryMonth.length * 3;
  {
    final value = object.updatedAt;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _salaryModelSerialize(
  SalaryModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.amountPaid);
  writer.writeString(offsets[1], object.createdAt);
  writer.writeLong(offsets[2], object.createdBy);
  writer.writeBool(offsets[3], object.isPaid);
  writer.writeString(offsets[4], object.paymentDate);
  writer.writeString(offsets[5], object.salaryMonth);
  writer.writeLong(offsets[6], object.staffId);
  writer.writeString(offsets[7], object.updatedAt);
  writer.writeLong(offsets[8], object.updatedBy);
}

SalaryModel _salaryModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SalaryModel();
  object.amountPaid = reader.readDouble(offsets[0]);
  object.createdAt = reader.readString(offsets[1]);
  object.createdBy = reader.readLong(offsets[2]);
  object.id = id;
  object.isPaid = reader.readBool(offsets[3]);
  object.paymentDate = reader.readStringOrNull(offsets[4]);
  object.salaryMonth = reader.readString(offsets[5]);
  object.staffId = reader.readLong(offsets[6]);
  object.updatedAt = reader.readStringOrNull(offsets[7]);
  object.updatedBy = reader.readLongOrNull(offsets[8]);
  return object;
}

P _salaryModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _salaryModelGetId(SalaryModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _salaryModelGetLinks(SalaryModel object) {
  return [];
}

void _salaryModelAttach(
    IsarCollection<dynamic> col, Id id, SalaryModel object) {
  object.id = id;
}

extension SalaryModelByIndex on IsarCollection<SalaryModel> {
  Future<SalaryModel?> getBySalaryMonthStaffId(
      String salaryMonth, int staffId) {
    return getByIndex(r'salaryMonth_staffId', [salaryMonth, staffId]);
  }

  SalaryModel? getBySalaryMonthStaffIdSync(String salaryMonth, int staffId) {
    return getByIndexSync(r'salaryMonth_staffId', [salaryMonth, staffId]);
  }

  Future<bool> deleteBySalaryMonthStaffId(String salaryMonth, int staffId) {
    return deleteByIndex(r'salaryMonth_staffId', [salaryMonth, staffId]);
  }

  bool deleteBySalaryMonthStaffIdSync(String salaryMonth, int staffId) {
    return deleteByIndexSync(r'salaryMonth_staffId', [salaryMonth, staffId]);
  }

  Future<List<SalaryModel?>> getAllBySalaryMonthStaffId(
      List<String> salaryMonthValues, List<int> staffIdValues) {
    final len = salaryMonthValues.length;
    assert(staffIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([salaryMonthValues[i], staffIdValues[i]]);
    }

    return getAllByIndex(r'salaryMonth_staffId', values);
  }

  List<SalaryModel?> getAllBySalaryMonthStaffIdSync(
      List<String> salaryMonthValues, List<int> staffIdValues) {
    final len = salaryMonthValues.length;
    assert(staffIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([salaryMonthValues[i], staffIdValues[i]]);
    }

    return getAllByIndexSync(r'salaryMonth_staffId', values);
  }

  Future<int> deleteAllBySalaryMonthStaffId(
      List<String> salaryMonthValues, List<int> staffIdValues) {
    final len = salaryMonthValues.length;
    assert(staffIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([salaryMonthValues[i], staffIdValues[i]]);
    }

    return deleteAllByIndex(r'salaryMonth_staffId', values);
  }

  int deleteAllBySalaryMonthStaffIdSync(
      List<String> salaryMonthValues, List<int> staffIdValues) {
    final len = salaryMonthValues.length;
    assert(staffIdValues.length == len,
        'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([salaryMonthValues[i], staffIdValues[i]]);
    }

    return deleteAllByIndexSync(r'salaryMonth_staffId', values);
  }

  Future<Id> putBySalaryMonthStaffId(SalaryModel object) {
    return putByIndex(r'salaryMonth_staffId', object);
  }

  Id putBySalaryMonthStaffIdSync(SalaryModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'salaryMonth_staffId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySalaryMonthStaffId(List<SalaryModel> objects) {
    return putAllByIndex(r'salaryMonth_staffId', objects);
  }

  List<Id> putAllBySalaryMonthStaffIdSync(List<SalaryModel> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'salaryMonth_staffId', objects,
        saveLinks: saveLinks);
  }
}

extension SalaryModelQueryWhereSort
    on QueryBuilder<SalaryModel, SalaryModel, QWhere> {
  QueryBuilder<SalaryModel, SalaryModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SalaryModelQueryWhere
    on QueryBuilder<SalaryModel, SalaryModel, QWhereClause> {
  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause>
      salaryMonthEqualToAnyStaffId(String salaryMonth) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'salaryMonth_staffId',
        value: [salaryMonth],
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause>
      salaryMonthNotEqualToAnyStaffId(String salaryMonth) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'salaryMonth_staffId',
              lower: [],
              upper: [salaryMonth],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'salaryMonth_staffId',
              lower: [salaryMonth],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'salaryMonth_staffId',
              lower: [salaryMonth],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'salaryMonth_staffId',
              lower: [],
              upper: [salaryMonth],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause>
      salaryMonthStaffIdEqualTo(String salaryMonth, int staffId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'salaryMonth_staffId',
        value: [salaryMonth, staffId],
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause>
      salaryMonthEqualToStaffIdNotEqualTo(String salaryMonth, int staffId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'salaryMonth_staffId',
              lower: [salaryMonth],
              upper: [salaryMonth, staffId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'salaryMonth_staffId',
              lower: [salaryMonth, staffId],
              includeLower: false,
              upper: [salaryMonth],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'salaryMonth_staffId',
              lower: [salaryMonth, staffId],
              includeLower: false,
              upper: [salaryMonth],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'salaryMonth_staffId',
              lower: [salaryMonth],
              upper: [salaryMonth, staffId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause>
      salaryMonthEqualToStaffIdGreaterThan(
    String salaryMonth,
    int staffId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'salaryMonth_staffId',
        lower: [salaryMonth, staffId],
        includeLower: include,
        upper: [salaryMonth],
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause>
      salaryMonthEqualToStaffIdLessThan(
    String salaryMonth,
    int staffId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'salaryMonth_staffId',
        lower: [salaryMonth],
        upper: [salaryMonth, staffId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterWhereClause>
      salaryMonthEqualToStaffIdBetween(
    String salaryMonth,
    int lowerStaffId,
    int upperStaffId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'salaryMonth_staffId',
        lower: [salaryMonth, lowerStaffId],
        includeLower: includeLower,
        upper: [salaryMonth, upperStaffId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SalaryModelQueryFilter
    on QueryBuilder<SalaryModel, SalaryModel, QFilterCondition> {
  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      amountPaidEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'amountPaid',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      amountPaidGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'amountPaid',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      amountPaidLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'amountPaid',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      amountPaidBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'amountPaid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'createdAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'createdAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdAt',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: '',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdAtIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdAt',
        value: '',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdByEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdBy',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdByGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdBy',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdByLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdBy',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      createdByBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition> isPaidEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isPaid',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'paymentDate',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'paymentDate',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paymentDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'paymentDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'paymentDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'paymentDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'paymentDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'paymentDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'paymentDate',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'paymentDate',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paymentDate',
        value: '',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      paymentDateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'paymentDate',
        value: '',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'salaryMonth',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'salaryMonth',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'salaryMonth',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'salaryMonth',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'salaryMonth',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'salaryMonth',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'salaryMonth',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'salaryMonth',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'salaryMonth',
        value: '',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      salaryMonthIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'salaryMonth',
        value: '',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition> staffIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'staffId',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      staffIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'staffId',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition> staffIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'staffId',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition> staffIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'staffId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'updatedAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'updatedAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updatedAt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updatedAt',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: '',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedAtIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updatedAt',
        value: '',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedByIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedBy',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedByIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedBy',
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedByEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedBy',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedByGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedBy',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedByLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedBy',
        value: value,
      ));
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterFilterCondition>
      updatedByBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SalaryModelQueryObject
    on QueryBuilder<SalaryModel, SalaryModel, QFilterCondition> {}

extension SalaryModelQueryLinks
    on QueryBuilder<SalaryModel, SalaryModel, QFilterCondition> {}

extension SalaryModelQuerySortBy
    on QueryBuilder<SalaryModel, SalaryModel, QSortBy> {
  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByAmountPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountPaid', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByAmountPaidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountPaid', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByCreatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByCreatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByIsPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPaid', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByIsPaidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPaid', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByPaymentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentDate', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByPaymentDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentDate', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortBySalaryMonth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'salaryMonth', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortBySalaryMonthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'salaryMonth', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByStaffId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'staffId', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByStaffIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'staffId', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByUpdatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedBy', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> sortByUpdatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedBy', Sort.desc);
    });
  }
}

extension SalaryModelQuerySortThenBy
    on QueryBuilder<SalaryModel, SalaryModel, QSortThenBy> {
  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByAmountPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountPaid', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByAmountPaidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountPaid', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByCreatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByCreatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByIsPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPaid', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByIsPaidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isPaid', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByPaymentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentDate', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByPaymentDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paymentDate', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenBySalaryMonth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'salaryMonth', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenBySalaryMonthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'salaryMonth', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByStaffId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'staffId', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByStaffIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'staffId', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByUpdatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedBy', Sort.asc);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QAfterSortBy> thenByUpdatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedBy', Sort.desc);
    });
  }
}

extension SalaryModelQueryWhereDistinct
    on QueryBuilder<SalaryModel, SalaryModel, QDistinct> {
  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctByAmountPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amountPaid');
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctByCreatedAt(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctByCreatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdBy');
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctByIsPaid() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isPaid');
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctByPaymentDate(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paymentDate', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctBySalaryMonth(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'salaryMonth', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctByStaffId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'staffId');
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctByUpdatedAt(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SalaryModel, SalaryModel, QDistinct> distinctByUpdatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedBy');
    });
  }
}

extension SalaryModelQueryProperty
    on QueryBuilder<SalaryModel, SalaryModel, QQueryProperty> {
  QueryBuilder<SalaryModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SalaryModel, double, QQueryOperations> amountPaidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amountPaid');
    });
  }

  QueryBuilder<SalaryModel, String, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SalaryModel, int, QQueryOperations> createdByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdBy');
    });
  }

  QueryBuilder<SalaryModel, bool, QQueryOperations> isPaidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isPaid');
    });
  }

  QueryBuilder<SalaryModel, String?, QQueryOperations> paymentDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paymentDate');
    });
  }

  QueryBuilder<SalaryModel, String, QQueryOperations> salaryMonthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'salaryMonth');
    });
  }

  QueryBuilder<SalaryModel, int, QQueryOperations> staffIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'staffId');
    });
  }

  QueryBuilder<SalaryModel, String?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<SalaryModel, int?, QQueryOperations> updatedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedBy');
    });
  }
}
