// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PeopleTable extends People with TableInfo<$PeopleTable, Person> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyMeta = const VerificationMeta(
    'company',
  );
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waNumberMeta = const VerificationMeta(
    'waNumber',
  );
  @override
  late final GeneratedColumn<String> waNumber = GeneratedColumn<String>(
    'wa_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wechatIdMeta = const VerificationMeta(
    'wechatId',
  );
  @override
  late final GeneratedColumn<String> wechatId = GeneratedColumn<String>(
    'wechat_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredChannelMeta = const VerificationMeta(
    'preferredChannel',
  );
  @override
  late final GeneratedColumn<String> preferredChannel = GeneratedColumn<String>(
    'preferred_channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('wa'),
  );
  static const VerificationMeta _metWhereMeta = const VerificationMeta(
    'metWhere',
  );
  @override
  late final GeneratedColumn<String> metWhere = GeneratedColumn<String>(
    'met_where',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metWhenMeta = const VerificationMeta(
    'metWhen',
  );
  @override
  late final GeneratedColumn<DateTime> metWhen = GeneratedColumn<DateTime>(
    'met_when',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  occasionTags = GeneratedColumn<String>(
    'occasion_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  ).withConverter<List<String>>($PeopleTable.$converteroccasionTags);
  static const VerificationMeta _pingDateMeta = const VerificationMeta(
    'pingDate',
  );
  @override
  late final GeneratedColumn<DateTime> pingDate = GeneratedColumn<DateTime>(
    'ping_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pingNoteMeta = const VerificationMeta(
    'pingNote',
  );
  @override
  late final GeneratedColumn<String> pingNote = GeneratedColumn<String>(
    'ping_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    company,
    waNumber,
    wechatId,
    preferredChannel,
    metWhere,
    metWhen,
    notes,
    occasionTags,
    pingDate,
    pingNote,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people';
  @override
  VerificationContext validateIntegrity(
    Insertable<Person> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('company')) {
      context.handle(
        _companyMeta,
        company.isAcceptableOrUnknown(data['company']!, _companyMeta),
      );
    }
    if (data.containsKey('wa_number')) {
      context.handle(
        _waNumberMeta,
        waNumber.isAcceptableOrUnknown(data['wa_number']!, _waNumberMeta),
      );
    }
    if (data.containsKey('wechat_id')) {
      context.handle(
        _wechatIdMeta,
        wechatId.isAcceptableOrUnknown(data['wechat_id']!, _wechatIdMeta),
      );
    }
    if (data.containsKey('preferred_channel')) {
      context.handle(
        _preferredChannelMeta,
        preferredChannel.isAcceptableOrUnknown(
          data['preferred_channel']!,
          _preferredChannelMeta,
        ),
      );
    }
    if (data.containsKey('met_where')) {
      context.handle(
        _metWhereMeta,
        metWhere.isAcceptableOrUnknown(data['met_where']!, _metWhereMeta),
      );
    }
    if (data.containsKey('met_when')) {
      context.handle(
        _metWhenMeta,
        metWhen.isAcceptableOrUnknown(data['met_when']!, _metWhenMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('ping_date')) {
      context.handle(
        _pingDateMeta,
        pingDate.isAcceptableOrUnknown(data['ping_date']!, _pingDateMeta),
      );
    }
    if (data.containsKey('ping_note')) {
      context.handle(
        _pingNoteMeta,
        pingNote.isAcceptableOrUnknown(data['ping_note']!, _pingNoteMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Person map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Person(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      company: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company'],
      ),
      waNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wa_number'],
      ),
      wechatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wechat_id'],
      ),
      preferredChannel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_channel'],
      )!,
      metWhere: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}met_where'],
      ),
      metWhen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}met_when'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      occasionTags: $PeopleTable.$converteroccasionTags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}occasion_tags'],
        )!,
      ),
      pingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ping_date'],
      ),
      pingNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ping_note'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PeopleTable createAlias(String alias) {
    return $PeopleTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converteroccasionTags =
      const TagListConverter();
}

class Person extends DataClass implements Insertable<Person> {
  final int id;
  final String name;
  final String? company;
  final String? waNumber;
  final String? wechatId;

