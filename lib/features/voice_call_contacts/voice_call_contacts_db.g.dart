// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_call_contacts_db.dart';

// ignore_for_file: type=lint
class $CanonicalPersonsTable extends CanonicalPersons
    with TableInfo<$CanonicalPersonsTable, CanonicalPerson> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CanonicalPersonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _primaryNameMeta =
      const VerificationMeta('primaryName');
  @override
  late final GeneratedColumn<String> primaryName = GeneratedColumn<String>(
      'primary_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mergedCountMeta =
      const VerificationMeta('mergedCount');
  @override
  late final GeneratedColumn<int> mergedCount = GeneratedColumn<int>(
      'merged_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _callCountMeta =
      const VerificationMeta('callCount');
  @override
  late final GeneratedColumn<int> callCount = GeneratedColumn<int>(
      'call_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastCalledAtMeta =
      const VerificationMeta('lastCalledAt');
  @override
  late final GeneratedColumn<DateTime> lastCalledAt = GeneratedColumn<DateTime>(
      'last_called_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, primaryName, mergedCount, callCount, lastCalledAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'canonical_persons';
  @override
  VerificationContext validateIntegrity(Insertable<CanonicalPerson> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('primary_name')) {
      context.handle(
          _primaryNameMeta,
          primaryName.isAcceptableOrUnknown(
              data['primary_name']!, _primaryNameMeta));
    } else if (isInserting) {
      context.missing(_primaryNameMeta);
    }
    if (data.containsKey('merged_count')) {
      context.handle(
          _mergedCountMeta,
          mergedCount.isAcceptableOrUnknown(
              data['merged_count']!, _mergedCountMeta));
    }
    if (data.containsKey('call_count')) {
      context.handle(_callCountMeta,
          callCount.isAcceptableOrUnknown(data['call_count']!, _callCountMeta));
    }
    if (data.containsKey('last_called_at')) {
      context.handle(
          _lastCalledAtMeta,
          lastCalledAt.isAcceptableOrUnknown(
              data['last_called_at']!, _lastCalledAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CanonicalPerson map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CanonicalPerson(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      primaryName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}primary_name'])!,
      mergedCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}merged_count'])!,
      callCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}call_count'])!,
      lastCalledAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_called_at']),
    );
  }

  @override
  $CanonicalPersonsTable createAlias(String alias) {
    return $CanonicalPersonsTable(attachedDatabase, alias);
  }
}

class CanonicalPerson extends DataClass implements Insertable<CanonicalPerson> {
  final int id;
  final String primaryName;
  final int mergedCount;
  final int callCount;
  final DateTime? lastCalledAt;
  const CanonicalPerson(
      {required this.id,
      required this.primaryName,
      required this.mergedCount,
      required this.callCount,
      this.lastCalledAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['primary_name'] = Variable<String>(primaryName);
    map['merged_count'] = Variable<int>(mergedCount);
    map['call_count'] = Variable<int>(callCount);
    if (!nullToAbsent || lastCalledAt != null) {
      map['last_called_at'] = Variable<DateTime>(lastCalledAt);
    }
    return map;
  }

  CanonicalPersonsCompanion toCompanion(bool nullToAbsent) {
    return CanonicalPersonsCompanion(
      id: Value(id),
      primaryName: Value(primaryName),
      mergedCount: Value(mergedCount),
      callCount: Value(callCount),
      lastCalledAt: lastCalledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCalledAt),
    );
  }

  factory CanonicalPerson.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CanonicalPerson(
      id: serializer.fromJson<int>(json['id']),
      primaryName: serializer.fromJson<String>(json['primaryName']),
      mergedCount: serializer.fromJson<int>(json['mergedCount']),
      callCount: serializer.fromJson<int>(json['callCount']),
      lastCalledAt: serializer.fromJson<DateTime?>(json['lastCalledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'primaryName': serializer.toJson<String>(primaryName),
      'mergedCount': serializer.toJson<int>(mergedCount),
      'callCount': serializer.toJson<int>(callCount),
      'lastCalledAt': serializer.toJson<DateTime?>(lastCalledAt),
    };
  }

  CanonicalPerson copyWith(
          {int? id,
          String? primaryName,
          int? mergedCount,
          int? callCount,
          Value<DateTime?> lastCalledAt = const Value.absent()}) =>
      CanonicalPerson(
        id: id ?? this.id,
        primaryName: primaryName ?? this.primaryName,
        mergedCount: mergedCount ?? this.mergedCount,
        callCount: callCount ?? this.callCount,
        lastCalledAt:
            lastCalledAt.present ? lastCalledAt.value : this.lastCalledAt,
      );
  CanonicalPerson copyWithCompanion(CanonicalPersonsCompanion data) {
    return CanonicalPerson(
      id: data.id.present ? data.id.value : this.id,
      primaryName:
          data.primaryName.present ? data.primaryName.value : this.primaryName,
      mergedCount:
          data.mergedCount.present ? data.mergedCount.value : this.mergedCount,
      callCount: data.callCount.present ? data.callCount.value : this.callCount,
      lastCalledAt: data.lastCalledAt.present
          ? data.lastCalledAt.value
          : this.lastCalledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CanonicalPerson(')
          ..write('id: $id, ')
          ..write('primaryName: $primaryName, ')
          ..write('mergedCount: $mergedCount, ')
          ..write('callCount: $callCount, ')
          ..write('lastCalledAt: $lastCalledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, primaryName, mergedCount, callCount, lastCalledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CanonicalPerson &&
          other.id == this.id &&
          other.primaryName == this.primaryName &&
          other.mergedCount == this.mergedCount &&
          other.callCount == this.callCount &&
          other.lastCalledAt == this.lastCalledAt);
}

class CanonicalPersonsCompanion extends UpdateCompanion<CanonicalPerson> {
  final Value<int> id;
  final Value<String> primaryName;
  final Value<int> mergedCount;
  final Value<int> callCount;
  final Value<DateTime?> lastCalledAt;
  const CanonicalPersonsCompanion({
    this.id = const Value.absent(),
    this.primaryName = const Value.absent(),
    this.mergedCount = const Value.absent(),
    this.callCount = const Value.absent(),
    this.lastCalledAt = const Value.absent(),
  });
  CanonicalPersonsCompanion.insert({
    this.id = const Value.absent(),
    required String primaryName,
    this.mergedCount = const Value.absent(),
    this.callCount = const Value.absent(),
    this.lastCalledAt = const Value.absent(),
  }) : primaryName = Value(primaryName);
  static Insertable<CanonicalPerson> custom({
    Expression<int>? id,
    Expression<String>? primaryName,
    Expression<int>? mergedCount,
    Expression<int>? callCount,
    Expression<DateTime>? lastCalledAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (primaryName != null) 'primary_name': primaryName,
      if (mergedCount != null) 'merged_count': mergedCount,
      if (callCount != null) 'call_count': callCount,
      if (lastCalledAt != null) 'last_called_at': lastCalledAt,
    });
  }

  CanonicalPersonsCompanion copyWith(
      {Value<int>? id,
      Value<String>? primaryName,
      Value<int>? mergedCount,
      Value<int>? callCount,
      Value<DateTime?>? lastCalledAt}) {
    return CanonicalPersonsCompanion(
      id: id ?? this.id,
      primaryName: primaryName ?? this.primaryName,
      mergedCount: mergedCount ?? this.mergedCount,
      callCount: callCount ?? this.callCount,
      lastCalledAt: lastCalledAt ?? this.lastCalledAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (primaryName.present) {
      map['primary_name'] = Variable<String>(primaryName.value);
    }
    if (mergedCount.present) {
      map['merged_count'] = Variable<int>(mergedCount.value);
    }
    if (callCount.present) {
      map['call_count'] = Variable<int>(callCount.value);
    }
    if (lastCalledAt.present) {
      map['last_called_at'] = Variable<DateTime>(lastCalledAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CanonicalPersonsCompanion(')
          ..write('id: $id, ')
          ..write('primaryName: $primaryName, ')
          ..write('mergedCount: $mergedCount, ')
          ..write('callCount: $callCount, ')
          ..write('lastCalledAt: $lastCalledAt')
          ..write(')'))
        .toString();
  }
}

class $PersonPhonesTable extends PersonPhones
    with TableInfo<$PersonPhonesTable, PersonPhone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonPhonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _personIdMeta =
      const VerificationMeta('personId');
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
      'person_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES canonical_persons (id) ON DELETE CASCADE'));
  static const VerificationMeta _e164Meta = const VerificationMeta('e164');
  @override
  late final GeneratedColumn<String> e164 = GeneratedColumn<String>(
      'e164', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isPrimaryMeta =
      const VerificationMeta('isPrimary');
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
      'is_primary', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_primary" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns => [id, personId, e164, label, isPrimary];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'person_phones';
  @override
  VerificationContext validateIntegrity(Insertable<PersonPhone> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('person_id')) {
      context.handle(_personIdMeta,
          personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta));
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('e164')) {
      context.handle(
          _e164Meta, e164.isAcceptableOrUnknown(data['e164']!, _e164Meta));
    } else if (isInserting) {
      context.missing(_e164Meta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('is_primary')) {
      context.handle(_isPrimaryMeta,
          isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta));
    } else if (isInserting) {
      context.missing(_isPrimaryMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonPhone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonPhone(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      personId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}person_id'])!,
      e164: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}e164'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      isPrimary: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_primary'])!,
    );
  }

  @override
  $PersonPhonesTable createAlias(String alias) {
    return $PersonPhonesTable(attachedDatabase, alias);
  }
}

class PersonPhone extends DataClass implements Insertable<PersonPhone> {
  final int id;
  final int personId;
  final String e164;
  final String label;
  final bool isPrimary;
  const PersonPhone(
      {required this.id,
      required this.personId,
      required this.e164,
      required this.label,
      required this.isPrimary});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['person_id'] = Variable<int>(personId);
    map['e164'] = Variable<String>(e164);
    map['label'] = Variable<String>(label);
    map['is_primary'] = Variable<bool>(isPrimary);
    return map;
  }

  PersonPhonesCompanion toCompanion(bool nullToAbsent) {
    return PersonPhonesCompanion(
      id: Value(id),
      personId: Value(personId),
      e164: Value(e164),
      label: Value(label),
      isPrimary: Value(isPrimary),
    );
  }

  factory PersonPhone.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonPhone(
      id: serializer.fromJson<int>(json['id']),
      personId: serializer.fromJson<int>(json['personId']),
      e164: serializer.fromJson<String>(json['e164']),
      label: serializer.fromJson<String>(json['label']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'personId': serializer.toJson<int>(personId),
      'e164': serializer.toJson<String>(e164),
      'label': serializer.toJson<String>(label),
      'isPrimary': serializer.toJson<bool>(isPrimary),
    };
  }

  PersonPhone copyWith(
          {int? id,
          int? personId,
          String? e164,
          String? label,
          bool? isPrimary}) =>
      PersonPhone(
        id: id ?? this.id,
        personId: personId ?? this.personId,
        e164: e164 ?? this.e164,
        label: label ?? this.label,
        isPrimary: isPrimary ?? this.isPrimary,
      );
  PersonPhone copyWithCompanion(PersonPhonesCompanion data) {
    return PersonPhone(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      e164: data.e164.present ? data.e164.value : this.e164,
      label: data.label.present ? data.label.value : this.label,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonPhone(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('e164: $e164, ')
          ..write('label: $label, ')
          ..write('isPrimary: $isPrimary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, personId, e164, label, isPrimary);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonPhone &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.e164 == this.e164 &&
          other.label == this.label &&
          other.isPrimary == this.isPrimary);
}

class PersonPhonesCompanion extends UpdateCompanion<PersonPhone> {
  final Value<int> id;
  final Value<int> personId;
  final Value<String> e164;
  final Value<String> label;
  final Value<bool> isPrimary;
  const PersonPhonesCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.e164 = const Value.absent(),
    this.label = const Value.absent(),
    this.isPrimary = const Value.absent(),
  });
  PersonPhonesCompanion.insert({
    this.id = const Value.absent(),
    required int personId,
    required String e164,
    required String label,
    required bool isPrimary,
  })  : personId = Value(personId),
        e164 = Value(e164),
        label = Value(label),
        isPrimary = Value(isPrimary);
  static Insertable<PersonPhone> custom({
    Expression<int>? id,
    Expression<int>? personId,
    Expression<String>? e164,
    Expression<String>? label,
    Expression<bool>? isPrimary,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (e164 != null) 'e164': e164,
      if (label != null) 'label': label,
      if (isPrimary != null) 'is_primary': isPrimary,
    });
  }

  PersonPhonesCompanion copyWith(
      {Value<int>? id,
      Value<int>? personId,
      Value<String>? e164,
      Value<String>? label,
      Value<bool>? isPrimary}) {
    return PersonPhonesCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      e164: e164 ?? this.e164,
      label: label ?? this.label,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (e164.present) {
      map['e164'] = Variable<String>(e164.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonPhonesCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('e164: $e164, ')
          ..write('label: $label, ')
          ..write('isPrimary: $isPrimary')
          ..write(')'))
        .toString();
  }
}

class $PersonAliasesTable extends PersonAliases
    with TableInfo<$PersonAliasesTable, PersonAlias> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _personIdMeta =
      const VerificationMeta('personId');
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
      'person_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES canonical_persons (id) ON DELETE CASCADE'));
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
      'alias', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedAliasMeta =
      const VerificationMeta('normalizedAlias');
  @override
  late final GeneratedColumn<String> normalizedAlias = GeneratedColumn<String>(
      'normalized_alias', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
      'origin', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
      'weight', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, personId, alias, normalizedAlias, origin, weight];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'person_aliases';
  @override
  VerificationContext validateIntegrity(Insertable<PersonAlias> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('person_id')) {
      context.handle(_personIdMeta,
          personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta));
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
          _aliasMeta, alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta));
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('normalized_alias')) {
      context.handle(
          _normalizedAliasMeta,
          normalizedAlias.isAcceptableOrUnknown(
              data['normalized_alias']!, _normalizedAliasMeta));
    } else if (isInserting) {
      context.missing(_normalizedAliasMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(_originMeta,
          origin.isAcceptableOrUnknown(data['origin']!, _originMeta));
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonAlias map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonAlias(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      personId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}person_id'])!,
      alias: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias'])!,
      normalizedAlias: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_alias'])!,
      origin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}origin'])!,
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight'])!,
    );
  }

  @override
  $PersonAliasesTable createAlias(String alias) {
    return $PersonAliasesTable(attachedDatabase, alias);
  }
}

