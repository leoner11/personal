import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

const _uuid = Uuid();

/// ⚠ IDs are client-generated UUIDs, NOT autoincrement integers.
/// Two devices handing out 1, 2, 3 from independent sequences produce
/// different people that share an id, and last-write-wins then merges them
/// and destroys one. A UUID is unique wherever it was created.
String newId() => _uuid.v4();

/// ⚠ SEEDED rows are the one exception to "ids are random". Every device seeds
/// its own occasion calendar on first launch, offline, before it has ever
/// reached the server. With v4 ids the Mac and the phone mint 19 rows each with
/// different ids and identical content — sync then keeps all 38, and every
/// festival notifies twice. v5 is a HASH of the key, so both devices derive the
/// same id independently and last-write-wins collapses them into one row.
String seededId(String key) => _uuid.v5(Namespace.url.value, 'personal-crm:$key');

/// The stable identity of a seeded occasion: its name and the day it falls on.
/// Date only, never the full timestamp — two devices in different timezones
/// must not disagree about what the key is.
String occasionSeedKey(String name, DateTime date) =>
    'occasion:$name:${date.toIso8601String().substring(0, 10)}';

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
  TextColumn get id => text().clientDefault(newId)();
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

  @override
  Set<Column> get primaryKey => {id};
}

/// D3 — Occasions. Hand-seeded, three years at a time.
/// ⚠ No API can supply these. Indonesian Lebaran is fixed by sidang isbat days
/// before; China's arrangement is published by the State Council each Nov/Dec;
/// Malaysia depends on moon sighting and varies by state.
@DataClassName('Occasion')
class Occasions extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text()();
  DateTimeColumn get date => dateTime()();
  /// OccasionTag.name — links a date to the people carrying that tag.
  TextColumn get tag => text()();
  TextColumn get country => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// D2 — Engagements. ⚠ Deliberately NOT a pipeline.
/// Ralali is a jv, not a deal — that distinction is the entire reason this
/// table exists instead of a deals table.
@DataClassName('Engagement')
class Engagements extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get name => text()();
  /// deal | jv | client | lead
  TextColumn get type => text().withDefault(const Constant('deal'))();
  TextColumn get counterpartyId => text().nullable()();
  /// ⚠ FREE TEXT ON PURPOSE. The moment this becomes a dropdown of stages,
  /// this is a sales tool and scope has escaped.
  TextColumn get status => text().nullable()();
  IntColumn get valueMinor => integer().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// D4 — Money. One table serves all three finance questions:
///   have    = SUM(actual,in) - SUM(actual,out)
///   coming in  = expected + in
///   coming out = expected + out
/// ⛔ Cashflow, NOT bookkeeping. No categories, no P&L, no reconciliation.
@DataClassName('MoneyRow')
class Money extends Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get date => dateTime()();
  /// in | out
  TextColumn get direction => text()();
  /// Minor units (cents). Integers, never floats — see kDecimals.
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get label => text()();
  /// expected | actual
  TextColumn get status => text().withDefault(const Constant('expected'))();
  TextColumn get engagementId => text().nullable()();
  TextColumn get personId => text().nullable()();
  /// Set when the row was created by a gift commit, so close-out can find it.
  TextColumn get occasionTag => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// D5 — Notes. ⚠ Deliberately dumb. A textarea and a save button.
@DataClassName('Note')
class Notes extends Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get date => dateTime()();
  /// ⚠ Named `body` in Dart: a column getter called `text` collides with
  /// drift's own Table.text() builder and codegen silently emits nothing.
  TextColumn get body => text().named('text').withDefault(const Constant(''))();
  TextColumn get personId => text().nullable()();
  TextColumn get engagementId => text().nullable()();
  TextColumn get tag => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// D6 — Touches. ⚠ ALWAYS OPTIONAL. The app must be fully useful for someone
/// who never logs a single touch. Do not gate anything on it.
@DataClassName('Touch')
class Touches extends Table {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get personId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get oneLine => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A scheduled meeting. ⚠ The first table in this app with a TIME, not just a
/// date — occasions are whole days and touches record what already happened.
/// A meeting is a commitment at 3pm, so startsAt carries the clock and the
/// reminder fires relative to it rather than at the 09:00 everything else uses.
///
/// ⚠ Why not reuse person.pingDate: that is ONE nullable column on the person
/// row, so a person can hold exactly one future dated thing. Booking a meeting
/// would silently overwrite their ping, and two meetings with the same person
/// could not both exist.
@DataClassName('Meeting')
class Meetings extends Table {
  TextColumn get id => text().clientDefault(newId)();