  /// 'wa' | 'wechat'. Drives which action the row offers.
  final String preferredChannel;
  final String? metWhere;
  final DateTime? metWhen;
  final String? notes;

  /// ⚠ The load-bearing field. Cannot be sensibly backfilled — you will not
  /// remember. Captured at A1, never after.
  final List<String> occasionTags;
  final DateTime? pingDate;
  final String? pingNote;

  /// Sync columns, present from day one. ⚠ Soft delete only — a hard-deleted
  /// row leaves nothing to tell the other device it is gone, so it syncs
  /// straight back. In Phase 4 the SERVER stamps updatedAt, never the client.
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Person({
    required this.id,
    required this.name,
    this.company,
    this.waNumber,
    this.wechatId,
    required this.preferredChannel,
    this.metWhere,
    this.metWhen,
    this.notes,
    required this.occasionTags,
    this.pingDate,
    this.pingNote,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || company != null) {
      map['company'] = Variable<String>(company);
    }
    if (!nullToAbsent || waNumber != null) {
      map['wa_number'] = Variable<String>(waNumber);
    }
    if (!nullToAbsent || wechatId != null) {
      map['wechat_id'] = Variable<String>(wechatId);
    }
    map['preferred_channel'] = Variable<String>(preferredChannel);
    if (!nullToAbsent || metWhere != null) {
      map['met_where'] = Variable<String>(metWhere);
    }
    if (!nullToAbsent || metWhen != null) {
      map['met_when'] = Variable<DateTime>(metWhen);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    {
      map['occasion_tags'] = Variable<String>(
        $PeopleTable.$converteroccasionTags.toSql(occasionTags),
      );
    }
    if (!nullToAbsent || pingDate != null) {
      map['ping_date'] = Variable<DateTime>(pingDate);
    }
    if (!nullToAbsent || pingNote != null) {
      map['ping_note'] = Variable<String>(pingNote);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(
      id: Value(id),
      name: Value(name),
      company: company == null && nullToAbsent
          ? const Value.absent()
          : Value(company),
      waNumber: waNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(waNumber),
      wechatId: wechatId == null && nullToAbsent
          ? const Value.absent()
          : Value(wechatId),
      preferredChannel: Value(preferredChannel),
      metWhere: metWhere == null && nullToAbsent
          ? const Value.absent()
          : Value(metWhere),
      metWhen: metWhen == null && nullToAbsent
          ? const Value.absent()
          : Value(metWhen),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      occasionTags: Value(occasionTags),
      pingDate: pingDate == null && nullToAbsent
          ? const Value.absent()
          : Value(pingDate),
      pingNote: pingNote == null && nullToAbsent
          ? const Value.absent()
          : Value(pingNote),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Person.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Person(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      company: serializer.fromJson<String?>(json['company']),
      waNumber: serializer.fromJson<String?>(json['waNumber']),
      wechatId: serializer.fromJson<String?>(json['wechatId']),
      preferredChannel: serializer.fromJson<String>(json['preferredChannel']),
      metWhere: serializer.fromJson<String?>(json['metWhere']),
      metWhen: serializer.fromJson<DateTime?>(json['metWhen']),
      notes: serializer.fromJson<String?>(json['notes']),
      occasionTags: serializer.fromJson<List<String>>(json['occasionTags']),
      pingDate: serializer.fromJson<DateTime?>(json['pingDate']),
      pingNote: serializer.fromJson<String?>(json['pingNote']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'company': serializer.toJson<String?>(company),
      'waNumber': serializer.toJson<String?>(waNumber),
      'wechatId': serializer.toJson<String?>(wechatId),
      'preferredChannel': serializer.toJson<String>(preferredChannel),
      'metWhere': serializer.toJson<String?>(metWhere),
      'metWhen': serializer.toJson<DateTime?>(metWhen),
      'notes': serializer.toJson<String?>(notes),
      'occasionTags': serializer.toJson<List<String>>(occasionTags),
      'pingDate': serializer.toJson<DateTime?>(pingDate),
      'pingNote': serializer.toJson<String?>(pingNote),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Person copyWith({
    int? id,
    String? name,
    Value<String?> company = const Value.absent(),
    Value<String?> waNumber = const Value.absent(),
    Value<String?> wechatId = const Value.absent(),
    String? preferredChannel,
    Value<String?> metWhere = const Value.absent(),
    Value<DateTime?> metWhen = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    List<String>? occasionTags,
    Value<DateTime?> pingDate = const Value.absent(),
    Value<String?> pingNote = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Person(
    id: id ?? this.id,
    name: name ?? this.name,
    company: company.present ? company.value : this.company,
    waNumber: waNumber.present ? waNumber.value : this.waNumber,
    wechatId: wechatId.present ? wechatId.value : this.wechatId,
    preferredChannel: preferredChannel ?? this.preferredChannel,
    metWhere: metWhere.present ? metWhere.value : this.metWhere,
    metWhen: metWhen.present ? metWhen.value : this.metWhen,
    notes: notes.present ? notes.value : this.notes,
    occasionTags: occasionTags ?? this.occasionTags,
    pingDate: pingDate.present ? pingDate.value : this.pingDate,
    pingNote: pingNote.present ? pingNote.value : this.pingNote,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Person copyWithCompanion(PeopleCompanion data) {
    return Person(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      company: data.company.present ? data.company.value : this.company,
      waNumber: data.waNumber.present ? data.waNumber.value : this.waNumber,
      wechatId: data.wechatId.present ? data.wechatId.value : this.wechatId,
      preferredChannel: data.preferredChannel.present
          ? data.preferredChannel.value
          : this.preferredChannel,
      metWhere: data.metWhere.present ? data.metWhere.value : this.metWhere,
      metWhen: data.metWhen.present ? data.metWhen.value : this.metWhen,
      notes: data.notes.present ? data.notes.value : this.notes,
      occasionTags: data.occasionTags.present
          ? data.occasionTags.value
          : this.occasionTags,
      pingDate: data.pingDate.present ? data.pingDate.value : this.pingDate,
      pingNote: data.pingNote.present ? data.pingNote.value : this.pingNote,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Person(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('company: $company, ')
          ..write('waNumber: $waNumber, ')
          ..write('wechatId: $wechatId, ')
          ..write('preferredChannel: $preferredChannel, ')
          ..write('metWhere: $metWhere, ')
          ..write('metWhen: $metWhen, ')
          ..write('notes: $notes, ')
          ..write('occasionTags: $occasionTags, ')
          ..write('pingDate: $pingDate, ')
          ..write('pingNote: $pingNote, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    company,
    waNumber,
    wechatId,
    preferredChannel,
    metWhere,
    metWhen,
    notes,
    occasionTags,
    pingDate,
    pingNote,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Person &&
          other.id == this.id &&
          other.name == this.name &&
          other.company == this.company &&
          other.waNumber == this.waNumber &&
          other.wechatId == this.wechatId &&
          other.preferredChannel == this.preferredChannel &&
          other.metWhere == this.metWhere &&
          other.metWhen == this.metWhen &&
          other.notes == this.notes &&
          other.occasionTags == this.occasionTags &&
          other.pingDate == this.pingDate &&
          other.pingNote == this.pingNote &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PeopleCompanion extends UpdateCompanion<Person> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> company;
  final Value<String?> waNumber;
  final Value<String?> wechatId;
  final Value<String> preferredChannel;
  final Value<String?> metWhere;
  final Value<DateTime?> metWhen;
  final Value<String?> notes;
  final Value<List<String>> occasionTags;
  final Value<DateTime?> pingDate;
  final Value<String?> pingNote;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const PeopleCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.company = const Value.absent(),
    this.waNumber = const Value.absent(),
    this.wechatId = const Value.absent(),
    this.preferredChannel = const Value.absent(),
    this.metWhere = const Value.absent(),
    this.metWhen = const Value.absent(),
    this.notes = const Value.absent(),
    this.occasionTags = const Value.absent(),
    this.pingDate = const Value.absent(),
    this.pingNote = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PeopleCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.company = const Value.absent(),
    this.waNumber = const Value.absent(),
    this.wechatId = const Value.absent(),
    this.preferredChannel = const Value.absent(),
    this.metWhere = const Value.absent(),
    this.metWhen = const Value.absent(),
    this.notes = const Value.absent(),
    this.occasionTags = const Value.absent(),
    this.pingDate = const Value.absent(),
    this.pingNote = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Person> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? company,
    Expression<String>? waNumber,
    Expression<String>? wechatId,
    Expression<String>? preferredChannel,
    Expression<String>? metWhere,
    Expression<DateTime>? metWhen,
    Expression<String>? notes,
    Expression<String>? occasionTags,
    Expression<DateTime>? pingDate,
    Expression<String>? pingNote,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (company != null) 'company': company,
      if (waNumber != null) 'wa_number': waNumber,
      if (wechatId != null) 'wechat_id': wechatId,
      if (preferredChannel != null) 'preferred_channel': preferredChannel,
      if (metWhere != null) 'met_where': metWhere,
      if (metWhen != null) 'met_when': metWhen,
      if (notes != null) 'notes': notes,
      if (occasionTags != null) 'occasion_tags': occasionTags,
      if (pingDate != null) 'ping_date': pingDate,
      if (pingNote != null) 'ping_note': pingNote,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PeopleCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? company,
    Value<String?>? waNumber,
    Value<String?>? wechatId,
    Value<String>? preferredChannel,
    Value<String?>? metWhere,
    Value<DateTime?>? metWhen,
    Value<String?>? notes,
    Value<List<String>>? occasionTags,
    Value<DateTime?>? pingDate,
    Value<String?>? pingNote,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PeopleCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      waNumber: waNumber ?? this.waNumber,
      wechatId: wechatId ?? this.wechatId,
      preferredChannel: preferredChannel ?? this.preferredChannel,
      metWhere: metWhere ?? this.metWhere,
      metWhen: metWhen ?? this.metWhen,
      notes: notes ?? this.notes,
      occasionTags: occasionTags ?? this.occasionTags,
      pingDate: pingDate ?? this.pingDate,
      pingNote: pingNote ?? this.pingNote,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (waNumber.present) {
      map['wa_number'] = Variable<String>(waNumber.value);
    }
    if (wechatId.present) {
      map['wechat_id'] = Variable<String>(wechatId.value);
    }
    if (preferredChannel.present) {
      map['preferred_channel'] = Variable<String>(preferredChannel.value);
    }
    if (metWhere.present) {
      map['met_where'] = Variable<String>(metWhere.value);
    }
    if (metWhen.present) {
      map['met_when'] = Variable<DateTime>(metWhen.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (occasionTags.present) {
      map['occasion_tags'] = Variable<String>(
        $PeopleTable.$converteroccasionTags.toSql(occasionTags.value),
      );
    }
    if (pingDate.present) {
      map['ping_date'] = Variable<DateTime>(pingDate.value);
    }
    if (pingNote.present) {
      map['ping_note'] = Variable<String>(pingNote.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('company: $company, ')
          ..write('waNumber: $waNumber, ')
          ..write('wechatId: $wechatId, ')
          ..write('preferredChannel: $preferredChannel, ')
          ..write('metWhere: $metWhere, ')
          ..write('metWhen: $metWhen, ')
          ..write('notes: $notes, ')
          ..write('occasionTags: $occasionTags, ')
          ..write('pingDate: $pingDate, ')
          ..write('pingNote: $pingNote, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PeopleTable people = $PeopleTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [people];
}

typedef $$PeopleTableCreateCompanionBuilder =
    PeopleCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> company,
      Value<String?> waNumber,
      Value<String?> wechatId,
      Value<String> preferredChannel,
      Value<String?> metWhere,
      Value<DateTime?> metWhen,
      Value<String?> notes,
      Value<List<String>> occasionTags,
      Value<DateTime?> pingDate,
      Value<String?> pingNote,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PeopleTableUpdateCompanionBuilder =
    PeopleCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> company,
      Value<String?> waNumber,
      Value<String?> wechatId,
      Value<String> preferredChannel,
      Value<String?> metWhere,
      Value<DateTime?> metWhen,
      Value<String?> notes,
      Value<List<String>> occasionTags,
      Value<DateTime?> pingDate,
      Value<String?> pingNote,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
    });

class $$PeopleTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waNumber => $composableBuilder(
    column: $table.waNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wechatId => $composableBuilder(
    column: $table.wechatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredChannel => $composableBuilder(
    column: $table.preferredChannel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metWhere => $composableBuilder(
    column: $table.metWhere,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get metWhen => $composableBuilder(
    column: $table.metWhen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get occasionTags => $composableBuilder(
    column: $table.occasionTags,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get pingDate => $composableBuilder(
    column: $table.pingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pingNote => $composableBuilder(
    column: $table.pingNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waNumber => $composableBuilder(
    column: $table.waNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wechatId => $composableBuilder(
    column: $table.wechatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredChannel => $composableBuilder(
    column: $table.preferredChannel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metWhere => $composableBuilder(
    column: $table.metWhere,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get metWhen => $composableBuilder(
    column: $table.metWhen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occasionTags => $composableBuilder(
    column: $table.occasionTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pingDate => $composableBuilder(
    column: $table.pingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pingNote => $composableBuilder(
    column: $table.pingNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get waNumber =>
      $composableBuilder(column: $table.waNumber, builder: (column) => column);

  GeneratedColumn<String> get wechatId =>
      $composableBuilder(column: $table.wechatId, builder: (column) => column);

  GeneratedColumn<String> get preferredChannel => $composableBuilder(
    column: $table.preferredChannel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metWhere =>
      $composableBuilder(column: $table.metWhere, builder: (column) => column);

  GeneratedColumn<DateTime> get metWhen =>
      $composableBuilder(column: $table.metWhen, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get occasionTags =>
      $composableBuilder(
        column: $table.occasionTags,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get pingDate =>
      $composableBuilder(column: $table.pingDate, builder: (column) => column);

  GeneratedColumn<String> get pingNote =>
      $composableBuilder(column: $table.pingNote, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleTable,
          Person,
          $$PeopleTableFilterComposer,
          $$PeopleTableOrderingComposer,
          $$PeopleTableAnnotationComposer,
          $$PeopleTableCreateCompanionBuilder,
          $$PeopleTableUpdateCompanionBuilder,
          (Person, BaseReferences<_$AppDatabase, $PeopleTable, Person>),
          Person,
          PrefetchHooks Function()
        > {
  $$PeopleTableTableManager(_$AppDatabase db, $PeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> company = const Value.absent(),
                Value<String?> waNumber = const Value.absent(),
                Value<String?> wechatId = const Value.absent(),
                Value<String> preferredChannel = const Value.absent(),
                Value<String?> metWhere = const Value.absent(),
                Value<DateTime?> metWhen = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<List<String>> occasionTags = const Value.absent(),
                Value<DateTime?> pingDate = const Value.absent(),
                Value<String?> pingNote = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PeopleCompanion(
                id: id,
                name: name,
                company: company,
                waNumber: waNumber,
                wechatId: wechatId,
                preferredChannel: preferredChannel,
                metWhere: metWhere,
                metWhen: metWhen,
                notes: notes,
                occasionTags: occasionTags,
                pingDate: pingDate,
                pingNote: pingNote,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> company = const Value.absent(),
                Value<String?> waNumber = const Value.absent(),
                Value<String?> wechatId = const Value.absent(),
                Value<String> preferredChannel = const Value.absent(),
                Value<String?> metWhere = const Value.absent(),
                Value<DateTime?> metWhen = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<List<String>> occasionTags = const Value.absent(),
                Value<DateTime?> pingDate = const Value.absent(),
                Value<String?> pingNote = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PeopleCompanion.insert(
                id: id,
                name: name,
                company: company,
                waNumber: waNumber,
                wechatId: wechatId,
                preferredChannel: preferredChannel,
                metWhere: metWhere,
                metWhen: metWhen,
                notes: notes,
                occasionTags: occasionTags,
                pingDate: pingDate,
                pingNote: pingNote,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleTable,
      Person,
      $$PeopleTableFilterComposer,
      $$PeopleTableOrderingComposer,
      $$PeopleTableAnnotationComposer,
      $$PeopleTableCreateCompanionBuilder,
      $$PeopleTableUpdateCompanionBuilder,
      (Person, BaseReferences<_$AppDatabase, $PeopleTable, Person>),
      Person,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
}