class PersonAlias extends DataClass implements Insertable<PersonAlias> {
  final int id;
  final int personId;
  final String alias;
  final String normalizedAlias;

  /// 'device_import' (replaced on every import) or 'user_custom' (kept).
  final String origin;
  final double weight;
  const PersonAlias(
      {required this.id,
      required this.personId,
      required this.alias,
      required this.normalizedAlias,
      required this.origin,
      required this.weight});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['person_id'] = Variable<int>(personId);
    map['alias'] = Variable<String>(alias);
    map['normalized_alias'] = Variable<String>(normalizedAlias);
    map['origin'] = Variable<String>(origin);
    map['weight'] = Variable<double>(weight);
    return map;
  }

  PersonAliasesCompanion toCompanion(bool nullToAbsent) {
    return PersonAliasesCompanion(
      id: Value(id),
      personId: Value(personId),
      alias: Value(alias),
      normalizedAlias: Value(normalizedAlias),
      origin: Value(origin),
      weight: Value(weight),
    );
  }

  factory PersonAlias.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonAlias(
      id: serializer.fromJson<int>(json['id']),
      personId: serializer.fromJson<int>(json['personId']),
      alias: serializer.fromJson<String>(json['alias']),
      normalizedAlias: serializer.fromJson<String>(json['normalizedAlias']),
      origin: serializer.fromJson<String>(json['origin']),
      weight: serializer.fromJson<double>(json['weight']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'personId': serializer.toJson<int>(personId),
      'alias': serializer.toJson<String>(alias),
      'normalizedAlias': serializer.toJson<String>(normalizedAlias),
      'origin': serializer.toJson<String>(origin),
      'weight': serializer.toJson<double>(weight),
    };
  }

  PersonAlias copyWith(
          {int? id,
          int? personId,
          String? alias,
          String? normalizedAlias,
          String? origin,
          double? weight}) =>
      PersonAlias(
        id: id ?? this.id,
        personId: personId ?? this.personId,
        alias: alias ?? this.alias,
        normalizedAlias: normalizedAlias ?? this.normalizedAlias,
        origin: origin ?? this.origin,
        weight: weight ?? this.weight,
      );
  PersonAlias copyWithCompanion(PersonAliasesCompanion data) {
    return PersonAlias(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      alias: data.alias.present ? data.alias.value : this.alias,
      normalizedAlias: data.normalizedAlias.present
          ? data.normalizedAlias.value
          : this.normalizedAlias,
      origin: data.origin.present ? data.origin.value : this.origin,
      weight: data.weight.present ? data.weight.value : this.weight,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonAlias(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('alias: $alias, ')
          ..write('normalizedAlias: $normalizedAlias, ')
          ..write('origin: $origin, ')
          ..write('weight: $weight')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, personId, alias, normalizedAlias, origin, weight);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonAlias &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.alias == this.alias &&
          other.normalizedAlias == this.normalizedAlias &&
          other.origin == this.origin &&
          other.weight == this.weight);
}

