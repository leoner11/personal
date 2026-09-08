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

/// D3 — Occasions. Hand-seeded, three years at a time.
/// ⚠ No API can supply these. Indonesian Lebaran is fixed by sidang isbat days
/// before; China's arrangement is published by the State Council each Nov/Dec;
/// Malaysia depends on moon sighting and varies by state.
@DataClassName('Occasion')
class Occasions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get date => dateTime()();
  /// OccasionTag.name — links a date to the people carrying that tag.
  TextColumn get tag => text()();
  TextColumn get country => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// D2 — Engagements. ⚠ Deliberately NOT a pipeline.
/// Ralali is a jv, not a deal — that distinction is the entire reason this
/// table exists instead of a deals table.
@DataClassName('Engagement')
class Engagements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  /// deal | jv | client | lead
  TextColumn get type => text().withDefault(const Constant('deal'))();
  IntColumn get counterpartyId => integer().nullable()();
  /// ⚠ FREE TEXT ON PURPOSE. The moment this becomes a dropdown of stages,
  /// this is a sales tool and scope has escaped.
  TextColumn get status => text().nullable()();
  IntColumn get valueMinor => integer().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// D4 — Money. One table serves all three finance questions:
///   have    = SUM(actual,in) - SUM(actual,out)
///   coming in  = expected + in
///   coming out = expected + out
/// ⛔ Cashflow, NOT bookkeeping. No categories, no P&L, no reconciliation.
@DataClassName('MoneyRow')
class Money extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  /// in | out
  TextColumn get direction => text()();
  /// Minor units (cents). Integers, never floats — see kDecimals.
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get label => text()();
  /// expected | actual
  TextColumn get status => text().withDefault(const Constant('expected'))();
  IntColumn get engagementId => integer().nullable()();
  IntColumn get personId => integer().nullable()();
  /// Set when the row was created by a gift commit, so close-out can find it.
  TextColumn get occasionTag => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// D5 — Notes. ⚠ Deliberately dumb. A textarea and a save button.
@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  /// ⚠ Named `body` in Dart: a column getter called `text` collides with
  /// drift's own Table.text() builder and codegen silently emits nothing.
  TextColumn get body => text().named('text').withDefault(const Constant(''))();
  IntColumn get personId => integer().nullable()();
  IntColumn get engagementId => integer().nullable()();
  TextColumn get tag => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// D6 — Touches. ⚠ ALWAYS OPTIONAL. The app must be fully useful for someone
/// who never logs a single touch. Do not gate anything on it.
@DataClassName('Touch')
class Touches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get oneLine => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [People, Occasions, Engagements, Money, Notes, Touches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'personal_crm'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(occasions);
            await m.createTable(engagements);
            await m.createTable(money);
            await m.createTable(notes);
            await m.createTable(touches);
          }
        },
      );

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

/// Queries used across screens. Kept on the database object rather than in a
/// repository layer — one user, six tables, no second consumer.
extension Queries on AppDatabase {
  Stream<List<Occasion>> watchOccasions() => (select(occasions)
        ..where((o) => o.deletedAt.isNull())
        ..orderBy([(o) => OrderingTerm.asc(o.date)]))
      .watch();

  /// The next occasion for each tag, used by Today and the scheduler.
  Future<List<Occasion>> upcomingOccasions({int withinDays = 400}) async {
    final now = DateTime.now();
    final all = await (select(occasions)
          ..where((o) => o.deletedAt.isNull())
          ..orderBy([(o) => OrderingTerm.asc(o.date)]))
        .get();
    return all
        .where((o) =>
            o.date.isAfter(now.subtract(const Duration(days: 1))) &&
            o.date.difference(now).inDays <= withinDays)
        .toList();
  }

  /// ⚠ The runway. If this runs dry nothing schedules, nothing fires, and it
  /// looks exactly like a normal quiet day.
  Future<DateTime?> calendarRunway() async {
    final rows = await (select(occasions)
          ..where((o) => o.deletedAt.isNull())
          ..orderBy([(o) => OrderingTerm.desc(o.date)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first.date;
  }

  Stream<List<Person>> watchPings() => (select(people)
        ..where((p) => p.deletedAt.isNull() & p.pingDate.isNotNull())
        ..orderBy([(p) => OrderingTerm.asc(p.pingDate)]))
      .watch();

  Future<void> setPing(int id, DateTime? date, {String? note}) =>
      (update(people)..where((p) => p.id.equals(id))).write(PeopleCompanion(
        pingDate: Value(date),
        pingNote: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(DateTime.now()),
      ));

  Future<int> logTouch(int personId, String line) =>
      into(touches).insert(TouchesCompanion.insert(
        personId: personId,
        date: DateTime.now(),
        oneLine: Value(line),
      ));

  Stream<List<Touch>> watchTouches(int personId) => (select(touches)
        ..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch();

  Future<Map<int, DateTime>> lastTouchByPerson() async {
    final rows = await (select(touches)..where((t) => t.deletedAt.isNull())).get();
    final out = <int, DateTime>{};
    for (final t in rows) {
      final cur = out[t.personId];
      if (cur == null || t.date.isAfter(cur)) out[t.personId] = t.date;
    }
    return out;
  }

  Stream<List<MoneyRow>> watchMoney() => (select(money)
        ..where((m) => m.deletedAt.isNull())
        ..orderBy([(m) => OrderingTerm.desc(m.date)]))
      .watch();

  Future<int> addMoney(MoneyCompanion m) => into(money).insert(m);

  Future<void> settleMoney(int id, {int? amountMinor, DateTime? date}) =>
      (update(money)..where((m) => m.id.equals(id))).write(MoneyCompanion(
        status: const Value('actual'),
        amountMinor:
            amountMinor == null ? const Value.absent() : Value(amountMinor),
        date: date == null ? const Value.absent() : Value(date),
        updatedAt: Value(DateTime.now()),
      ));

  Stream<List<Engagement>> watchEngagements() => (select(engagements)
        ..where((e) => e.deletedAt.isNull())
        ..orderBy([(e) => OrderingTerm.asc(e.type)]))
      .watch();

  Stream<List<Note>> watchNotes() => (select(notes)
        ..where((n) => n.deletedAt.isNull())
        ..orderBy([(n) => OrderingTerm.desc(n.date)]))
      .watch();

  Future<void> saveNote(int id, String text) =>
      (update(notes)..where((n) => n.id.equals(id))).write(NotesCompanion(
        body: Value(text),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> softDeleteRow(TableInfo table, int id) => customUpdate(
        'UPDATE ${table.actualTableName} SET deleted_at = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          Variable.withInt(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          Variable.withInt(id),
        ],
        updates: {table},
      );
}
