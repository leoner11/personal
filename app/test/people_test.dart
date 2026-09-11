import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/channel.dart';
import 'package:personal_crm/domain/occasions.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Returns the UUID, not the rowid — insert() gives the latter and it is
  // not the primary key any more.
  Future<String> add(String name, List<OccasionTag> tags,
      {String? wa, String? wc}) async {
    final id = newId();
    await db.addPerson(PeopleCompanion.insert(
      id: Value(id),
      name: name,
      waNumber: Value(wa),
      wechatId: Value(wc),
      preferredChannel: Value(wa != null ? 'wa' : 'wechat'),
      occasionTags: Value(tags.map((t) => t.name).toList()),
    ));
    return id;
  }

  test('tag filter matches first, middle, last and only positions', () async {
    // The LIKE-over-a-comma-string filter is the one bit of real logic in
    // Phase 1. Every position in the list must match.
    await add('Only',   [OccasionTag.midAutumn], wa: '1');
    await add('First',  [OccasionTag.midAutumn, OccasionTag.cny], wa: '2');
    await add('Last',   [OccasionTag.cny, OccasionTag.midAutumn], wa: '3');
    await add('Middle', [OccasionTag.cny, OccasionTag.midAutumn, OccasionTag.christmas], wa: '4');
    await add('Absent', [OccasionTag.cny, OccasionTag.christmas], wa: '5');

    final got = await db.watchByTag(OccasionTag.midAutumn.name).first;
    expect(got.map((p) => p.name).toSet(), {'Only', 'First', 'Last', 'Middle'});
  });

  test('tag filter does not match on a substring collision', () async {
    // 'newYear' must not be dragged in by a search for a shorter tag, and
    // vice versa. Guards the naive LIKE '%tag%' mistake.
    await add('NY', [OccasionTag.newYear], wa: '1');
    final cny = await db.watchByTag(OccasionTag.cny.name).first;
    expect(cny, isEmpty);
  });

  test('soft delete hides the row but keeps it', () async {
    final id = await add('Gone', [OccasionTag.midAutumn], wa: '1');
    await db.softDelete(id);

    expect(await db.watchPeople().first, isEmpty);
    expect(await db.watchByTag(OccasionTag.midAutumn.name).first, isEmpty);
    // ⚠ Still on disk — a hard delete would sync straight back in Phase 4.
    final raw = await db.select(db.people).get();
    expect(raw.single.deletedAt, isA<DateTime>());
  });

  test('person with no tags appears under Everyone only', () async {
    await add('Untagged', const [], wa: '1');
    expect((await db.watchPeople().first).length, 1);
    expect(await db.watchByTag(OccasionTag.midAutumn.name).first, isEmpty);
  });

  test('macOS builds a whatsapp:// link, never wa.me', () {
    // Spike 0.2: wa.me resolves to Safari on macOS. Regression guard.
    final uri = whatsappUri('+62 812-3456-7890', '中秋节快乐');
    expect(uri.scheme, 'whatsapp');
    expect(uri.query, contains('phone=6281234567890')); // punctuation stripped
    expect(uri.toString(), isNot(contains('wa.me')));
  });

  test('ids are uuids, unique per row, so two devices cannot collide', () async {
    // ⚠ The bug this replaced: autoincrement ids from two independent
    // sequences produce different people sharing an id, and last-write-wins
    // then merges them and destroys one.
    final a = await add('A', const [], wa: '1');
    final b = await add('B', const [], wa: '2');
    expect(a, isNot(b));
    expect(a.length, 36);
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(a), isTrue);
  });

  test('mid-autumn constant is the confirmed 2026 date', () {
    expect(kMidAutumn2026, DateTime(2026, 9, 25));
  });

  test('countdown counts whole calendar days, not elapsed 24h blocks', () {
    // Late in the day, a raw .inDays truncates and reads one day short.
    int daysFrom(DateTime now) =>
        kMidAutumn2026.difference(DateTime(now.year, now.month, now.day)).inDays;
    expect(daysFrom(DateTime(2026, 9, 9, 0, 14)), 16);
    expect(daysFrom(DateTime(2026, 9, 9, 23, 59)), 16);
    expect(daysFrom(DateTime(2026, 9, 25, 9, 0)), 0);
  });

  group('editing a person', () {
    Future<Person> only(AppDatabase db) async =>
        (await db.watchPeople().first).single;

    Future<String> seed(AppDatabase db) async {
      await db.addPerson(PeopleCompanion.insert(
        name: 'Pak Andi',
        waNumber: const Value('628123456789'),
        company: const Value('PT Formcase'),
        metWhen: Value(DateTime(2026, 3, 1)),
        occasionTags: const Value(['christmas']),
      ));
      return (await only(db)).id;
    }

    test('the id survives, so nothing linked detaches', () async {
      // ⚠ The whole point. The workaround this replaces was delete-and-re-add,
      // which mints a new UUID and leaves every touch, note and money row
      // pointing at an id no person has any more.
      final id = await seed(db);
      await db.logTouch(id, 'called about the gudang');

      await db.updatePerson(id, const PeopleCompanion(name: Value('Pak Andri')));

      final p = await only(db);
      expect(p.id, id);
      expect(p.name, 'Pak Andri');
      expect((await db.watchTouches(id).first).length, 1);
    });

    test('updated_at is stamped, or the row never syncs', () async {
      // ⚠ The server pulls on `updated_at > since`. An unstamped edit is
      // invisible to the other device forever, and looks like nothing broke.
      final id = await seed(db);
      final before = (await only(db)).updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      await db.updatePerson(id, const PeopleCompanion(name: Value('Changed')));
      expect((await only(db)).updatedAt.isAfter(before), isTrue);
    });

    test('an occasion tag can be added later', () async {
      // The reason this feature was built: eleven people entered from a list
      // of names, none of them tagged, and no way to tag them.
      final id = await seed(db);
      await db.updatePerson(
          id, const PeopleCompanion(occasionTags: Value(['christmas', 'guoqing'])));
      expect((await only(db)).occasionTags, ['christmas', 'guoqing']);
    });

    test('a channel can be added to someone who had none', () async {
      await db.addPerson(PeopleCompanion.insert(name: 'Om Lilik'));
      final id = (await only(db)).id;
      expect((await only(db)).waNumber, equals(null));

      await db.updatePerson(
          id, const PeopleCompanion(waNumber: Value('628999000111')));
      expect((await only(db)).waNumber, '628999000111');
    });

    test('fields left out of the patch are untouched', () async {
      // ⚠ Value.absent() means "do not write", which is what lets the phone
      // sheet omit ping fields it does not show without clearing them.
      final id = await seed(db);
      await db.updatePerson(id, const PeopleCompanion(name: Value('Renamed')));

      final p = await only(db);
      expect(p.company, 'PT Formcase');
      expect(p.waNumber, '628123456789');
      expect(p.metWhen, DateTime(2026, 3, 1));
    });

    test('editing a deleted person does not revive them', () async {
      final id = await seed(db);
      await db.softDelete(id);
      await db.updatePerson(id, const PeopleCompanion(name: Value('Ghost')));
      expect(await db.watchPeople().first, isEmpty);
    });
  });
}
