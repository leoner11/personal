import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/domain/config.dart';
import 'package:personal_crm/data/database.dart';

/// Regressions for the column-exists-but-feature-missing audit.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a money row can be dated in the future, not just now', () async {
    // COMING IN / COMING OUT is entirely about future money. Rows pinned to
    // now made the whole view useless.
    final due = DateTime(2026, 10, 1);
    await db.addMoney(MoneyCompanion.insert(
      id: Value(newId()),
      date: due,
      direction: 'in',
      amountMinor: 2500000,
      label: 'Powerline M3',
    ));
    expect((await db.watchMoney().first).single.date, due);
  });

  test('settling can change the amount and the date', () async {
    final id = newId();
    await db.addMoney(MoneyCompanion.insert(
      id: Value(id),
      date: DateTime(2026, 10, 1),
      direction: 'in',
      amountMinor: 2500000,
      label: 'Powerline M3',
    ));
    await db.settleMoney(id,
        amountMinor: 2400000, date: DateTime(2026, 10, 9));

    final row = (await db.watchMoney().first).single;
    expect(row.status, 'actual');
    expect(row.amountMinor, 2400000);
    expect(row.date, DateTime(2026, 10, 9));
  });

  test('an expected row can be pushed later and stay expected', () async {
    // The Prawnwatch pattern: a row that slips repeatedly is information.
    final id = newId();
    await db.addMoney(MoneyCompanion.insert(
      id: Value(id),
      date: DateTime(2026, 10, 1),
      direction: 'in',
      amountMinor: 100,
      label: 'slips',
    ));
    await db.updateMoney(
        id, MoneyCompanion(date: Value(DateTime(2026, 12, 1))));

    final row = (await db.watchMoney().first).single;
    expect(row.status, 'expected');
    expect(row.date.month, 12);
  });

  test('an occasion can be added and its date corrected after seeding',
      () async {
    // Lebaran and Idul Adha move on sighting; the seeded date is an estimate
    // and the runway warning tells you to add more dates.
    final id = newId();
    await db.into(db.occasions).insert(OccasionsCompanion.insert(
          id: Value(id),
          name: 'Lebaran / Aidilfitri',
          date: DateTime(2027, 3, 9),
          tag: 'lebaran',
        ));
    await (db.update(db.occasions)..where((o) => o.id.equals(id)))
        .write(OccasionsCompanion(date: Value(DateTime(2027, 3, 10))));

    expect((await db.watchOccasions().first).single.date, DateTime(2027, 3, 10));
  });

  test('a note can carry a brand-new tag with no existing tags', () async {
    // The chicken-and-egg: the tag used to come only from the active filter,
    // which only listed tags that already existed, so the first was
    // unreachable.
    final id = newId();
    await db.into(db.notes).insert(NotesCompanion.insert(
        id: Value(id), date: DateTime.now()));
    await db.updateNote(id, const NotesCompanion(tag: Value('content')));

    expect((await db.watchNotes().first).single.tag, 'content');
  });

  test('a note can be dated in the future for content planning', () async {
    final id = newId();
    final when = DateTime(2026, 9, 20);
    await db.into(db.notes).insert(
        NotesCompanion.insert(id: Value(id), date: DateTime.now()));
    await db.updateNote(id, NotesCompanion(date: Value(when)));

    expect((await db.watchNotes().first).single.date, when);
  });

  test('every table soft-deletes rather than vanishing', () async {
    final pid = newId();
    await db.addPerson(PeopleCompanion.insert(id: Value(pid), name: 'Typo'));
    await db.softDelete(pid);
    expect(await db.watchPeople().first, isEmpty);
    expect((await db.select(db.people).get()).single.deletedAt, isA<DateTime>());

    final oid = newId();
    await db.into(db.occasions).insert(OccasionsCompanion.insert(
        id: Value(oid), name: 'Wrong', date: DateTime.now(), tag: 'newYear'));
    await db.softDeleteRow(db.occasions, oid);
    expect(await db.watchOccasions().first, isEmpty);
    expect((await db.select(db.occasions).get()).single.deletedAt,
        isA<DateTime>());
  });

  test('gift rows are findable by occasion for close-out', () async {
    // money.occasionTag was write-only: the T+1 notification promised a
    // close-out screen that did not exist.
    await db.addMoney(MoneyCompanion.insert(
      id: Value(newId()),
      date: DateTime(2026, 9, 25),
      direction: 'out',
      amountMinor: 40000,
      label: '中秋节 gift — Pak Andi',
      occasionTag: const Value('midAutumn'),
    ));
    await db.addMoney(MoneyCompanion.insert(
      id: Value(newId()),
      date: DateTime.now(),
      direction: 'out',
      amountMinor: 420,
      label: 'VPS renewal',
    ));

    final gifts = (await db.watchMoney().first)
        .where((m) => m.occasionTag == 'midAutumn')
        .toList();
    expect(gifts.length, 1);
    expect(gifts.single.status, 'expected');

    await db.settleMoney(gifts.single.id);
    expect(
        (await db.watchMoney().first)
            .firstWhere((m) => m.occasionTag == 'midAutumn')
            .status,
        'actual');
  });

  test('a project keeps its free-text notes', () async {
    final id = newId();
    await db.into(db.engagements).insert(EngagementsCompanion.insert(
        id: Value(id), name: 'Ralali JV', notes: const Value('via ZIBS intro')));
    expect((await db.watchEngagements().first).single.notes, 'via ZIBS intro');
  });

  group('sync is not allowed to leak the token', () {
    // ⚠ The token rides in an Authorization header on EVERY sync request, and
    // phone sync happens on cafe and airport wifi. Over http that header is
    // readable by anyone on the network.
    test('an http:// base url disables sync rather than leaking over it', () {
      expect(syncEnabledFor('http://crm.example.com'), isFalse);
      expect(syncEnabledFor('http://192.168.1.10:8765'), isFalse);
    });

    test('https is what turns sync on', () {
      expect(syncEnabledFor('https://crm.example.com'), isTrue);
    });

    test('empty stays local-only, which is the default state', () {
      expect(syncEnabledFor(''), isFalse);
    });
  });
}
