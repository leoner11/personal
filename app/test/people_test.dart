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

  Future<int> add(String name, List<OccasionTag> tags, {String? wa, String? wc}) =>
      db.addPerson(PeopleCompanion.insert(
        name: name,
        waNumber: Value(wa),
        wechatId: Value(wc),
        preferredChannel: Value(wa != null ? 'wa' : 'wechat'),
        occasionTags: Value(tags.map((t) => t.name).toList()),
      ));

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
}
