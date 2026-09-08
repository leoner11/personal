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
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
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
        DriftSqlType.string,
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
  final String id;
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
    map['id'] = Variable<String>(id);
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
      id: serializer.fromJson<String>(json['id']),
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
      'id': serializer.toJson<String>(id),
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
    String? id,
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
  final Value<String> id;
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
  final Value<int> rowid;
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
    this.rowid = const Value.absent(),
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
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Person> custom({
    Expression<String>? id,
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
    Expression<int>? rowid,
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
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeopleCompanion copyWith({
    Value<String>? id,
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
    Value<int>? rowid,
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
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
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
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OccasionsTable extends Occasions
    with TableInfo<$OccasionsTable, Occasion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OccasionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
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
    date,
    tag,
    country,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'occasions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Occasion> instance, {
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
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
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
  Occasion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Occasion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
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
  $OccasionsTable createAlias(String alias) {
    return $OccasionsTable(attachedDatabase, alias);
  }
}

class Occasion extends DataClass implements Insertable<Occasion> {
  final String id;
  final String name;
  final DateTime date;

  /// OccasionTag.name — links a date to the people carrying that tag.
  final String tag;
  final String? country;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Occasion({
    required this.id,
    required this.name,
    required this.date,
    required this.tag,
    this.country,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['date'] = Variable<DateTime>(date);
    map['tag'] = Variable<String>(tag);
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  OccasionsCompanion toCompanion(bool nullToAbsent) {
    return OccasionsCompanion(
      id: Value(id),
      name: Value(name),
      date: Value(date),
      tag: Value(tag),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Occasion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Occasion(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      date: serializer.fromJson<DateTime>(json['date']),
      tag: serializer.fromJson<String>(json['tag']),
      country: serializer.fromJson<String?>(json['country']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'date': serializer.toJson<DateTime>(date),
      'tag': serializer.toJson<String>(tag),
      'country': serializer.toJson<String?>(country),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Occasion copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? tag,
    Value<String?> country = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Occasion(
    id: id ?? this.id,
    name: name ?? this.name,
    date: date ?? this.date,
    tag: tag ?? this.tag,
    country: country.present ? country.value : this.country,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Occasion copyWithCompanion(OccasionsCompanion data) {
    return Occasion(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      date: data.date.present ? data.date.value : this.date,
      tag: data.tag.present ? data.tag.value : this.tag,
      country: data.country.present ? data.country.value : this.country,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Occasion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('date: $date, ')
          ..write('tag: $tag, ')
          ..write('country: $country, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, date, tag, country, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Occasion &&
          other.id == this.id &&
          other.name == this.name &&
          other.date == this.date &&
          other.tag == this.tag &&
          other.country == this.country &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class OccasionsCompanion extends UpdateCompanion<Occasion> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> date;
  final Value<String> tag;
  final Value<String?> country;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const OccasionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.date = const Value.absent(),
    this.tag = const Value.absent(),
    this.country = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OccasionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime date,
    required String tag,
    this.country = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       date = Value(date),
       tag = Value(tag);
  static Insertable<Occasion> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? date,
    Expression<String>? tag,
    Expression<String>? country,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (date != null) 'date': date,
      if (tag != null) 'tag': tag,
      if (country != null) 'country': country,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OccasionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? date,
    Value<String>? tag,
    Value<String?>? country,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return OccasionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      tag: tag ?? this.tag,
      country: country ?? this.country,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OccasionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('date: $date, ')
          ..write('tag: $tag, ')
          ..write('country: $country, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EngagementsTable extends Engagements
    with TableInfo<$EngagementsTable, Engagement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EngagementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('deal'),
  );
  static const VerificationMeta _counterpartyIdMeta = const VerificationMeta(
    'counterpartyId',
  );
  @override
  late final GeneratedColumn<String> counterpartyId = GeneratedColumn<String>(
    'counterparty_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMinorMeta = const VerificationMeta(
    'valueMinor',
  );
  @override
  late final GeneratedColumn<int> valueMinor = GeneratedColumn<int>(
    'value_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    type,
    counterpartyId,
    status,
    valueMinor,
    currency,
    notes,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'engagements';
  @override
  VerificationContext validateIntegrity(
    Insertable<Engagement> instance, {
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
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('counterparty_id')) {
      context.handle(
        _counterpartyIdMeta,
        counterpartyId.isAcceptableOrUnknown(
          data['counterparty_id']!,
          _counterpartyIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('value_minor')) {
      context.handle(
        _valueMinorMeta,
        valueMinor.isAcceptableOrUnknown(data['value_minor']!, _valueMinorMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Engagement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Engagement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      counterpartyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      valueMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value_minor'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
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
  $EngagementsTable createAlias(String alias) {
    return $EngagementsTable(attachedDatabase, alias);
  }
}

class Engagement extends DataClass implements Insertable<Engagement> {
  final String id;
  final String name;

  /// deal | jv | client | lead
  final String type;
  final String? counterpartyId;

  /// ⚠ FREE TEXT ON PURPOSE. The moment this becomes a dropdown of stages,
  /// this is a sales tool and scope has escaped.
  final String? status;
  final int? valueMinor;
  final String? currency;
  final String? notes;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Engagement({
    required this.id,
    required this.name,
    required this.type,
    this.counterpartyId,
    this.status,
    this.valueMinor,
    this.currency,
    this.notes,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || counterpartyId != null) {
      map['counterparty_id'] = Variable<String>(counterpartyId);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || valueMinor != null) {
      map['value_minor'] = Variable<int>(valueMinor);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EngagementsCompanion toCompanion(bool nullToAbsent) {
    return EngagementsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      counterpartyId: counterpartyId == null && nullToAbsent
          ? const Value.absent()
          : Value(counterpartyId),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      valueMinor: valueMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(valueMinor),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Engagement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Engagement(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      counterpartyId: serializer.fromJson<String?>(json['counterpartyId']),
      status: serializer.fromJson<String?>(json['status']),
      valueMinor: serializer.fromJson<int?>(json['valueMinor']),
      currency: serializer.fromJson<String?>(json['currency']),
      notes: serializer.fromJson<String?>(json['notes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'counterpartyId': serializer.toJson<String?>(counterpartyId),
      'status': serializer.toJson<String?>(status),
      'valueMinor': serializer.toJson<int?>(valueMinor),
      'currency': serializer.toJson<String?>(currency),
      'notes': serializer.toJson<String?>(notes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Engagement copyWith({
    String? id,
    String? name,
    String? type,
    Value<String?> counterpartyId = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<int?> valueMinor = const Value.absent(),
    Value<String?> currency = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Engagement(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    counterpartyId: counterpartyId.present
        ? counterpartyId.value
        : this.counterpartyId,
    status: status.present ? status.value : this.status,
    valueMinor: valueMinor.present ? valueMinor.value : this.valueMinor,
    currency: currency.present ? currency.value : this.currency,
    notes: notes.present ? notes.value : this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Engagement copyWithCompanion(EngagementsCompanion data) {
    return Engagement(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      counterpartyId: data.counterpartyId.present
          ? data.counterpartyId.value
          : this.counterpartyId,
      status: data.status.present ? data.status.value : this.status,
      valueMinor: data.valueMinor.present
          ? data.valueMinor.value
          : this.valueMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Engagement(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('counterpartyId: $counterpartyId, ')
          ..write('status: $status, ')
          ..write('valueMinor: $valueMinor, ')
          ..write('currency: $currency, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    counterpartyId,
    status,
    valueMinor,
    currency,
    notes,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Engagement &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.counterpartyId == this.counterpartyId &&
          other.status == this.status &&
          other.valueMinor == this.valueMinor &&
          other.currency == this.currency &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EngagementsCompanion extends UpdateCompanion<Engagement> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> counterpartyId;
  final Value<String?> status;
  final Value<int?> valueMinor;
  final Value<String?> currency;
  final Value<String?> notes;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EngagementsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.counterpartyId = const Value.absent(),
    this.status = const Value.absent(),
    this.valueMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EngagementsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.type = const Value.absent(),
    this.counterpartyId = const Value.absent(),
    this.status = const Value.absent(),
    this.valueMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Engagement> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? counterpartyId,
    Expression<String>? status,
    Expression<int>? valueMinor,
    Expression<String>? currency,
    Expression<String>? notes,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (counterpartyId != null) 'counterparty_id': counterpartyId,
      if (status != null) 'status': status,
      if (valueMinor != null) 'value_minor': valueMinor,
      if (currency != null) 'currency': currency,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EngagementsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? counterpartyId,
    Value<String?>? status,
    Value<int?>? valueMinor,
    Value<String?>? currency,
    Value<String?>? notes,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EngagementsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      counterpartyId: counterpartyId ?? this.counterpartyId,
      status: status ?? this.status,
      valueMinor: valueMinor ?? this.valueMinor,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (counterpartyId.present) {
      map['counterparty_id'] = Variable<String>(counterpartyId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (valueMinor.present) {
      map['value_minor'] = Variable<int>(valueMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EngagementsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('counterpartyId: $counterpartyId, ')
          ..write('status: $status, ')
          ..write('valueMinor: $valueMinor, ')
          ..write('currency: $currency, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoneyTable extends Money with TableInfo<$MoneyTable, MoneyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoneyTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CNY'),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('expected'),
  );
  static const VerificationMeta _engagementIdMeta = const VerificationMeta(
    'engagementId',
  );
  @override
  late final GeneratedColumn<String> engagementId = GeneratedColumn<String>(
    'engagement_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occasionTagMeta = const VerificationMeta(
    'occasionTag',
  );
  @override
  late final GeneratedColumn<String> occasionTag = GeneratedColumn<String>(
    'occasion_tag',
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
    date,
    direction,
    amountMinor,
    currency,
    label,
    status,
    engagementId,
    personId,
    occasionTag,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'money';
  @override
  VerificationContext validateIntegrity(
    Insertable<MoneyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('engagement_id')) {
      context.handle(
        _engagementIdMeta,
        engagementId.isAcceptableOrUnknown(
          data['engagement_id']!,
          _engagementIdMeta,
        ),
      );
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('occasion_tag')) {
      context.handle(
        _occasionTagMeta,
        occasionTag.isAcceptableOrUnknown(
          data['occasion_tag']!,
          _occasionTagMeta,
        ),
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
  MoneyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoneyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      engagementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engagement_id'],
      ),
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      ),
      occasionTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occasion_tag'],
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
  $MoneyTable createAlias(String alias) {
    return $MoneyTable(attachedDatabase, alias);
  }
}

class MoneyRow extends DataClass implements Insertable<MoneyRow> {
  final String id;
  final DateTime date;

  /// in | out
  final String direction;

  /// Minor units (cents). Integers, never floats — see kDecimals.
  final int amountMinor;
  final String currency;
  final String label;

  /// expected | actual
  final String status;
  final String? engagementId;
  final String? personId;

  /// Set when the row was created by a gift commit, so close-out can find it.
  final String? occasionTag;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const MoneyRow({
    required this.id,
    required this.date,
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.label,
    required this.status,
    this.engagementId,
    this.personId,
    this.occasionTag,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<DateTime>(date);
    map['direction'] = Variable<String>(direction);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['label'] = Variable<String>(label);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || engagementId != null) {
      map['engagement_id'] = Variable<String>(engagementId);
    }
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<String>(personId);
    }
    if (!nullToAbsent || occasionTag != null) {
      map['occasion_tag'] = Variable<String>(occasionTag);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  MoneyCompanion toCompanion(bool nullToAbsent) {
    return MoneyCompanion(
      id: Value(id),
      date: Value(date),
      direction: Value(direction),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      label: Value(label),
      status: Value(status),
      engagementId: engagementId == null && nullToAbsent
          ? const Value.absent()
          : Value(engagementId),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      occasionTag: occasionTag == null && nullToAbsent
          ? const Value.absent()
          : Value(occasionTag),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MoneyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoneyRow(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      direction: serializer.fromJson<String>(json['direction']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      label: serializer.fromJson<String>(json['label']),
      status: serializer.fromJson<String>(json['status']),
      engagementId: serializer.fromJson<String?>(json['engagementId']),
      personId: serializer.fromJson<String?>(json['personId']),
      occasionTag: serializer.fromJson<String?>(json['occasionTag']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<DateTime>(date),
      'direction': serializer.toJson<String>(direction),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'label': serializer.toJson<String>(label),
      'status': serializer.toJson<String>(status),
      'engagementId': serializer.toJson<String?>(engagementId),
      'personId': serializer.toJson<String?>(personId),
      'occasionTag': serializer.toJson<String?>(occasionTag),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  MoneyRow copyWith({
    String? id,
    DateTime? date,
    String? direction,
    int? amountMinor,
    String? currency,
    String? label,
    String? status,
    Value<String?> engagementId = const Value.absent(),
    Value<String?> personId = const Value.absent(),
    Value<String?> occasionTag = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => MoneyRow(
    id: id ?? this.id,
    date: date ?? this.date,
    direction: direction ?? this.direction,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    label: label ?? this.label,
    status: status ?? this.status,
    engagementId: engagementId.present ? engagementId.value : this.engagementId,
    personId: personId.present ? personId.value : this.personId,
    occasionTag: occasionTag.present ? occasionTag.value : this.occasionTag,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  MoneyRow copyWithCompanion(MoneyCompanion data) {
    return MoneyRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      direction: data.direction.present ? data.direction.value : this.direction,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      label: data.label.present ? data.label.value : this.label,
      status: data.status.present ? data.status.value : this.status,
      engagementId: data.engagementId.present
          ? data.engagementId.value
          : this.engagementId,
      personId: data.personId.present ? data.personId.value : this.personId,
      occasionTag: data.occasionTag.present
          ? data.occasionTag.value
          : this.occasionTag,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoneyRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('direction: $direction, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('label: $label, ')
          ..write('status: $status, ')
          ..write('engagementId: $engagementId, ')
          ..write('personId: $personId, ')
          ..write('occasionTag: $occasionTag, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    direction,
    amountMinor,
    currency,
    label,
    status,
    engagementId,
    personId,
    occasionTag,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoneyRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.direction == this.direction &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.label == this.label &&
          other.status == this.status &&
          other.engagementId == this.engagementId &&
          other.personId == this.personId &&
          other.occasionTag == this.occasionTag &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MoneyCompanion extends UpdateCompanion<MoneyRow> {
  final Value<String> id;
  final Value<DateTime> date;
  final Value<String> direction;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String> label;
  final Value<String> status;
  final Value<String?> engagementId;
  final Value<String?> personId;
  final Value<String?> occasionTag;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const MoneyCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.direction = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.label = const Value.absent(),
    this.status = const Value.absent(),
    this.engagementId = const Value.absent(),
    this.personId = const Value.absent(),
    this.occasionTag = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoneyCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String direction,
    required int amountMinor,
    this.currency = const Value.absent(),
    required String label,
    this.status = const Value.absent(),
    this.engagementId = const Value.absent(),
    this.personId = const Value.absent(),
    this.occasionTag = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       direction = Value(direction),
       amountMinor = Value(amountMinor),
       label = Value(label);
  static Insertable<MoneyRow> custom({
    Expression<String>? id,
    Expression<DateTime>? date,
    Expression<String>? direction,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? label,
    Expression<String>? status,
    Expression<String>? engagementId,
    Expression<String>? personId,
    Expression<String>? occasionTag,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (direction != null) 'direction': direction,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (label != null) 'label': label,
      if (status != null) 'status': status,
      if (engagementId != null) 'engagement_id': engagementId,
      if (personId != null) 'person_id': personId,
      if (occasionTag != null) 'occasion_tag': occasionTag,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoneyCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? date,
    Value<String>? direction,
    Value<int>? amountMinor,
    Value<String>? currency,
    Value<String>? label,
    Value<String>? status,
    Value<String?>? engagementId,
    Value<String?>? personId,
    Value<String?>? occasionTag,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return MoneyCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      direction: direction ?? this.direction,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      label: label ?? this.label,
      status: status ?? this.status,
      engagementId: engagementId ?? this.engagementId,
      personId: personId ?? this.personId,
      occasionTag: occasionTag ?? this.occasionTag,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (engagementId.present) {
      map['engagement_id'] = Variable<String>(engagementId.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (occasionTag.present) {
      map['occasion_tag'] = Variable<String>(occasionTag.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoneyCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('direction: $direction, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('label: $label, ')
          ..write('status: $status, ')
          ..write('engagementId: $engagementId, ')
          ..write('personId: $personId, ')
          ..write('occasionTag: $occasionTag, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _engagementIdMeta = const VerificationMeta(
    'engagementId',
  );
  @override
  late final GeneratedColumn<String> engagementId = GeneratedColumn<String>(
    'engagement_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
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
    date,
    body,
    personId,
    engagementId,
    tag,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('engagement_id')) {
      context.handle(
        _engagementIdMeta,
        engagementId.isAcceptableOrUnknown(
          data['engagement_id']!,
          _engagementIdMeta,
        ),
      );
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
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
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      ),
      engagementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engagement_id'],
      ),
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
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
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final DateTime date;

  /// ⚠ Named `body` in Dart: a column getter called `text` collides with
  /// drift's own Table.text() builder and codegen silently emits nothing.
  final String body;
  final String? personId;
  final String? engagementId;
  final String? tag;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Note({
    required this.id,
    required this.date,
    required this.body,
    this.personId,
    this.engagementId,
    this.tag,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<DateTime>(date);
    map['text'] = Variable<String>(body);
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<String>(personId);
    }
    if (!nullToAbsent || engagementId != null) {
      map['engagement_id'] = Variable<String>(engagementId);
    }
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<String>(tag);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      date: Value(date),
      body: Value(body),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      engagementId: engagementId == null && nullToAbsent
          ? const Value.absent()
          : Value(engagementId),
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      body: serializer.fromJson<String>(json['body']),
      personId: serializer.fromJson<String?>(json['personId']),
      engagementId: serializer.fromJson<String?>(json['engagementId']),
      tag: serializer.fromJson<String?>(json['tag']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<DateTime>(date),
      'body': serializer.toJson<String>(body),
      'personId': serializer.toJson<String?>(personId),
      'engagementId': serializer.toJson<String?>(engagementId),
      'tag': serializer.toJson<String?>(tag),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Note copyWith({
    String? id,
    DateTime? date,
    String? body,
    Value<String?> personId = const Value.absent(),
    Value<String?> engagementId = const Value.absent(),
    Value<String?> tag = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Note(
    id: id ?? this.id,
    date: date ?? this.date,
    body: body ?? this.body,
    personId: personId.present ? personId.value : this.personId,
    engagementId: engagementId.present ? engagementId.value : this.engagementId,
    tag: tag.present ? tag.value : this.tag,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      body: data.body.present ? data.body.value : this.body,
      personId: data.personId.present ? data.personId.value : this.personId,
      engagementId: data.engagementId.present
          ? data.engagementId.value
          : this.engagementId,
      tag: data.tag.present ? data.tag.value : this.tag,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('body: $body, ')
          ..write('personId: $personId, ')
          ..write('engagementId: $engagementId, ')
          ..write('tag: $tag, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    body,
    personId,
    engagementId,
    tag,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.date == this.date &&
          other.body == this.body &&
          other.personId == this.personId &&
          other.engagementId == this.engagementId &&
          other.tag == this.tag &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<DateTime> date;
  final Value<String> body;
  final Value<String?> personId;
  final Value<String?> engagementId;
  final Value<String?> tag;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.body = const Value.absent(),
    this.personId = const Value.absent(),
    this.engagementId = const Value.absent(),
    this.tag = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    this.body = const Value.absent(),
    this.personId = const Value.absent(),
    this.engagementId = const Value.absent(),
    this.tag = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<DateTime>? date,
    Expression<String>? body,
    Expression<String>? personId,
    Expression<String>? engagementId,
    Expression<String>? tag,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (body != null) 'text': body,
      if (personId != null) 'person_id': personId,
      if (engagementId != null) 'engagement_id': engagementId,
      if (tag != null) 'tag': tag,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? date,
    Value<String>? body,
    Value<String?>? personId,
    Value<String?>? engagementId,
    Value<String?>? tag,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      body: body ?? this.body,
      personId: personId ?? this.personId,
      engagementId: engagementId ?? this.engagementId,
      tag: tag ?? this.tag,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (engagementId.present) {
      map['engagement_id'] = Variable<String>(engagementId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('body: $body, ')
          ..write('personId: $personId, ')
          ..write('engagementId: $engagementId, ')
          ..write('tag: $tag, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TouchesTable extends Touches with TableInfo<$TouchesTable, Touch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TouchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oneLineMeta = const VerificationMeta(
    'oneLine',
  );
  @override
  late final GeneratedColumn<String> oneLine = GeneratedColumn<String>(
    'one_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    personId,
    date,
    oneLine,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'touches';
  @override
  VerificationContext validateIntegrity(
    Insertable<Touch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('one_line')) {
      context.handle(
        _oneLineMeta,
        oneLine.isAcceptableOrUnknown(data['one_line']!, _oneLineMeta),
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
  Touch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Touch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      oneLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}one_line'],
      )!,
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
  $TouchesTable createAlias(String alias) {
    return $TouchesTable(attachedDatabase, alias);
  }
}

class Touch extends DataClass implements Insertable<Touch> {
  final String id;
  final String personId;
  final DateTime date;
  final String oneLine;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Touch({
    required this.id,
    required this.personId,
    required this.date,
    required this.oneLine,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person_id'] = Variable<String>(personId);
    map['date'] = Variable<DateTime>(date);
    map['one_line'] = Variable<String>(oneLine);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TouchesCompanion toCompanion(bool nullToAbsent) {
    return TouchesCompanion(
      id: Value(id),
      personId: Value(personId),
      date: Value(date),
      oneLine: Value(oneLine),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Touch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Touch(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String>(json['personId']),
      date: serializer.fromJson<DateTime>(json['date']),
      oneLine: serializer.fromJson<String>(json['oneLine']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String>(personId),
      'date': serializer.toJson<DateTime>(date),
      'oneLine': serializer.toJson<String>(oneLine),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Touch copyWith({
    String? id,
    String? personId,
    DateTime? date,
    String? oneLine,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Touch(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    date: date ?? this.date,
    oneLine: oneLine ?? this.oneLine,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Touch copyWithCompanion(TouchesCompanion data) {
    return Touch(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      date: data.date.present ? data.date.value : this.date,
      oneLine: data.oneLine.present ? data.oneLine.value : this.oneLine,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Touch(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('date: $date, ')
          ..write('oneLine: $oneLine, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, personId, date, oneLine, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Touch &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.date == this.date &&
          other.oneLine == this.oneLine &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TouchesCompanion extends UpdateCompanion<Touch> {
  final Value<String> id;
  final Value<String> personId;
  final Value<DateTime> date;
  final Value<String> oneLine;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TouchesCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.date = const Value.absent(),
    this.oneLine = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TouchesCompanion.insert({
    this.id = const Value.absent(),
    required String personId,
    required DateTime date,
    this.oneLine = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : personId = Value(personId),
       date = Value(date);
  static Insertable<Touch> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<DateTime>? date,
    Expression<String>? oneLine,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (date != null) 'date': date,
      if (oneLine != null) 'one_line': oneLine,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TouchesCompanion copyWith({
    Value<String>? id,
    Value<String>? personId,
    Value<DateTime>? date,
    Value<String>? oneLine,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TouchesCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      date: date ?? this.date,
      oneLine: oneLine ?? this.oneLine,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (oneLine.present) {
      map['one_line'] = Variable<String>(oneLine.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TouchesCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('date: $date, ')
          ..write('oneLine: $oneLine, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PeopleTable people = $PeopleTable(this);
  late final $OccasionsTable occasions = $OccasionsTable(this);
  late final $EngagementsTable engagements = $EngagementsTable(this);
  late final $MoneyTable money = $MoneyTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $TouchesTable touches = $TouchesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    people,
    occasions,
    engagements,
    money,
    notes,
    touches,
  ];
}

typedef $$PeopleTableCreateCompanionBuilder =
    PeopleCompanion Function({
      Value<String> id,
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
      Value<int> rowid,
    });
typedef $$PeopleTableUpdateCompanionBuilder =
    PeopleCompanion Function({
      Value<String> id,
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
      Value<int> rowid,
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
  ColumnFilters<String> get id => $composableBuilder(
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
  ColumnOrderings<String> get id => $composableBuilder(
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
  GeneratedColumn<String> get id =>
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
                Value<String> id = const Value.absent(),
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
                Value<int> rowid = const Value.absent(),
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
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
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
                Value<int> rowid = const Value.absent(),
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
                rowid: rowid,
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
typedef $$OccasionsTableCreateCompanionBuilder =
    OccasionsCompanion Function({
      Value<String> id,
      required String name,
      required DateTime date,
      required String tag,
      Value<String?> country,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$OccasionsTableUpdateCompanionBuilder =
    OccasionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> date,
      Value<String> tag,
      Value<String?> country,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$OccasionsTableFilterComposer
    extends Composer<_$AppDatabase, $OccasionsTable> {
  $$OccasionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
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

class $$OccasionsTableOrderingComposer
    extends Composer<_$AppDatabase, $OccasionsTable> {
  $$OccasionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
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

class $$OccasionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OccasionsTable> {
  $$OccasionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$OccasionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OccasionsTable,
          Occasion,
          $$OccasionsTableFilterComposer,
          $$OccasionsTableOrderingComposer,
          $$OccasionsTableAnnotationComposer,
          $$OccasionsTableCreateCompanionBuilder,
          $$OccasionsTableUpdateCompanionBuilder,
          (Occasion, BaseReferences<_$AppDatabase, $OccasionsTable, Occasion>),
          Occasion,
          PrefetchHooks Function()
        > {
  $$OccasionsTableTableManager(_$AppDatabase db, $OccasionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OccasionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OccasionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OccasionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OccasionsCompanion(
                id: id,
                name: name,
                date: date,
                tag: tag,
                country: country,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                required DateTime date,
                required String tag,
                Value<String?> country = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OccasionsCompanion.insert(
                id: id,
                name: name,
                date: date,
                tag: tag,
                country: country,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OccasionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OccasionsTable,
      Occasion,
      $$OccasionsTableFilterComposer,
      $$OccasionsTableOrderingComposer,
      $$OccasionsTableAnnotationComposer,
      $$OccasionsTableCreateCompanionBuilder,
      $$OccasionsTableUpdateCompanionBuilder,
      (Occasion, BaseReferences<_$AppDatabase, $OccasionsTable, Occasion>),
      Occasion,
      PrefetchHooks Function()
    >;
typedef $$EngagementsTableCreateCompanionBuilder =
    EngagementsCompanion Function({
      Value<String> id,
      required String name,
      Value<String> type,
      Value<String?> counterpartyId,
      Value<String?> status,
      Value<int?> valueMinor,
      Value<String?> currency,
      Value<String?> notes,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$EngagementsTableUpdateCompanionBuilder =
    EngagementsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String?> counterpartyId,
      Value<String?> status,
      Value<int?> valueMinor,
      Value<String?> currency,
      Value<String?> notes,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$EngagementsTableFilterComposer
    extends Composer<_$AppDatabase, $EngagementsTable> {
  $$EngagementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterpartyId => $composableBuilder(
    column: $table.counterpartyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get valueMinor => $composableBuilder(
    column: $table.valueMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
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

class $$EngagementsTableOrderingComposer
    extends Composer<_$AppDatabase, $EngagementsTable> {
  $$EngagementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterpartyId => $composableBuilder(
    column: $table.counterpartyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get valueMinor => $composableBuilder(
    column: $table.valueMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
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

class $$EngagementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EngagementsTable> {
  $$EngagementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get counterpartyId => $composableBuilder(
    column: $table.counterpartyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get valueMinor => $composableBuilder(
    column: $table.valueMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$EngagementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EngagementsTable,
          Engagement,
          $$EngagementsTableFilterComposer,
          $$EngagementsTableOrderingComposer,
          $$EngagementsTableAnnotationComposer,
          $$EngagementsTableCreateCompanionBuilder,
          $$EngagementsTableUpdateCompanionBuilder,
          (
            Engagement,
            BaseReferences<_$AppDatabase, $EngagementsTable, Engagement>,
          ),
          Engagement,
          PrefetchHooks Function()
        > {
  $$EngagementsTableTableManager(_$AppDatabase db, $EngagementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EngagementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EngagementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EngagementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> counterpartyId = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> valueMinor = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EngagementsCompanion(
                id: id,
                name: name,
                type: type,
                counterpartyId: counterpartyId,
                status: status,
                valueMinor: valueMinor,
                currency: currency,
                notes: notes,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                Value<String> type = const Value.absent(),
                Value<String?> counterpartyId = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> valueMinor = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EngagementsCompanion.insert(
                id: id,
                name: name,
                type: type,
                counterpartyId: counterpartyId,
                status: status,
                valueMinor: valueMinor,
                currency: currency,
                notes: notes,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EngagementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EngagementsTable,
      Engagement,
      $$EngagementsTableFilterComposer,
      $$EngagementsTableOrderingComposer,
      $$EngagementsTableAnnotationComposer,
      $$EngagementsTableCreateCompanionBuilder,
      $$EngagementsTableUpdateCompanionBuilder,
      (
        Engagement,
        BaseReferences<_$AppDatabase, $EngagementsTable, Engagement>,
      ),
      Engagement,
      PrefetchHooks Function()
    >;
typedef $$MoneyTableCreateCompanionBuilder =
    MoneyCompanion Function({
      Value<String> id,
      required DateTime date,
      required String direction,
      required int amountMinor,
      Value<String> currency,
      required String label,
      Value<String> status,
      Value<String?> engagementId,
      Value<String?> personId,
      Value<String?> occasionTag,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$MoneyTableUpdateCompanionBuilder =
    MoneyCompanion Function({
      Value<String> id,
      Value<DateTime> date,
      Value<String> direction,
      Value<int> amountMinor,
      Value<String> currency,
      Value<String> label,
      Value<String> status,
      Value<String?> engagementId,
      Value<String?> personId,
      Value<String?> occasionTag,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$MoneyTableFilterComposer extends Composer<_$AppDatabase, $MoneyTable> {
  $$MoneyTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engagementId => $composableBuilder(
    column: $table.engagementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occasionTag => $composableBuilder(
    column: $table.occasionTag,
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

class $$MoneyTableOrderingComposer
    extends Composer<_$AppDatabase, $MoneyTable> {
  $$MoneyTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engagementId => $composableBuilder(
    column: $table.engagementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occasionTag => $composableBuilder(
    column: $table.occasionTag,
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

class $$MoneyTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoneyTable> {
  $$MoneyTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get engagementId => $composableBuilder(
    column: $table.engagementId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<String> get occasionTag => $composableBuilder(
    column: $table.occasionTag,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$MoneyTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MoneyTable,
          MoneyRow,
          $$MoneyTableFilterComposer,
          $$MoneyTableOrderingComposer,
          $$MoneyTableAnnotationComposer,
          $$MoneyTableCreateCompanionBuilder,
          $$MoneyTableUpdateCompanionBuilder,
          (MoneyRow, BaseReferences<_$AppDatabase, $MoneyTable, MoneyRow>),
          MoneyRow,
          PrefetchHooks Function()
        > {
  $$MoneyTableTableManager(_$AppDatabase db, $MoneyTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoneyTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoneyTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoneyTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> engagementId = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<String?> occasionTag = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoneyCompanion(
                id: id,
                date: date,
                direction: direction,
                amountMinor: amountMinor,
                currency: currency,
                label: label,
                status: status,
                engagementId: engagementId,
                personId: personId,
                occasionTag: occasionTag,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required DateTime date,
                required String direction,
                required int amountMinor,
                Value<String> currency = const Value.absent(),
                required String label,
                Value<String> status = const Value.absent(),
                Value<String?> engagementId = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<String?> occasionTag = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoneyCompanion.insert(
                id: id,
                date: date,
                direction: direction,
                amountMinor: amountMinor,
                currency: currency,
                label: label,
                status: status,
                engagementId: engagementId,
                personId: personId,
                occasionTag: occasionTag,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MoneyTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MoneyTable,
      MoneyRow,
      $$MoneyTableFilterComposer,
      $$MoneyTableOrderingComposer,
      $$MoneyTableAnnotationComposer,
      $$MoneyTableCreateCompanionBuilder,
      $$MoneyTableUpdateCompanionBuilder,
      (MoneyRow, BaseReferences<_$AppDatabase, $MoneyTable, MoneyRow>),
      MoneyRow,
      PrefetchHooks Function()
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      required DateTime date,
      Value<String> body,
      Value<String?> personId,
      Value<String?> engagementId,
      Value<String?> tag,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<DateTime> date,
      Value<String> body,
      Value<String?> personId,
      Value<String?> engagementId,
      Value<String?> tag,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engagementId => $composableBuilder(
    column: $table.engagementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
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

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engagementId => $composableBuilder(
    column: $table.engagementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
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

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<String> get engagementId => $composableBuilder(
    column: $table.engagementId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<String?> engagementId = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                date: date,
                body: body,
                personId: personId,
                engagementId: engagementId,
                tag: tag,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required DateTime date,
                Value<String> body = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<String?> engagementId = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                date: date,
                body: body,
                personId: personId,
                engagementId: engagementId,
                tag: tag,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$TouchesTableCreateCompanionBuilder =
    TouchesCompanion Function({
      Value<String> id,
      required String personId,
      required DateTime date,
      Value<String> oneLine,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TouchesTableUpdateCompanionBuilder =
    TouchesCompanion Function({
      Value<String> id,
      Value<String> personId,
      Value<DateTime> date,
      Value<String> oneLine,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$TouchesTableFilterComposer
    extends Composer<_$AppDatabase, $TouchesTable> {
  $$TouchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oneLine => $composableBuilder(
    column: $table.oneLine,
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

class $$TouchesTableOrderingComposer
    extends Composer<_$AppDatabase, $TouchesTable> {
  $$TouchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oneLine => $composableBuilder(
    column: $table.oneLine,
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

class $$TouchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TouchesTable> {
  $$TouchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get oneLine =>
      $composableBuilder(column: $table.oneLine, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TouchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TouchesTable,
          Touch,
          $$TouchesTableFilterComposer,
          $$TouchesTableOrderingComposer,
          $$TouchesTableAnnotationComposer,
          $$TouchesTableCreateCompanionBuilder,
          $$TouchesTableUpdateCompanionBuilder,
          (Touch, BaseReferences<_$AppDatabase, $TouchesTable, Touch>),
          Touch,
          PrefetchHooks Function()
        > {
  $$TouchesTableTableManager(_$AppDatabase db, $TouchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TouchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TouchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TouchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> oneLine = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TouchesCompanion(
                id: id,
                personId: personId,
                date: date,
                oneLine: oneLine,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String personId,
                required DateTime date,
                Value<String> oneLine = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TouchesCompanion.insert(
                id: id,
                personId: personId,
                date: date,
                oneLine: oneLine,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TouchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TouchesTable,
      Touch,
      $$TouchesTableFilterComposer,
      $$TouchesTableOrderingComposer,
      $$TouchesTableAnnotationComposer,
      $$TouchesTableCreateCompanionBuilder,
      $$TouchesTableUpdateCompanionBuilder,
      (Touch, BaseReferences<_$AppDatabase, $TouchesTable, Touch>),
      Touch,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$OccasionsTableTableManager get occasions =>
      $$OccasionsTableTableManager(_db, _db.occasions);
  $$EngagementsTableTableManager get engagements =>
      $$EngagementsTableTableManager(_db, _db.engagements);
  $$MoneyTableTableManager get money =>
      $$MoneyTableTableManager(_db, _db.money);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$TouchesTableTableManager get touches =>
      $$TouchesTableTableManager(_db, _db.touches);
}