  /// Nullable: a meeting can exist before you have decided who it is with,
  /// and the same pattern as money and notes.
  TextColumn get personId => text().nullable()();
  TextColumn get engagementId => text().nullable()();
  TextColumn get title => text()();
  DateTimeColumn get startsAt => dateTime()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(60))();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
    tables: [People, Occasions, Engagements, Money, Notes, Touches, Meetings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'personal_crm'));
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v3 changed every primary key from autoincrement int to UUID.
          // There is no in-place migration for that and no data worth
          // preserving at this point, so rebuild from scratch.
          if (from < 3) {
            for (final t in allSchemaEntities.whereType<TableInfo>().toList().reversed) {
              await m.deleteTable(t.actualTableName);
            }
            await m.createAll();
          }
          // v4 gives seeded occasions deterministic ids so a second device
          // cannot duplicate the calendar. Rewrites in place rather than
          // reseeding — hand-corrected dates (Lebaran, Idul Adha, Deepavali)
          // are worth keeping. Nothing references an occasion by id; money
          // carries occasion_tag, a string.
          if (from < 4) {
            for (final o in await select(occasions).get()) {
              final want = seededId(occasionSeedKey(o.name, o.date));
              if (o.id != want) {
                await (update(occasions)..where((t) => t.id.equals(o.id)))
                    .write(OccasionsCompanion(id: Value(want)));
              }
            }
          }
          // v5 adds meetings. ⚠ createTable only — nothing else is touched,
          // because by now this database holds real contacts.
          if (from < 5) {
            await m.createTable(meetings);
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

  /// ⚠ One-shot reads. Use these instead of `watchX().first` when the value is
  /// only needed once. Taking `.first` from a watch stream builds a query
  /// stream, subscribes, and immediately cancels it — wasted work in
  /// production, and drift schedules a zero-duration teardown timer on that
  /// cancel (StreamQueryStore.markAsClosed) which outlives a widget test and
  /// trips its "Timer is still pending" assertion.
  Future<List<Person>> allPeople() => (select(people)
        ..where((p) => p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.desc(p.id)]))
      .get();

  Future<List<Occasion>> allOccasions() => (select(occasions)
        ..where((o) => o.deletedAt.isNull())
        ..orderBy([(o) => OrderingTerm.asc(o.date)]))
      .get();

  Future<List<MoneyRow>> allMoney() => (select(money)
        ..where((m) => m.deletedAt.isNull())
        ..orderBy([(m) => OrderingTerm.desc(m.date)]))
      .get();

  Future<int> addPerson(PeopleCompanion p) => into(people).insert(p);

  /// ⚠ The one write this app went without for far too long. `money`, `notes`
  /// and `engagements` all had an update path; `people` — the table the whole
  /// app exists for — did not, so a name, a number or an occasion tag was
  /// write-once at capture and a typo was permanent.
  ///
  /// ⚠ Updates IN PLACE, keeping the id. The workaround it replaces was delete
  /// and re-add, which mints a new UUID: every touch, note and money row still
  /// points at the old id and silently detaches from the person.
  ///
  /// ⚠ Stamps updatedAt, like every other write here. Without it the row never
  /// syncs — the server pulls on `updated_at > since` and would never see it.
  Future<void> updatePerson(String id, PeopleCompanion patch) =>
      (update(people)..where((p) => p.id.equals(id)))
          .write(patch.copyWith(updatedAt: Value(DateTime.now())));

  Future<void> softDelete(String id) => (update(people)..where((p) => p.id.equals(id)))
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

  // ── Meetings ────────────────────────────────────────────────────────────
  /// Everything ahead, soonest first — what the calendar and Today read.
  Stream<List<Meeting>> watchMeetings() => (select(meetings)
        ..where((m) => m.deletedAt.isNull())
        ..orderBy([(m) => OrderingTerm.asc(m.startsAt)]))
      .watch();

  Stream<List<Meeting>> watchMeetingsForPerson(String personId) =>
      (select(meetings)
            ..where((m) => m.deletedAt.isNull() & m.personId.equals(personId))
            ..orderBy([(m) => OrderingTerm.desc(m.startsAt)]))
          .watch();

  Future<List<Meeting>> allMeetings() => (select(meetings)
        ..where((m) => m.deletedAt.isNull())
        ..orderBy([(m) => OrderingTerm.asc(m.startsAt)]))
      .get();

  Future<int> addMeeting(MeetingsCompanion m) => into(meetings).insert(m);

  Future<List<Touch>> allTouches() => (select(touches)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .get();

  /// ⚠ Stamps updatedAt like every other write. Without it the row never
  /// syncs — the server pulls on `updated_at > since` and never sees it.
  Future<void> updateMeeting(String id, MeetingsCompanion patch) =>
      (update(meetings)..where((m) => m.id.equals(id)))
          .write(patch.copyWith(updatedAt: Value(DateTime.now())));

  Future<void> setPing(String id, DateTime? date, {String? note}) =>
      (update(people)..where((p) => p.id.equals(id))).write(PeopleCompanion(
        pingDate: Value(date),
        pingNote: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(DateTime.now()),
      ));

  Future<int> logTouch(String personId, String line) =>
      into(touches).insert(TouchesCompanion.insert(
        personId: personId,
        date: DateTime.now(),
        oneLine: Value(line),
      ));

  Stream<List<Touch>> watchTouches(String personId) => (select(touches)
        ..where((t) => t.personId.equals(personId) & t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch();

  Future<Map<String, DateTime>> lastTouchByPerson() async {
    final rows = await (select(touches)..where((t) => t.deletedAt.isNull())).get();
    final out = <String, DateTime>{};
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

  Future<void> settleMoney(String id, {int? amountMinor, DateTime? date}) =>
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

  Future<void> saveNote(String id, String text) =>
      (update(notes)..where((n) => n.id.equals(id))).write(NotesCompanion(
        body: Value(text),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> softDeleteRow(TableInfo table, String id) => customUpdate(
        'UPDATE ${table.actualTableName} SET deleted_at = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          Variable.withInt(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          Variable.withString(id),
        ],
        updates: {table},
      );
}

/// Person <-> engagement links. The counterparty field is what makes a project
/// row mean something on its own — "NaraHome ERP" without a person attached is
/// a name, not a relationship.
extension Links on AppDatabase {
  Stream<List<Engagement>> watchEngagementsForPerson(String personId) =>
      (select(engagements)
            ..where((e) =>
                e.deletedAt.isNull() & e.counterpartyId.equals(personId)))
          .watch();

  Future<Map<String, Person>> peopleById() async {
    final rows = await (select(people)..where((p) => p.deletedAt.isNull())).get();
    return {for (final p in rows) p.id: p};
  }

  /// B2 sorts by engagement value desc, then last touch asc — highest-value
  /// and longest-neglected first, so if you only get through half the list it
  /// was the right half. Currency is ignored for ordering: mixing rates in
  /// would need an FX source, and relative order is all that matters here.
  Future<Map<String, int>> engagementValueByPerson() async {
    final rows = await (select(engagements)
          ..where((e) => e.deletedAt.isNull() & e.counterpartyId.isNotNull()))
        .get();
    final out = <String, int>{};
    for (final e in rows) {
      final id = e.counterpartyId;
      if (id == null || id.isEmpty) continue;
      out[id] = (out[id] ?? 0) + (e.valueMinor ?? 0);
    }
    return out;
  }

  Future<void> updateEngagement(String id, EngagementsCompanion patch) =>
      (update(engagements)..where((e) => e.id.equals(id))).write(patch);
}

/// Everything attached to a person, for the unified timeline and the reverse
/// panels. ⚠ Links are always optional — an unlinked note or money row is
/// normal, not incomplete.
extension MoreLinks on AppDatabase {
  Stream<List<Note>> watchNotesForPerson(String personId) => (select(notes)
        ..where((n) => n.deletedAt.isNull() & n.personId.equals(personId))
        ..orderBy([(n) => OrderingTerm.desc(n.date)]))
      .watch();

  Stream<List<Note>> watchNotesForEngagement(String engagementId) =>
      (select(notes)
            ..where((n) =>
                n.deletedAt.isNull() & n.engagementId.equals(engagementId))
            ..orderBy([(n) => OrderingTerm.desc(n.date)]))
          .watch();

  Stream<List<MoneyRow>> watchMoneyForPerson(String personId) => (select(money)
        ..where((m) => m.deletedAt.isNull() & m.personId.equals(personId))
        ..orderBy([(m) => OrderingTerm.desc(m.date)]))
      .watch();

  Future<void> updateNote(String id, NotesCompanion patch) =>
      (update(notes)..where((n) => n.id.equals(id))).write(patch);

  Future<void> updateMoney(String id, MoneyCompanion patch) =>
      (update(money)..where((m) => m.id.equals(id))).write(patch);

  Future<Map<String, Engagement>> engagementsById() async {
    final rows =
        await (select(engagements)..where((e) => e.deletedAt.isNull())).get();
    return {for (final e in rows) e.id: e};
  }
}

/// One row on the person timeline, from whichever table it came.
class TimelineEntry {
  const TimelineEntry({
    required this.date,
    required this.kind,
    required this.text,
    this.direction,
  });

  final DateTime date;
  /// touch | note | money | meeting
  final String kind;
  final String text;
  /// 'in' | 'out' for money rows, null otherwise.
  final String? direction;
}
