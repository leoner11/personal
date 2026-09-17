import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/agenda.dart';
import 'package:personal_crm/domain/tasks.dart';
import 'package:personal_crm/domain/today.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/capture_screen.dart';
import 'package:personal_crm/ui/phone/occasion_run_screen.dart';
import 'package:personal_crm/ui/phone/phone_shell.dart';
import 'package:personal_crm/ui/phone/phone_primitives.dart';
import 'package:personal_crm/ui/phone/tasks_list_screen.dart';
import 'package:personal_crm/ui/phone/today_screen.dart';
import 'package:personal_crm/ui/screens/tasks_screen.dart';
import 'package:personal_crm/ui/screens/today_screen.dart';
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

  DateTime day(int add) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + add);
  }

  Future<void> add(String title,
          {DateTime? due, DateTime? done, DateTime? created}) =>
      db.addTask(TasksCompanion.insert(
        id: Value(title),
        title: title,
        dueDate: Value(due),
        doneAt: Value(done),
        createdAt: Value(created ?? DateTime(2026, 9, 1)),
      ));

  group('grouping', () {
    final now = DateTime(2026, 9, 13, 15, 0);
    Task task(String title, {DateTime? due, DateTime? done, DateTime? created}) =>
        Task(
            id: title,
            title: title,
            createdAt: created ?? DateTime(2026, 9, 1),
            dueDate: due,
            doneAt: done,
            updatedAt: now);

    test('each task lands in exactly one group', () {
      final g = groupTasks([
        task('late', due: DateTime(2026, 9, 12)),
        task('today', due: DateTime(2026, 9, 13)),
        task('soon', due: DateTime(2026, 9, 14)),
        task('someday'),
        task('ticked', due: DateTime(2026, 9, 1), done: DateTime(2026, 9, 2)),
      ], now);
      List<String> titles(TaskGroup k) => g[k]!.map((t) => t.title).toList();

      expect(titles(TaskGroup.overdue), ['late']);
      expect(titles(TaskGroup.today), ['today']);
      expect(titles(TaskGroup.upcoming), ['soon']);
      expect(titles(TaskGroup.undated), ['someday']);
      // ⚠ Done beats overdue. A ticked-off task is finished, whatever its date.
      expect(titles(TaskGroup.done), ['ticked']);
    });

    test('due today is not overdue at 15:00', () {
      // ⚠ Due dates are midnight. Comparing timestamps instead of days would
      // call everything due today "overdue" from 00:01.
      expect(groupOf(task('x', due: DateTime(2026, 9, 13)), now),
          TaskGroup.today);
    });

    test('an undated list keeps the order it was written in', () {
      final g = groupTasks([
        task('third', created: DateTime(2026, 9, 3)),
        task('first', created: DateTime(2026, 9, 1)),
        task('second', created: DateTime(2026, 9, 2)),
      ], now);
      expect(g[TaskGroup.undated]!.map((t) => t.title),
          ['first', 'second', 'third']);
    });

    test('the most recently ticked comes first in done', () {
      final g = groupTasks([
        task('earlier', done: DateTime(2026, 9, 10)),
        task('just now', done: DateTime(2026, 9, 13)),
      ], now);
      expect(g[TaskGroup.done]!.map((t) => t.title), ['just now', 'earlier']);
    });

    test('due labels', () {
      expect(dueLabel(DateTime(2026, 9, 10), now), '3d overdue');
      expect(dueLabel(DateTime(2026, 9, 12), now), 'yesterday');
      expect(dueLabel(DateTime(2026, 9, 13), now), 'today');
      expect(dueLabel(DateTime(2026, 9, 14), now), 'tomorrow');
    });
  });

  group('writes', () {
    test('ticking off stamps doneAt and updatedAt, unticking clears it',
        () async {
      await db.addTask(TasksCompanion.insert(
          id: const Value('t1'),
          title: 'Call Pak Budi',
          updatedAt: Value(DateTime(2026, 1, 1))));

      await db.setTaskDone('t1', true);
      var t = (await db.allTasks()).single;
      expect(t.doneAt, isNotNull);
      // ⚠ Without the updatedAt stamp the tick never syncs — the server pulls
      // on updated_at > since.
      expect(t.updatedAt.isAfter(DateTime(2026, 1, 1)), isTrue);

      await db.setTaskDone('t1', false);
      t = (await db.allTasks()).single;
      expect(t.doneAt, isNull);
    });

    test('links are queryable from both ends', () async {
      await db.addTask(TasksCompanion.insert(
          title: 'Quotation',
          personId: const Value('p1'),
          engagementId: const Value('e1')));
      await db.addTask(TasksCompanion.insert(title: 'Unlinked'));

      expect((await db.watchTasksForPerson('p1').first).map((t) => t.title),
          ['Quotation']);
      expect(
          (await db.watchTasksForEngagement('e1').first).map((t) => t.title),
          ['Quotation']);
    });
  });

  group('Today', () {
    test('overdue and due today appear; tomorrow and undated do not', () async {
      await add('overdue', due: day(-2));
      await add('today', due: day(0));
      await add('tomorrow', due: day(1));
      await add('someday');

      final d = await loadToday(db);
      // Overdue first — it has waited longest.
      expect(d.tasks.map((t) => t.title), ['overdue', 'today']);
    });

    test('a done task leaves Today', () async {
      await add('sent', due: day(0), done: DateTime.now());
      expect((await loadToday(db)).tasks, isEmpty);
    });

    test('a deleted task leaves Today', () async {
      await add('gone', due: day(0));
      await db.updateTask('gone', TasksCompanion(deletedAt: Value(DateTime.now())));
      expect((await loadToday(db)).tasks, isEmpty);
    });

    test('a day holding only a task is not an empty day', () async {
      // ⚠ Both shells show the empty state off isEmpty. A task that counted
      // for nothing there would render a blank screen instead.
      await add('only thing', due: day(0));
      final d = await loadToday(db);
      expect(d.isEmpty, isFalse);
    });
  });

  group('calendar', () {
    Future<List<AgendaEntry>> agenda() =>
        loadAgenda(db, from: day(-30), to: day(30));

    test('a dated task is on its day, and carries the row', () async {
      await add('Send quotation', due: day(3));
      final e = (await agenda()).single;
      expect(e.kind, 'task');
      expect(e.day, day(3));
      expect(e.task?.id, 'Send quotation');
      expect(e.hasTime, isFalse, reason: 'a task is due on a day, not at 09:00');
    });

    test('an undated task is not on the calendar', () async {
      await add('someday');
      expect(await agenda(), isEmpty);
    });

    test('a done task stays on its day, marked done', () async {
      await add('sent', due: day(-1), done: DateTime.now());
      expect((await agenda()).single.subtitle, startsWith('done'));
    });
  });

  group('screens', () {
    Widget host(Widget child, {double width = 900}) => MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: Center(child: SizedBox(width: width, child: child)),
          ),
        );

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('typing a line and pressing Enter writes an undated task',
        (tester) async {
      await tester.pumpWidget(host(TasksScreen(db: db)));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Buy mooncakes');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      final rows = (await tester.runAsync(db.allTasks))!;
      expect(rows.map((t) => t.title), ['Buy mooncakes']);
      expect(rows.single.dueDate, isNull);
      // Cleared, ready for the next line.
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '');
      await unmount(tester);
    });

    testWidgets('ticking the box marks the row done in the database',
        (tester) async {
      await tester.runAsync(() => add('Call Pak Budi'));
      await tester.pumpWidget(host(TasksScreen(db: db)));
      await settle(tester);

      expect(find.byType(TaskCheck), findsOneWidget);
      await tester.tap(find.byType(TaskCheck));
      await settle(tester);

      final t = (await tester.runAsync(db.allTasks))!.single;
      expect(t.doneAt, isNotNull);
      await unmount(tester);
    });

    testWidgets('every group fits the tightest pane', (tester) async {
      await tester.runAsync(() async {
        await db.addPerson(PeopleCompanion.insert(
            id: const Value('p1'), name: 'Pak Andi Wijaya of PT Formcase'));
        for (final (title, due) in [
          ('Send the Odoo compatibility quotation to the warehouse team', day(-4)),
          ('Confirm the 中秋节 gift list and the delivery address', day(0)),
          ('Follow up with Pak Budi about the second milestone invoice', day(6)),
          ('Write down everything from the site visit before it fades', null),
        ]) {
          await db.addTask(TasksCompanion.insert(
              title: title, dueDate: Value(due), personId: const Value('p1')));
        }
        await add('done one', done: DateTime.now());
      });

      await tester.pumpWidget(host(TasksScreen(db: db), width: 396));
      await settle(tester);

      expect(find.text('OVERDUE · 1'), findsOneWidget);
      expect(find.text('NO DATE · 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('Done on Today ticks the task off', (tester) async {
      await tester.runAsync(() => add('Send quotation', due: day(0)));
      await tester.pumpWidget(host(
          TodayScreen(db: db, onCount: (_) {}, onGo: (_) {})));
      await settle(tester);

      expect(find.text('Send quotation'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      final t = (await tester.runAsync(db.allTasks))!.single;
      expect(t.doneAt, isNotNull);
      await unmount(tester);
    });
  });

  /// ── The v2 phone core loop ────────────────────────────────────────────
  ///
  /// ⚠ The phone holds task writes for the 200ms exit animation, and drift
  /// needs a real-async window inside testWidgets (see phone_shell_test's
  /// traps). [phoneBeat] advances the fake clock past the hold, gives the
  /// write its real time, then fires the exit-sweep timer. Order matters.
  group('phone', () {
    setUp(() => phoneTodayCount.value = 0);

    /// ⚠ The REAL test view must be phone-shaped, not just the MediaQuery
    /// data. Hit testing clips to the actual viewport (600pt tall by
    /// default), so a MediaQuery-only override puts a sheet's pinned buttons
    /// at y≈1129 where tap() silently cannot reach them.
    Widget phoneHost(WidgetTester tester, Widget child) {
      tester.view.physicalSize = const Size(1170, 2532); // 390x844 @3x
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      return MaterialApp(theme: buildTheme(Brightness.light), home: child);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    /// The full phone beat: check hold (~340ms) + collapse (200ms) + the
    /// write and the post-load sweep (~280ms) all have to land inside it.
    Future<void> phoneBeat(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 260));
      await settle(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('Today quick-add dates the task today and stays clear',
        (tester) async {
      await tester.pumpWidget(phoneHost(tester, PhoneTodayScreen(db: db)));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Buy mooncakes');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await phoneBeat(tester);

      final rows = (await tester.runAsync(() => db.allTasks()))!;
      expect(rows.single.title, 'Buy mooncakes');
      // ⚠ TODAY dates the add — an undated row would vanish off the deck
      // the instant it was typed, which reads as data loss (§6).
      expect(rows.single.dueDate, day(0));
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          '');
      await unmount(tester);
    });

    testWidgets('the Today badge follows the deck on every load',
        (tester) async {
      await tester.pumpWidget(phoneHost(tester, PhoneTodayScreen(db: db)));
      await settle(tester);
      // Fresh db: the runway warning is the one permanent resident (§8.7),
      // so even an empty deck counts 1 — the badge never lies about Today.
      expect(phoneTodayCount.value, 1);

      await tester.enterText(find.byType(TextField).first, 'One thing');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await phoneBeat(tester);
      expect(phoneTodayCount.value, 2);

      await tester.tap(find.byType(PhoneTaskCheck));
      await phoneBeat(tester);
      expect(phoneTodayCount.value, 1);
      await unmount(tester);
    });

    testWidgets('checking a task on Today ticks it off and empties the deck',
        (tester) async {
      await tester.runAsync(() => add('Send quotation', due: day(0)));
      await tester.pumpWidget(phoneHost(tester, PhoneTodayScreen(db: db)));
      await settle(tester);
      expect(find.text('Send quotation'), findsOneWidget);

      await tester.tap(find.byType(PhoneTaskCheck));
      await phoneBeat(tester);

      final t = (await tester.runAsync(() => db.allTasks()))!.single;
      expect(t.doneAt, isNotNull);
      // Done tasks LEAVE the deck — no lingering struck-through row (§6).
      expect(find.text('Send quotation'), findsNothing);
      await unmount(tester);
    });

    testWidgets('the list quick-add writes an undated task and keeps focus',
        (tester) async {
      await tester.pumpWidget(phoneHost(tester, PhoneTasksScreen(db: db)));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Buy mooncakes');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await phoneBeat(tester);

      final rows = (await tester.runAsync(() => db.allTasks()))!;
      // Desktop parity: the LIST stays undated (only Today dates the add).
      expect(rows.single.dueDate, isNull);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, '');
      // ⚠ Keeps focus — a checklist is written several lines at a time.
      expect(field.focusNode!.hasFocus, isTrue);
      await unmount(tester);
    });

    testWidgets('checking a list task files it under DONE; un-check returns it',
        (tester) async {
      await tester.runAsync(() => add('Call Pak Budi'));
      await tester.pumpWidget(phoneHost(tester, PhoneTasksScreen(db: db)));
      await settle(tester);
      expect(find.text('NO DATE · 1'), findsOneWidget);

      await tester.tap(find.byType(PhoneTaskCheck));
      await phoneBeat(tester);
      expect(
          (await tester.runAsync(() => db.allTasks()))!.single.doneAt,
          isNotNull);
      expect(find.text('NO DATE · 1'), findsNothing);
      // Collapsed by default — done is the record, not the list.
      expect(find.text('DONE · 1'), findsOneWidget);
      expect(find.text('Call Pak Budi'), findsNothing);

      await tester.tap(find.text('Show'));
      await settle(tester);
      expect(find.text('Call Pak Budi'), findsOneWidget);

      await tester.tap(find.byType(PhoneTaskCheck));
      await phoneBeat(tester);
      expect(
          (await tester.runAsync(() => db.allTasks()))!.single.doneAt, isNull);
      expect(find.text('NO DATE · 1'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a trailing swipe completes the task', (tester) async {
      await tester.runAsync(() => add('Send the quotation', due: day(-3)));
      await tester.pumpWidget(phoneHost(tester, PhoneTasksScreen(db: db)));
      await settle(tester);

      await tester.drag(find.text('Send the quotation'), const Offset(-480, 0));
      await phoneBeat(tester);

      final t = (await tester.runAsync(() => db.allTasks()))!.single;
      expect(t.doneAt, isNotNull);
      await unmount(tester);
    });

    testWidgets('the edit sheet soft-deletes behind the house confirm',
        (tester) async {
      await tester.runAsync(() => add('Renew the domain', due: day(2)));
      await tester.pumpWidget(phoneHost(tester, PhoneTasksScreen(db: db)));
      await settle(tester);

      await tester.tap(find.text('Renew the domain'));
      // The sheet's spring starts a frame after the tap: pump past the full
      // 420ms duration or every pinned button sits mid-flight, off-screen.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Edit task'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      // The house panel asks; the confirm is a ghost in danger.text.
      expect(find.text('Delete Renew the domain?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await phoneBeat(tester);

      // Soft delete: the row is kept, but it has left every list.
      expect(await tester.runAsync(() => db.allTasks()), isEmpty);
      await unmount(tester);
    });

    testWidgets('the new-person sheet saves name + one channel and pops',
        (tester) async {
      await tester.pumpWidget(phoneHost(tester, Builder(
        builder: (context) => Center(
          child: PhoneBtn('Add someone',
              onPressed: () => showNewPersonSheet(context, db)),
        ),
      )));
      await tester.pump();
      await tester.tap(find.text('Add someone'));
      // Same spring-starts-late rule as the edit sheet above.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('New person'), findsOneWidget);

      // One channel required: a name alone cannot save.
      await tester.enterText(find.byType(TextField).at(0), 'Bu Sri');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(await tester.runAsync(() => db.allPeople()), isEmpty);

      await tester.enterText(find.byType(TextField).at(1), '628999');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await phoneBeat(tester);

      final people =
          await tester.runAsync(() => db.allPeople()) ?? const <Person>[];
      expect(people.single.name, 'Bu Sri');
      expect(people.single.waNumber, '628999');
      // WhatsApp wins — it is the channel that deep-links.
      expect(people.single.preferredChannel, 'wa');
      // metWhen = now: capture stamps the meeting the moment it happened.
      expect(people.single.metWhen, isNotNull);
      // Pops itself on save — the person lands in the list you came from.
      expect(find.text('New person'), findsNothing);
      await unmount(tester);
    });

    testWidgets('sent state derives from the touch log window', (tester) async {
      const line = 'sent 中秋节 Mid-Autumn wishes';
      await tester.runAsync(() async {
        await db.addPerson(PeopleCompanion.insert(
            id: const Value('p1'),
            name: 'Pak Chen',
            occasionTags: const Value(<String>['midAutumn'])));
        await db.addPerson(PeopleCompanion.insert(
            id: const Value('p2'),
            name: 'Pak Andi',
            occasionTags: const Value(<String>['midAutumn'])));
        // The occasion is 12 days out, so the run window opened 2 days ago.
        // Pak Chen's touch is 8 days old — LAST YEAR's entry must not count
        // (§7: derived, not remembered, and bounded by the window).
        await db.into(db.touches).insert(TouchesCompanion.insert(
            personId: 'p1',
            date: day(-8),
            oneLine: const Value(line)));
        await db.into(db.touches).insert(TouchesCompanion.insert(
            personId: 'p2',
            date: DateTime.now(),
            oneLine: const Value(line)));
      });

      await tester.pumpWidget(phoneHost(tester, OccasionRunScreen(
        db: db,
        occasion: Occasion(
          id: 'occ1',
          name: '中秋节 Mid-Autumn',
          date: day(12),
          tag: 'midAutumn',
          updatedAt: DateTime.now(),
        ),
      )));
      await settle(tester);

      expect(find.text('1 of 2 sent'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      await unmount(tester);
    });
  });
}