class PersonAliasesCompanion extends UpdateCompanion<PersonAlias> {
  final Value<int> id;
  final Value<int> personId;
  final Value<String> alias;
  final Value<String> normalizedAlias;
  final Value<String> origin;
  final Value<double> weight;
  const PersonAliasesCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.alias = const Value.absent(),
    this.normalizedAlias = const Value.absent(),
    this.origin = const Value.absent(),
    this.weight = const Value.absent(),
  });
  PersonAliasesCompanion.insert({
    this.id = const Value.absent(),
    required int personId,
    required String alias,
    required String normalizedAlias,
    required String origin,
    this.weight = const Value.absent(),
  })  : personId = Value(personId),
        alias = Value(alias),
        normalizedAlias = Value(normalizedAlias),
        origin = Value(origin);
  static Insertable<PersonAlias> custom({
    Expression<int>? id,
    Expression<int>? personId,
    Expression<String>? alias,
    Expression<String>? normalizedAlias,
    Expression<String>? origin,
    Expression<double>? weight,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (alias != null) 'alias': alias,
      if (normalizedAlias != null) 'normalized_alias': normalizedAlias,
      if (origin != null) 'origin': origin,
      if (weight != null) 'weight': weight,
    });
  }

  PersonAliasesCompanion copyWith(
      {Value<int>? id,
      Value<int>? personId,
      Value<String>? alias,
      Value<String>? normalizedAlias,
      Value<String>? origin,
      Value<double>? weight}) {
    return PersonAliasesCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      alias: alias ?? this.alias,
      normalizedAlias: normalizedAlias ?? this.normalizedAlias,
      origin: origin ?? this.origin,
      weight: weight ?? this.weight,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (normalizedAlias.present) {
      map['normalized_alias'] = Variable<String>(normalizedAlias.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonAliasesCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('alias: $alias, ')
          ..write('normalizedAlias: $normalizedAlias, ')
          ..write('origin: $origin, ')
          ..write('weight: $weight')
          ..write(')'))
        .toString();
  }
}

