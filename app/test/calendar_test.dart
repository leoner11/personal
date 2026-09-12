import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/agenda.dart';
import 'package:flutter/material.dart';
import 'package:personal_crm/domain/ics.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/screens/calendar_screen.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final base = DateTime(2026, 10, 15);
  Future<List<AgendaEntry>> agenda() => loadAgenda(db,
      from: base.subtract(const Duration(days: 30)),
      to: base.add(const Duration(days: 30)));

  Future<String> person(String name) async {
    await db.addPerson(PeopleCompanion.insert(
        name: name, waNumber: const Value('628111')));
    return (await db.watchPeople().first).first.id;
  }

  group('agenda', () {
    test('gathers every dated kind into one list', () async {
      final pid = await person('Pak Arnold');
      await db.addMeeting(MeetingsCompanion.insert(
          title: 'Coffee', startsAt: DateTime(2026, 10, 16, 15, 0),
          personId: Value(pid)));
      await db.into(db.occasions).insert(OccasionsCompanion.insert(
          name: '国庆节', date: DateTime(2026, 10, 1), tag: 'guoqing'));
      await db.setPing(pid, DateTime(2026, 10, 20), note: 'follow up');
      // ⚠ Not logTouch() — it stamps DateTime.now(), which falls outside
      // this fixed test window. The date is the thing under test here.
      await db.into(db.touches).insert(TouchesCompanion.insert(
          personId: pid,
          date: DateTime(2026, 10, 10),
          oneLine: const Value('called about Odoo')));
      await db.addMoney(MoneyCompanion.insert(
          date: DateTime(2026, 10, 18), direction: 'in',
          amountMinor: 5000, label: 'Invoice'));

      final kinds = (await agenda()).map((e) => e.kind).toSet();
      expect(kinds, {'meeting', 'occasion', 'ping', 'touch', 'money'});
    });

    test('only meetings carry a clock', () async {
      // ⚠ Rendering a time against a festival invents precision the data does
      // not have — occasions are whole days.
      await db.addMeeting(MeetingsCompanion.insert(
          title: 'Coffee', startsAt: DateTime(2026, 10, 16, 15, 0)));
      await db.into(db.occasions).insert(OccasionsCompanion.insert(
          name: '国庆节', date: DateTime(2026, 10, 16), tag: 'guoqing'));

      final entries = await agenda();
      expect(entries.firstWhere((e) => e.kind == 'meeting').hasTime, isTrue);
      expect(entries.firstWhere((e) => e.kind == 'occasion').hasTime, isFalse);
    });

    test('a timed entry sorts above a whole-day one on the same day', () async {
      await db.into(db.occasions).insert(OccasionsCompanion.insert(
          name: '国庆节', date: DateTime(2026, 10, 16), tag: 'guoqing'));
      await db.addMeeting(MeetingsCompanion.insert(
          title: 'Coffee', startsAt: DateTime(2026, 10, 16, 15, 0)));

      final sameDay =
          (await agenda()).where((e) => e.day == DateTime(2026, 10, 16));
      expect(sameDay.first.kind, 'meeting');
    });

    test('entries outside the window are excluded', () async {
      await db.addMeeting(MeetingsCompanion.insert(
          title: 'Next year', startsAt: DateTime(2027, 10, 16, 15, 0)));
      expect(await agenda(), isEmpty);
    });

    test('a deleted meeting disappears', () async {
      await db.addMeeting(MeetingsCompanion.insert(
          id: const Value('m1'),
          title: 'Cancelled',
          startsAt: DateTime(2026, 10, 16, 15, 0)));
      expect((await agenda()).length, 1);

      await db.updateMeeting(
          'm1', MeetingsCompanion(deletedAt: Value(DateTime(2026, 10, 15))));
      expect(await agenda(), isEmpty);
    });

    test('byDay groups and keeps order', () async {
      await db.addMeeting(MeetingsCompanion.insert(
          title: 'A', startsAt: DateTime(2026, 10, 16, 9, 0)));
      await db.addMeeting(MeetingsCompanion.insert(
          title: 'B', startsAt: DateTime(2026, 10, 16, 15, 0)));
      await db.addMeeting(MeetingsCompanion.insert(
          title: 'C', startsAt: DateTime(2026, 10, 17, 9, 0)));

      final days = byDay(await agenda());
      expect(days.length, 2);
      expect(days[DateTime(2026, 10, 16)]!.map((e) => e.title).toList(),
          ['A', 'B']);
    });
  });

  group('sync keeps the clock', () {
    // ⚠ Found on a live server, not in review. The client sent a naive local
    // timestamp, Django (USE_TZ on) read it as UTC, and the value came back
    // as 15:00+00:00 — which parses to a UTC DateTime and displays as 23:00
    // in Haining. A meeting moved eight hours on its first sync, and every
    // whole-day row would shift a day for anyone west of UTC.
    test('a local time survives the UTC round trip', () {
      final local = DateTime(2026, 10, 16, 15, 0);

      // What the client now puts on the wire.
      final wire = local.toUtc().toIso8601String();
      expect(wire.endsWith('Z'), isTrue, reason: 'must declare it is UTC');

      // What comes back, and how the client now reads it.
      final parsed = DateTime.parse(wire).toLocal();
      expect(parsed, local);
    });

    test('a naive timestamp is exactly what used to break it', () {
      final local = DateTime(2026, 10, 16, 15, 0);
      final naive = local.toIso8601String();
      expect(naive.endsWith('Z'), isFalse);
      // The server appends +00:00 to a naive value, and this is the result.
      final asServerReadIt = DateTime.parse('${naive}Z').toLocal();
      expect(asServerReadIt, isNot(local),
          reason: 'this is the eight-hour shift, pinned so it stays fixed');
    });
  });

  group('ics export', () {
    Meeting meeting({String title = 'Coffee', String? location}) => Meeting(
          id: 'm1',
          title: title,
          startsAt: DateTime(2026, 10, 16, 15, 0),
          durationMinutes: 90,
          location: location,
          updatedAt: DateTime(2026, 10, 15),
        );

    test('local time, with no Z and no timezone block', () {
      // ⚠ A meeting at 15:00 means 15:00 where you are. Stamping it UTC
      // without declaring the zone is how an event lands hours out.
      final ics = icsFor(meeting());
      expect(ics, contains('DTSTART:20261016T150000'));
      expect(ics, contains('DTEND:20261016T163000'));
      expect(ics, isNot(contains('DTSTART:20261016T150000Z')));
    });

    test('the UID is stable, so re-export updates rather than duplicates', () {
      expect(icsFor(meeting()), contains('UID:m1@personal-crm'));
    });

    test('commas in a title are escaped, not left to truncate it', () {
      // ⚠ Comma is a field separator in iCalendar. Unescaped, everything
      // after it is silently dropped from the summary.
      final ics = icsFor(meeting(title: 'Coffee, then the warehouse'));
      expect(ics, contains(r'SUMMARY:Coffee\, then the warehouse'));
    });

    test('CRLF line endings, as RFC 5545 requires', () {
      expect(icsFor(meeting()), contains('\r\n'));
    });

    test('an empty location is omitted rather than written blank', () {
      expect(icsFor(meeting()), isNot(contains('LOCATION:')));
      expect(icsFor(meeting(location: 'their office')),
          contains('LOCATION:their office'));
    });
  });

  group('the calendar screen renders', () {
    // ⚠ The desktop rule: overflow only shows at the NARROW end. 396 is the
    // tightest the detail pane can get — 960 minimum window, minus the 200
    // sidebar, the 300 list and the padding.
    Widget host(Widget child, double width) => MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: Center(child: SizedBox(width: width, child: child)),
          ),
        );

    testWidgets('a full day of every kind fits the tightest pane',
        (tester) async {
      await tester.runAsync(() async {
        final pid = await person('Pak Arnold');
        await db.addMeeting(MeetingsCompanion.insert(
            title: 'Coffee and a look at the warehouse floor',
            startsAt: DateTime.now().add(const Duration(days: 1, hours: 4)),
            location: const Value('their office in Jakarta Selatan'),
            personId: Value(pid)));
        await db.setPing(pid, DateTime.now().add(const Duration(days: 1)),
            note: 'follow up on the Odoo compatibility question');
        await db.addMoney(MoneyCompanion.insert(
            date: DateTime.now().add(const Duration(days: 1)),
            direction: 'in',
            amountMinor: 2500000,
            label: 'Powerline milestone 3'));
      });

      await tester.pumpWidget(host(CalendarScreen(db: db), 396));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Calendar'), findsOneWidget);
    });

    testWidgets('an empty day says so rather than showing a blank page',
        (tester) async {
      await tester.pumpWidget(host(CalendarScreen(db: db), 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ⚠ Most days ARE empty. That is the normal condition of a calendar,
      // not something to apologise for.
      expect(find.text('Nothing on this day.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it looks like a calendar: weekday headers and 42 cells',
        (tester) async {
      await tester.pumpWidget(host(CalendarScreen(db: db), 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ⚠ Weeks start Monday — the whole user base is CN/ID/MY.
      expect(find.text('MON'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);

      // ⚠ Six rows always, never five. A month needing six and one needing
      // five would change the height of everything below it on every page.
      final today = DateTime.now();
      final first = DateTime(today.year, today.month);
      final start = first.subtract(Duration(days: first.weekday - 1));
      for (var i = 0; i < 42; i += 7) {
        expect(find.text('${start.add(Duration(days: i)).day}'), findsWidgets);
      }
    });

    testWidgets('picking a day changes the detail below the grid',
        (tester) async {
      // The grid answers "what shape is this month"; the list answers "what
      // is actually on this day". Neither alone is the feature.
      final when = DateTime(DateTime.now().year, DateTime.now().month, 15, 15, 0);
      await tester.runAsync(() => db.addMeeting(
          MeetingsCompanion.insert(title: 'Coffee with Pak Arnold', startsAt: when)));

      await tester.pumpWidget(host(CalendarScreen(db: db), 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('15').first);
      await tester.pump();

      expect(find.text('Coffee with Pak Arnold'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
