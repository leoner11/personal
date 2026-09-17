import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/people_screen.dart';
import 'package:personal_crm/ui/phone/person_detail_screen.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/channel.dart';
import 'package:personal_crm/domain/occasions.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/domain/tag_vocab.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // ⚠ The tag vocabulary is a TABLE now, and chips render from it. main()
    // seeds it before the first frame; a test database starts empty, so
    // without this every occasion chip is simply absent. refresh() rather
    // than bind() — a drift stream subscription outlives the test and trips
    // the pending-timer assertion.
    await seedBuiltInTags(db);
    await TagVocab.refresh(db);
  });
  tearDown(() async {
    await TagVocab.reset();
    await db.close();
  });

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

  group('phone people list', () {
    // Seeds one row and optionally a touch N days back, which is what the
    // recency buckets key on.
    Future<String> addRow(String name,
        {String? company, String? wa, String? wc, int? touchedDaysAgo}) async {
      final id = newId();
      await db.addPerson(PeopleCompanion.insert(
        id: Value(id),
        name: name,
        company: company == null ? const Value.absent() : Value(company),
        waNumber: wa == null ? const Value.absent() : Value(wa),
        wechatId: wc == null ? const Value.absent() : Value(wc),
        preferredChannel: Value(wa != null ? 'wa' : 'wechat'),
      ));
      if (touchedDaysAgo != null) {
        await db.into(db.touches).insert(TouchesCompanion.insert(
              personId: id,
              date: DateTime.now().subtract(Duration(days: touchedDaysAgo)),
            ));
      }
      return id;
    }

    Widget host() => MaterialApp(
        theme: buildTheme(Brightness.light), home: PhonePeopleScreen(db: db));

    testWidgets('groups by recency with counts, NEVER last', (tester) async {
      await tester.runAsync(() async {
        await addRow('Adil Rahman',
            company: 'Ralali', wa: '6281', touchedDaysAgo: 2);
        await addRow('Chen Wei', wc: 'chen_wx', touchedDaysAgo: 100);
        await addRow('Bu Sri');
      });
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('RECENT · 1'), findsOneWidget);
      expect(find.text('3–6 MO · 1'), findsOneWidget);
      expect(find.text('NEVER · 1'), findsOneWidget);
      // The quiet bucket goes last — leading with it buries the
      // relationships that still have a pulse.
      expect(tester.getTopLeft(find.text('NEVER · 1')).dy,
          greaterThan(tester.getTopLeft(find.text('RECENT · 1')).dy));
      // ⚠ Drain the drift cancel-timers before the body ends — the unmount
      // rule from phone_shell_test.dart. Ending cold wedges the whole file.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('search renders flat A–Z with no group headers',
        (tester) async {
      await tester.runAsync(() async {
        await addRow('Zaki', wa: '6282', touchedDaysAgo: 1);
        await addRow('Adi', wa: '6283');
      });
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'a');
      await tester.pumpAndSettle();

      expect(find.textContaining('MO'), findsNothing);
      expect(find.textContaining('RECENT'), findsNothing);
      expect(tester.getTopLeft(find.text('Adi')).dy,
          lessThan(tester.getTopLeft(find.text('Zaki')).dy));
      // Same drain rule as the recency test above — cold endings wedge.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('empty states are one line each', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('No one yet.'), findsOneWidget);

      await tester.runAsync(() => addRow('Adil Rahman', wa: '6281'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No match.'), findsOneWidget);
    // Drain the drift cancel-timers before the body ends (see recency test).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('long-press menu deletes through the house confirm',
        (tester) async {
      final id = await tester
          .runAsync(() => addRow('Chen Wei', wc: 'chen_wx')) as String;
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Chen Wei'));
      await tester.pumpAndSettle();
      // WeChat-only: the copy verb is there, WhatsApp is not.
      expect(find.text('Copy WeChat ID'), findsOneWidget);
      expect(find.text('Message on WhatsApp'), findsNothing);

      await tester.tap(find.text('Delete person'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Chen Wei?'), findsOneWidget);
      expect(
          find.text('The row is kept so the other device learns it is gone.'),
          findsOneWidget);

      await tester.tap(find.text('Delete'));
      // The row's 200ms collapse, then the removal timer that drops it.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Chen Wei'), findsNothing);
      final rows = await tester.runAsync(() => db.watchPeople().first);
      expect(rows, isEmpty);
      // Soft delete: the raw row is kept for the other device.
      final raw = await tester.runAsync(() =>
          (db.select(db.people)..where((p) => p.id.equals(id))).getSingle());
      expect(raw!.deletedAt != null, isTrue);
    // Drain (see recency test).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('trailing swipe reveals one channel action', (tester) async {
      await tester.runAsync(() async {
        await addRow('Adil Rahman', wa: '6281');
        await addRow('Bu Sri');
      });
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // A partial drag holds the action briefly — past the threshold it
      // would FIRE, and a test cannot open WhatsApp. The partial reveal is
      // enough to pin which verb the row carries.
      await tester.drag(find.text('Adil Rahman'), const Offset(-120, 0));
      await tester.pump();
      expect(find.text('Message'), findsOneWidget);
      await tester.pumpAndSettle(); // snaps back — the list does not mutate

      await tester.drag(find.text('Bu Sri'), const Offset(-120, 0));
      await tester.pump();
      // Bu Sri has no channel, so no second Dismissible ever exists — the
      // row simply does not swipe. (The snapped-back background of the first
      // row stays painted at rest, so findsNothing on its label would lie.)
      expect(find.byType(Dismissible), findsOneWidget);
      await tester.pumpAndSettle();
      // Drain (see recency test).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });

  group('phone person detail', () {
    Widget host(String id) => MaterialApp(
        theme: buildTheme(Brightness.light),
        home: PersonDetailScreen(db: db, personId: id));

    Future<String> seed(WidgetTester tester, {String? wa, String? wc}) async {
      final id = newId();
      await tester.runAsync(() => db.addPerson(PeopleCompanion.insert(
            id: Value(id),
            name: 'Adil Rahman',
            company: const Value('Ralali'),
            waNumber: wa == null ? const Value.absent() : Value(wa),
            wechatId: wc == null ? const Value.absent() : Value(wc),
          )));
      return id;
    }
    testWidgets('logging a touch writes immediately, no confirmation',
        (tester) async {
      final id = await seed(tester, wa: '6281');
      await tester.pumpWidget(host(id));
      await tester.pumpAndSettle();
      // Never touched yet — the subtitle says so in words.
      expect(find.text('Ralali · last touch never'), findsOneWidget);

      await tester.enterText(
          find.byType(TextField).first, 'called about the gudang');
      await tester.pump();
      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();

      // The row arrives on the stream; the subtitle re-buckets.
      expect(find.text('called about the gudang'), findsOneWidget);
      expect(find.text('Ralali · last touch today'), findsOneWidget);
      final touches =
          await tester.runAsync(() => db.watchTouches(id).first);
      expect(touches!.length, 1);
    // Drain (see recency test).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('timeline merges touches, notes and money flat',
        (tester) async {
      final id = await seed(tester, wa: '6281');
      await tester.runAsync(() async {
        await db.logTouch(id, 'called about the gudang');
        await db.into(db.notes).insert(NotesCompanion.insert(
              date: DateTime(2026, 8, 12),
              body: const Value('Grand plan\nsecond line'),
              personId: Value(id),
            ));
        await db.into(db.money).insert(MoneyCompanion.insert(
              date: DateTime(2026, 8, 12),
              direction: 'in',
              amountMinor: 120000,
              label: 'Deposit',
              status: const Value('actual'),
              personId: Value(id),
            ));
      });
      await tester.pumpWidget(host(id));
      await tester.pumpAndSettle();

      expect(find.text('called about the gudang'), findsOneWidget);
      // Notes carry the kind marker and only their first line.
      expect(find.text('(note) Grand plan'), findsOneWidget);
      // Money appends the right-aligned mono amount.
      expect(find.text('Deposit'), findsOneWidget);
      expect(find.text('¥1,200.00'), findsOneWidget);
    // Drain (see recency test).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('no channel means no pinned bar at all', (tester) async {
      final id = await seed(tester);
      await tester.pumpWidget(host(id));
      await tester.pumpAndSettle();
      expect(find.text('Message on WhatsApp'), findsNothing);
      expect(find.text('Copy WeChat ID'), findsNothing);
      // The screen itself is still all there.
      expect(find.text('TIMELINE'), findsOneWidget);
      // Drain (see recency test).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