abstract class _$VoiceCallContactsDb extends GeneratedDatabase {
  _$VoiceCallContactsDb(QueryExecutor e) : super(e);
  $VoiceCallContactsDbManager get managers => $VoiceCallContactsDbManager(this);
  late final $CanonicalPersonsTable canonicalPersons =
      $CanonicalPersonsTable(this);
  late final $PersonPhonesTable personPhones = $PersonPhonesTable(this);
  late final $PersonAliasesTable personAliases = $PersonAliasesTable(this);
  late final Index personAliasesNormalized = Index('person_aliases_normalized',
      'CREATE INDEX person_aliases_normalized ON person_aliases (normalized_alias)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [canonicalPersons, personPhones, personAliases, personAliasesNormalized];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('canonical_persons',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('person_phones', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('canonical_persons',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('person_aliases', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$CanonicalPersonsTableCreateCompanionBuilder
    = CanonicalPersonsCompanion Function({
  Value<int> id,
  required String primaryName,
  Value<int> mergedCount,
  Value<int> callCount,
  Value<DateTime?> lastCalledAt,
});
typedef $$CanonicalPersonsTableUpdateCompanionBuilder
    = CanonicalPersonsCompanion Function({
  Value<int> id,
  Value<String> primaryName,
  Value<int> mergedCount,
  Value<int> callCount,
  Value<DateTime?> lastCalledAt,
});

final class $$CanonicalPersonsTableReferences extends BaseReferences<
    _$VoiceCallContactsDb, $CanonicalPersonsTable, CanonicalPerson> {
  $$CanonicalPersonsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PersonPhonesTable, List<PersonPhone>>
      _personPhonesRefsTable(_$VoiceCallContactsDb db) =>
          MultiTypedResultKey.fromTable(db.personPhones,
              aliasName: 'canonical_persons__id__person_phones__person_id');

  $$PersonPhonesTableProcessedTableManager get personPhonesRefs {
    final manager = $$PersonPhonesTableTableManager($_db, $_db.personPhones)
        .filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_personPhonesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PersonAliasesTable, List<PersonAlias>>
      _personAliasesRefsTable(_$VoiceCallContactsDb db) =>
          MultiTypedResultKey.fromTable(db.personAliases,
              aliasName: 'canonical_persons__id__person_aliases__person_id');

  $$PersonAliasesTableProcessedTableManager get personAliasesRefs {
    final manager = $$PersonAliasesTableTableManager($_db, $_db.personAliases)
        .filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_personAliasesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CanonicalPersonsTableFilterComposer
    extends Composer<_$VoiceCallContactsDb, $CanonicalPersonsTable> {
  $$CanonicalPersonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get primaryName => $composableBuilder(
      column: $table.primaryName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mergedCount => $composableBuilder(
      column: $table.mergedCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get callCount => $composableBuilder(
      column: $table.callCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastCalledAt => $composableBuilder(
      column: $table.lastCalledAt, builder: (column) => ColumnFilters(column));

  Expression<bool> personPhonesRefs(
      Expression<bool> Function($$PersonPhonesTableFilterComposer f) f) {
    final $$PersonPhonesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.personPhones,
        getReferencedColumn: (t) => t.personId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PersonPhonesTableFilterComposer(
              $db: $db,
              $table: $db.personPhones,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> personAliasesRefs(
      Expression<bool> Function($$PersonAliasesTableFilterComposer f) f) {
    final $$PersonAliasesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.personAliases,
        getReferencedColumn: (t) => t.personId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PersonAliasesTableFilterComposer(
              $db: $db,
              $table: $db.personAliases,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CanonicalPersonsTableOrderingComposer
    extends Composer<_$VoiceCallContactsDb, $CanonicalPersonsTable> {
  $$CanonicalPersonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get primaryName => $composableBuilder(
      column: $table.primaryName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mergedCount => $composableBuilder(
      column: $table.mergedCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get callCount => $composableBuilder(
      column: $table.callCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastCalledAt => $composableBuilder(
      column: $table.lastCalledAt,
      builder: (column) => ColumnOrderings(column));
}

class $$CanonicalPersonsTableAnnotationComposer
    extends Composer<_$VoiceCallContactsDb, $CanonicalPersonsTable> {
  $$CanonicalPersonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get primaryName => $composableBuilder(
      column: $table.primaryName, builder: (column) => column);

  GeneratedColumn<int> get mergedCount => $composableBuilder(
      column: $table.mergedCount, builder: (column) => column);

  GeneratedColumn<int> get callCount =>
      $composableBuilder(column: $table.callCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCalledAt => $composableBuilder(
      column: $table.lastCalledAt, builder: (column) => column);

  Expression<T> personPhonesRefs<T extends Object>(
      Expression<T> Function($$PersonPhonesTableAnnotationComposer a) f) {
    final $$PersonPhonesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.personPhones,
        getReferencedColumn: (t) => t.personId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PersonPhonesTableAnnotationComposer(
              $db: $db,
              $table: $db.personPhones,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> personAliasesRefs<T extends Object>(
      Expression<T> Function($$PersonAliasesTableAnnotationComposer a) f) {
    final $$PersonAliasesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.personAliases,
        getReferencedColumn: (t) => t.personId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PersonAliasesTableAnnotationComposer(
              $db: $db,
              $table: $db.personAliases,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CanonicalPersonsTableTableManager extends RootTableManager<
    _$VoiceCallContactsDb,
    $CanonicalPersonsTable,
    CanonicalPerson,
    $$CanonicalPersonsTableFilterComposer,
    $$CanonicalPersonsTableOrderingComposer,
    $$CanonicalPersonsTableAnnotationComposer,
    $$CanonicalPersonsTableCreateCompanionBuilder,
    $$CanonicalPersonsTableUpdateCompanionBuilder,
    (CanonicalPerson, $$CanonicalPersonsTableReferences),
    CanonicalPerson,
    PrefetchHooks Function({bool personPhonesRefs, bool personAliasesRefs})> {
  $$CanonicalPersonsTableTableManager(
      _$VoiceCallContactsDb db, $CanonicalPersonsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CanonicalPersonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CanonicalPersonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CanonicalPersonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> primaryName = const Value.absent(),
            Value<int> mergedCount = const Value.absent(),
            Value<int> callCount = const Value.absent(),
            Value<DateTime?> lastCalledAt = const Value.absent(),
          }) =>
              CanonicalPersonsCompanion(
            id: id,
            primaryName: primaryName,
            mergedCount: mergedCount,
            callCount: callCount,
            lastCalledAt: lastCalledAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String primaryName,
            Value<int> mergedCount = const Value.absent(),
            Value<int> callCount = const Value.absent(),
            Value<DateTime?> lastCalledAt = const Value.absent(),
          }) =>
              CanonicalPersonsCompanion.insert(
            id: id,
            primaryName: primaryName,
            mergedCount: mergedCount,
            callCount: callCount,
            lastCalledAt: lastCalledAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CanonicalPersonsTable, CanonicalPerson>(table),
                    $$CanonicalPersonsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {personPhonesRefs = false, personAliasesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (personPhonesRefs) db.personPhones,
                if (personAliasesRefs) db.personAliases
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (personPhonesRefs)
                    await $_getPrefetchedDataByColumns<
                            CanonicalPerson,
                            $CanonicalPersonsTable,
                            PersonPhone,
                            $PersonPhonesTable>(
                        currentTable: table,
                        referencedTable: $$CanonicalPersonsTableReferences
                            ._personPhonesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CanonicalPersonsTableReferences(db, table, p0)
                                .personPhonesRefs,
                        currentColumn: 'id',
                        referencedColumn: 'person_id',
                        typedResults: items),
                  if (personAliasesRefs)
                    await $_getPrefetchedDataByColumns<
                            CanonicalPerson,
                            $CanonicalPersonsTable,
                            PersonAlias,
                            $PersonAliasesTable>(
                        currentTable: table,
                        referencedTable: $$CanonicalPersonsTableReferences
                            ._personAliasesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CanonicalPersonsTableReferences(db, table, p0)
                                .personAliasesRefs,
                        currentColumn: 'id',
                        referencedColumn: 'person_id',
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CanonicalPersonsTableProcessedTableManager = ProcessedTableManager<
    _$VoiceCallContactsDb,
    $CanonicalPersonsTable,
    CanonicalPerson,
    $$CanonicalPersonsTableFilterComposer,
    $$CanonicalPersonsTableOrderingComposer,
    $$CanonicalPersonsTableAnnotationComposer,
    $$CanonicalPersonsTableCreateCompanionBuilder,
    $$CanonicalPersonsTableUpdateCompanionBuilder,
    (CanonicalPerson, $$CanonicalPersonsTableReferences),
    CanonicalPerson,
    PrefetchHooks Function({bool personPhonesRefs, bool personAliasesRefs})>;
typedef $$PersonPhonesTableCreateCompanionBuilder = PersonPhonesCompanion
    Function({
  Value<int> id,
  required int personId,
  required String e164,
  required String label,
  required bool isPrimary,
});
typedef $$PersonPhonesTableUpdateCompanionBuilder = PersonPhonesCompanion
    Function({
  Value<int> id,
  Value<int> personId,
  Value<String> e164,
  Value<String> label,
  Value<bool> isPrimary,
});

final class $$PersonPhonesTableReferences extends BaseReferences<
    _$VoiceCallContactsDb, $PersonPhonesTable, PersonPhone> {
  $$PersonPhonesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CanonicalPersonsTable _personIdTable(_$VoiceCallContactsDb db) =>
      db.canonicalPersons
          .createAlias('person_phones__person_id__canonical_persons__id');

  $$CanonicalPersonsTableProcessedTableManager get personId {
    final $_column = $_itemColumn<int>('person_id')!;

    final manager =
        $$CanonicalPersonsTableTableManager($_db, $_db.canonicalPersons)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PersonPhonesTableFilterComposer
    extends Composer<_$VoiceCallContactsDb, $PersonPhonesTable> {
  $$PersonPhonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get e164 => $composableBuilder(
      column: $table.e164, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnFilters(column));

  $$CanonicalPersonsTableFilterComposer get personId {
    final $$CanonicalPersonsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.personId,
        referencedTable: $db.canonicalPersons,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CanonicalPersonsTableFilterComposer(
              $db: $db,
              $table: $db.canonicalPersons,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PersonPhonesTableOrderingComposer
    extends Composer<_$VoiceCallContactsDb, $PersonPhonesTable> {
  $$PersonPhonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get e164 => $composableBuilder(
      column: $table.e164, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnOrderings(column));

  $$CanonicalPersonsTableOrderingComposer get personId {
    final $$CanonicalPersonsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.personId,
        referencedTable: $db.canonicalPersons,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CanonicalPersonsTableOrderingComposer(
              $db: $db,
              $table: $db.canonicalPersons,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PersonPhonesTableAnnotationComposer
    extends Composer<_$VoiceCallContactsDb, $PersonPhonesTable> {
  $$PersonPhonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get e164 =>
      $composableBuilder(column: $table.e164, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  $$CanonicalPersonsTableAnnotationComposer get personId {
    final $$CanonicalPersonsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.personId,
        referencedTable: $db.canonicalPersons,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CanonicalPersonsTableAnnotationComposer(
              $db: $db,
              $table: $db.canonicalPersons,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PersonPhonesTableTableManager extends RootTableManager<
    _$VoiceCallContactsDb,
    $PersonPhonesTable,
    PersonPhone,
    $$PersonPhonesTableFilterComposer,
    $$PersonPhonesTableOrderingComposer,
    $$PersonPhonesTableAnnotationComposer,
    $$PersonPhonesTableCreateCompanionBuilder,
    $$PersonPhonesTableUpdateCompanionBuilder,
    (PersonPhone, $$PersonPhonesTableReferences),
    PersonPhone,
    PrefetchHooks Function({bool personId})> {
  $$PersonPhonesTableTableManager(
      _$VoiceCallContactsDb db, $PersonPhonesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonPhonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonPhonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonPhonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> personId = const Value.absent(),
            Value<String> e164 = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<bool> isPrimary = const Value.absent(),
          }) =>
              PersonPhonesCompanion(
            id: id,
            personId: personId,
            e164: e164,
            label: label,
            isPrimary: isPrimary,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int personId,
            required String e164,
            required String label,
            required bool isPrimary,
          }) =>
              PersonPhonesCompanion.insert(
            id: id,
            personId: personId,
            e164: e164,
            label: label,
            isPrimary: isPrimary,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PersonPhonesTable, PersonPhone>(table),
                    $$PersonPhonesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({personId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (personId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.personId,
                    referencedTable:
                        $$PersonPhonesTableReferences._personIdTable(db),
                    referencedColumn:
                        $$PersonPhonesTableReferences._personIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PersonPhonesTableProcessedTableManager = ProcessedTableManager<
    _$VoiceCallContactsDb,
    $PersonPhonesTable,
    PersonPhone,
    $$PersonPhonesTableFilterComposer,
    $$PersonPhonesTableOrderingComposer,
    $$PersonPhonesTableAnnotationComposer,
    $$PersonPhonesTableCreateCompanionBuilder,
    $$PersonPhonesTableUpdateCompanionBuilder,
    (PersonPhone, $$PersonPhonesTableReferences),
    PersonPhone,
    PrefetchHooks Function({bool personId})>;
typedef $$PersonAliasesTableCreateCompanionBuilder = PersonAliasesCompanion
    Function({
  Value<int> id,
  required int personId,
  required String alias,
  required String normalizedAlias,
  required String origin,
  Value<double> weight,
});
typedef $$PersonAliasesTableUpdateCompanionBuilder = PersonAliasesCompanion
    Function({
  Value<int> id,
  Value<int> personId,
  Value<String> alias,
  Value<String> normalizedAlias,
  Value<String> origin,
  Value<double> weight,
});

final class $$PersonAliasesTableReferences extends BaseReferences<
    _$VoiceCallContactsDb, $PersonAliasesTable, PersonAlias> {
  $$PersonAliasesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CanonicalPersonsTable _personIdTable(_$VoiceCallContactsDb db) =>
      db.canonicalPersons
          .createAlias('person_aliases__person_id__canonical_persons__id');

  $$CanonicalPersonsTableProcessedTableManager get personId {
    final $_column = $_itemColumn<int>('person_id')!;

    final manager =
        $$CanonicalPersonsTableTableManager($_db, $_db.canonicalPersons)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PersonAliasesTableFilterComposer
    extends Composer<_$VoiceCallContactsDb, $PersonAliasesTable> {
  $$PersonAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedAlias => $composableBuilder(
      column: $table.normalizedAlias,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get origin => $composableBuilder(
      column: $table.origin, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnFilters(column));

  $$CanonicalPersonsTableFilterComposer get personId {
    final $$CanonicalPersonsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.personId,
        referencedTable: $db.canonicalPersons,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CanonicalPersonsTableFilterComposer(
              $db: $db,
              $table: $db.canonicalPersons,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PersonAliasesTableOrderingComposer
    extends Composer<_$VoiceCallContactsDb, $PersonAliasesTable> {
  $$PersonAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedAlias => $composableBuilder(
      column: $table.normalizedAlias,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get origin => $composableBuilder(
      column: $table.origin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnOrderings(column));

  $$CanonicalPersonsTableOrderingComposer get personId {
    final $$CanonicalPersonsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.personId,
        referencedTable: $db.canonicalPersons,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CanonicalPersonsTableOrderingComposer(
              $db: $db,
              $table: $db.canonicalPersons,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PersonAliasesTableAnnotationComposer
    extends Composer<_$VoiceCallContactsDb, $PersonAliasesTable> {
  $$PersonAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get normalizedAlias => $composableBuilder(
      column: $table.normalizedAlias, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  $$CanonicalPersonsTableAnnotationComposer get personId {
    final $$CanonicalPersonsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.personId,
        referencedTable: $db.canonicalPersons,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CanonicalPersonsTableAnnotationComposer(
              $db: $db,
              $table: $db.canonicalPersons,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PersonAliasesTableTableManager extends RootTableManager<
    _$VoiceCallContactsDb,
    $PersonAliasesTable,
    PersonAlias,
    $$PersonAliasesTableFilterComposer,
    $$PersonAliasesTableOrderingComposer,
    $$PersonAliasesTableAnnotationComposer,
    $$PersonAliasesTableCreateCompanionBuilder,
    $$PersonAliasesTableUpdateCompanionBuilder,
    (PersonAlias, $$PersonAliasesTableReferences),
    PersonAlias,
    PrefetchHooks Function({bool personId})> {
  $$PersonAliasesTableTableManager(
      _$VoiceCallContactsDb db, $PersonAliasesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonAliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> personId = const Value.absent(),
            Value<String> alias = const Value.absent(),
            Value<String> normalizedAlias = const Value.absent(),
            Value<String> origin = const Value.absent(),
            Value<double> weight = const Value.absent(),
          }) =>
              PersonAliasesCompanion(
            id: id,
            personId: personId,
            alias: alias,
            normalizedAlias: normalizedAlias,
            origin: origin,
            weight: weight,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int personId,
            required String alias,
            required String normalizedAlias,
            required String origin,
            Value<double> weight = const Value.absent(),
          }) =>
              PersonAliasesCompanion.insert(
            id: id,
            personId: personId,
            alias: alias,
            normalizedAlias: normalizedAlias,
            origin: origin,
            weight: weight,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PersonAliasesTable, PersonAlias>(table),
                    $$PersonAliasesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({personId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (personId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.personId,
                    referencedTable:
                        $$PersonAliasesTableReferences._personIdTable(db),
                    referencedColumn:
                        $$PersonAliasesTableReferences._personIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PersonAliasesTableProcessedTableManager = ProcessedTableManager<
    _$VoiceCallContactsDb,
    $PersonAliasesTable,
    PersonAlias,
    $$PersonAliasesTableFilterComposer,
    $$PersonAliasesTableOrderingComposer,
    $$PersonAliasesTableAnnotationComposer,
    $$PersonAliasesTableCreateCompanionBuilder,
    $$PersonAliasesTableUpdateCompanionBuilder,
    (PersonAlias, $$PersonAliasesTableReferences),
    PersonAlias,
    PrefetchHooks Function({bool personId})>;

class $VoiceCallContactsDbManager {
  final _$VoiceCallContactsDb _db;
  $VoiceCallContactsDbManager(this._db);
  $$CanonicalPersonsTableTableManager get canonicalPersons =>
      $$CanonicalPersonsTableTableManager(_db, _db.canonicalPersons);
  $$PersonPhonesTableTableManager get personPhones =>
      $$PersonPhonesTableTableManager(_db, _db.personPhones);
  $$PersonAliasesTableTableManager get personAliases =>
      $$PersonAliasesTableTableManager(_db, _db.personAliases);
}
