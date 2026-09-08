import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Stores occasion tags as a comma-separated list of enum names.
/// Single user, small lists — a join table would be ceremony.
class TagListConverter extends TypeConverter<List<String>, String> {
  const TagListConverter();
  @override
  List<String> fromSql(String fromDb) =>
      fromDb.isEmpty ? const [] : fromDb.split(',');
  @override
  String toSql(List<String> value) => value.join(',');
}

/// D1 — People. Full schema from the flowchart, including the fields Phase 1
/// does not use yet. Adding the columns now costs nothing; a migration later
/// costs an evening.
@DataClassName('Person')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get company => text().nullable()();
  TextColumn get waNumber => text().nullable()();
  TextColumn get wechatId => text().nullable()();

  /// 'wa' | 'wechat'. Drives which action the row offers.
  TextColumn get preferredChannel => text().withDefault(const Constant('wa'))();

  TextColumn get metWhere => text().nullable()();
  DateTimeColumn get metWhen => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  /// ⚠ The load-bearing field. Cannot be sensibly backfilled — you will not
  /// remember. Captured at A1, never after.
  TextColumn get occasionTags =>
      text().map(const TagListConverter()).withDefault(const Constant(''))();

  DateTimeColumn get pingDate => dateTime().nullable()();
  TextColumn get pingNote => text().nullable()();

  /// Sync columns, present from day one. ⚠ Soft delete only — a hard-deleted
  /// row leaves nothing to tell the other device it is gone, so it syncs
  /// straight back. In Phase 4 the SERVER stamps updatedAt, never the client.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [People])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'personal_crm'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  /// Everything alive, newest contact first.
  Stream<List<Person>> watchPeople() => (select(people)
        ..where((p) => p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.desc(p.id)]))
      .watch();

  /// B2 — the occasion list. Filtered to people carrying this tag.
  /// LIKE on a comma string is fine at this scale; revisit past ~2k rows.
  Stream<List<Person>> watchByTag(String tag) => (select(people)
        ..where((p) =>
            p.deletedAt.isNull() &
            (p.occasionTags.equals(tag) |
                p.occasionTags.like('$tag,%') |
                p.occasionTags.like('%,$tag') |
                p.occasionTags.like('%,$tag,%')))
        ..orderBy([(p) => OrderingTerm.desc(p.id)]))
      .watch();

  Future<int> addPerson(PeopleCompanion p) => into(people).insert(p);

  Future<void> softDelete(int id) => (update(people)..where((p) => p.id.equals(id)))
      .write(PeopleCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
}
