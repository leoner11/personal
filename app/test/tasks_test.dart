import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/agenda.dart';
import 'package:personal_crm/domain/tasks.dart';
import 'package:personal_crm/domain/today.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/screens/tasks_screen.dart';
import 'package:personal_crm/ui/screens/today_screen.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

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
          title: 'Call Lucy',
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
      await tester.runAsync(() => add('Call Lucy'));
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
          ('Follow up with Lucy about the second milestone invoice', day(6)),
          ('Write down everything from the Haining trip before it fades', null),
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
}
