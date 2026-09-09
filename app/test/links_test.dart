import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> person(String name) async {
    final id = newId();
    await db.addPerson(PeopleCompanion.insert(id: Value(id), name: name));
    return id;
  }

  Future<String> project(String name, {String? personId, int? value}) async {
    final id = newId();
    await db.into(db.engagements).insert(EngagementsCompanion.insert(
          id: Value(id),
          name: name,
          counterpartyId: Value(personId),
          valueMinor: Value(value),
        ));
    return id;
  }

  test('a project links to a person and is findable from both sides', () async {
    final andi = await person('Pak Andi');
    await project('Formcase ERP', personId: andi, value: 500000);

    // Project -> person
    final byId = await db.peopleById();
    final proj = (await db.watchEngagements().first).single;
    expect(byId[proj.counterpartyId]?.name, 'Pak Andi');

    // Person -> project. Without this the link would be write-only.
    final linked = await db.watchEngagementsForPerson(andi).first;
    expect(linked.single.name, 'Formcase ERP');
  });

  test('an unlinked project belongs to no one', () async {
    await person('Someone');
    await project('Orphan project');
    final all = await db.watchEngagements().first;
    expect(all.single.counterpartyId, isNull);
  });

  test('value sums across several projects for the same person', () async {
    final p = await person('Ralali');
    await project('JV phase 1', personId: p, value: 100000);
    await project('JV phase 2', personId: p, value: 250000);
    await project('unlinked', value: 999999);

    final values = await db.engagementValueByPerson();
    expect(values[p], 350000);
    expect(values.length, 1); // the unlinked one contributes to nobody
  });

  test('deleted projects drop out of the value ranking', () async {
    final p = await person('Gone Co');
    final id = await project('Cancelled', personId: p, value: 900000);
    await db.updateEngagement(
        id, EngagementsCompanion(deletedAt: Value(DateTime.now())));

    expect(await db.engagementValueByPerson(), isEmpty);
    expect(await db.watchEngagementsForPerson(p).first, isEmpty);
  });

  test('notes and money link to a person and a project, both optional', () async {
    final p = await person('Bu Sari');
    final e = await project('Cooljek app', personId: p);

    final noteId = newId();
    await db.into(db.notes).insert(NotesCompanion.insert(
          id: Value(noteId),
          date: DateTime.now(),
          body: Value('discussed the gudang'),
          personId: Value(p),
          engagementId: Value(e),
        ));
    // An unlinked note is normal, not incomplete.
    await db.into(db.notes).insert(NotesCompanion.insert(
          id: Value(newId()),
          date: DateTime.now(),
          body: Value('random idea'),
        ));

    expect((await db.watchNotesForPerson(p).first).single.body,
        'discussed the gudang');
    expect((await db.watchNotesForEngagement(e).first).single.body,
        'discussed the gudang');
    expect((await db.watchNotes().first).length, 2);
  });

  test('clearing a link nulls it without deleting the row', () async {
    final p = await person('Someone');
    final id = newId();
    await db.into(db.notes).insert(NotesCompanion.insert(
          id: Value(id), date: DateTime.now(), personId: Value(p)));

    await db.updateNote(id, const NotesCompanion(personId: Value(null)));

    expect(await db.watchNotesForPerson(p).first, isEmpty);
    expect((await db.watchNotes().first).length, 1); // row survives
  });

  test('the person timeline interleaves touches, notes and money by date',
      () async {
    final p = await person('Pak Andi');
    await db.into(db.touches).insert(TouchesCompanion.insert(
          id: Value(newId()),
          personId: p,
          date: DateTime(2026, 3, 20),
          oneLine: Value('met at ZIBS mixer'),
        ));
    await db.into(db.notes).insert(NotesCompanion.insert(
          id: Value(newId()),
          date: DateTime(2026, 8, 2),
          body: Value('mentioned expanding the gudang'),
          personId: Value(p),
        ));
    await db.addMoney(MoneyCompanion.insert(
      id: Value(newId()),
      date: DateTime(2026, 6, 14),
      direction: 'out',
      amountMinor: 40000,
      label: 'Lebaran hampers',
      personId: Value(p),
    ));

    final entries = <TimelineEntry>[
      for (final x in await db.watchTouches(p).first)
        TimelineEntry(date: x.date, kind: 'touch', text: x.oneLine),
      for (final n in await db.watchNotesForPerson(p).first)
        TimelineEntry(date: n.date, kind: 'note', text: n.body),
      for (final m in await db.watchMoneyForPerson(p).first)
        TimelineEntry(
            date: m.date, kind: 'money', direction: m.direction, text: m.label),
    ]..sort((a, b) => b.date.compareTo(a.date));

    expect(entries.map((e) => e.kind).toList(), ['note', 'money', 'touch']);
    expect(entries.first.date, DateTime(2026, 8, 2));
  });

  test('B2 ranking: value desc, then oldest touch, never-touched first', () async {
    // Mirrors the ordering used by the occasion run screen.
    final rich = await person('Rich');
    final poor = await person('Poor');
    await person('Never');
    await project('big', personId: rich, value: 900000);
    await project('small', personId: poor, value: 100);

    await db.logTouch(rich, 'recent');
    await db.logTouch(poor, 'recent');

    final values = await db.engagementValueByPerson();
    final touches = await db.lastTouchByPerson();
    final people = await db.watchPeople().first;

    final sorted = [...people]..sort((a, b) {
        final va = values[a.id] ?? 0;
        final vb = values[b.id] ?? 0;
        if (va != vb) return vb.compareTo(va);
        final ta = touches[a.id];
        final tb = touches[b.id];
        if (ta == null && tb == null) return a.name.compareTo(b.name);
        if (ta == null) return -1;
        if (tb == null) return 1;
        return ta.compareTo(tb);
      });

    // Highest value first; the never-touched, zero-value person outranks the
    // low-value one only on the touch tiebreak, so it lands last on value.
    expect(sorted.first.name, 'Rich');
    expect(sorted[1].name, 'Poor');
    expect(sorted[2].name, 'Never');
  });
}
