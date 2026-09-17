import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/money_totals.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/money_screen.dart';
import 'package:personal_crm/ui/phone/notes_screen.dart';
import 'package:personal_crm/ui/phone/phone_primitives.dart';
import 'package:personal_crm/ui/phone/phone_shell.dart';
import 'package:personal_crm/ui/phone/projects_screen.dart';
import 'package:personal_crm/ui/phone/review_screen.dart';
import 'package:personal_crm/ui/phone/tasks_list_screen.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/domain/tag_vocab.dart';

/// Money, Projects and Notes on the phone.
///
/// ⚠ Same two drift-under-FakeAsync traps as `phone_shell_test.dart`: await
/// drift inside `tester.runAsync`, and unmount the tree inside the test. Both
/// present as "the file hangs with no output".
///
/// ⚠ And the same assertion rule. Do not assert on what is findable when
/// every tab is mounted in an IndexedStack and the nav bar renders every tab's
/// label — two tests in the shell file were vacuous for exactly that reason.
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

  Widget host(Widget child) => MaterialApp(
    theme: buildTheme(Brightness.light),
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: child,
    ),
  );

  PhoneTab currentTab(WidgetTester tester) =>
      PhoneTab.values[tester
          .widget<IndexedStack>(find.byType(IndexedStack))
          .index!];

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // ⚠ v2: Today (mounted by the shell) schedules a ~280ms post-collapse
    // sweep on load — the drain must cover one full sweep window.
    await tester.pump(const Duration(milliseconds: PM.clearMs + 120));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<R> io<R>(WidgetTester tester, Future<R> Function() body) async =>
      (await tester.runAsync(body)) as R;

  Future<void> addMoney(
    WidgetTester tester, {
    required String label,
    required int minor,
    String cur = 'CNY',
    String dir = 'in',
    String status = 'actual',
    DateTime? date,
  }) => io(
    tester,
    () => db.addMoney(
      MoneyCompanion.insert(
        date: date ?? DateTime(2026, 9, 11),
        direction: dir,
        amountMinor: minor,
        currency: Value(cur),
        label: label,
        status: Value(status),
      ),
    ),
  );

  group('MoneyTotals', () {
    // Pure logic, and the reason it was extracted: the Mac screen, the phone
    // screen and the Review hub all derive these and had begun to do it three
    // separate times.
    MoneyRow row(String dir, String status, int minor, [String cur = 'CNY']) =>
        MoneyRow(
          id: 'x$minor$dir$status$cur',
          date: DateTime(2026, 9, 11),
          direction: dir,
          amountMinor: minor,
          currency: cur,
          label: 'l',
          status: status,
          updatedAt: DateTime(2026, 9, 11),
        );

    test('balance counts actuals only, signed by direction', () {
      final t = MoneyTotals.of([
        row('in', 'actual', 10000),
        row('out', 'actual', 4000),
        // Expected must not move the balance — that is the whole distinction.
        row('in', 'actual', 500),
        row('in', 'expected', 999999),
      ]);
      expect(t.balances['CNY'], 10000 - 4000 + 500);
    });

    test('currencies are kept apart and never summed together', () {
      final t = MoneyTotals.of([
        row('in', 'actual', 10000),
        row('in', 'actual', 700, 'USD'),
      ]);
      // ⚠ There is no exchange rate in this app. One combined number would be
      // a number that is not true.
      expect(t.balances, {'CNY': 10000, 'USD': 700});
    });

    test('expected splits by direction and stays unsigned', () {
      final t = MoneyTotals.of([
        row('in', 'expected', 800),
        row('out', 'expected', 300),
        row('out', 'expected', 200),
      ]);
      expect(t.inExpected, {'CNY': 800});
      expect(t.outExpected, {'CNY': 500});
      expect(t.balances, isEmpty);
    });

    test('no rows is an empty balance, not a zero', () {
      // ⚠ "¥0.00" claims the accounts are empty. "—" says nothing is recorded.
      expect(MoneyTotals.of(const []).balances, isEmpty);
    });
  });

  group('the Review tab', () {
    testWidgets('Review is the fifth tab and Capture is still the default', (
      tester,
    ) async {
      await tester.pumpWidget(host(PhoneShell(db: db)));
      await tester.pump();
      expect(currentTab(tester), PhoneTab.capture);

      // v2: Calendar took the fourth slot (it absorbs the occasions browse),
      // pushing Review to fifth — still one deliberate tap away.
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      expect(currentTab(tester), PhoneTab.calendar);

      await tester.tap(find.text('Review'));
      await tester.pump();
      expect(currentTab(tester), PhoneTab.review);
      await unmount(tester);
    });

    testWidgets('shows the balance on the hub, not just a row count', (
      tester,
    ) async {
      await addMoney(tester, label: 'Powerline M3', minor: 2500000);
      await tester.pumpWidget(host(PhoneReviewScreen(db: db)));
      await tester.pump();
      await tester.pump();

      // The point of the money screen is one number seen often; the hub
      // showing it means one fewer tap to see it.
      expect(find.textContaining('25,000'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('counts are singular at one', (tester) async {
      await io(
        tester,
        () => db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: const Value('n1'),
                date: DateTime(2026, 9, 11),
              ),
            ),
      );
      await tester.pumpWidget(host(PhoneReviewScreen(db: db)));
      await tester.pump();
      await tester.pump();

      expect(find.text('1 note'), findsOneWidget);
      expect(find.text('0 projects'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the Tasks row counts open tasks and pushes the list',
        (tester) async {
      await io(
        tester,
        () => db.addTask(TasksCompanion.insert(
          title: 'open one',
          createdAt: Value(DateTime.now()),
        )),
      );
      await io(
        tester,
        () async {
          await db.addTask(TasksCompanion.insert(
            title: 'done one',
            createdAt: Value(DateTime.now()),
          ));
          final done =
              (await db.watchTasks().first).firstWhere(
            (t) => t.title == 'done one',
          );
          await db.setTaskDone(done.id, true);
        },
      );
      await tester.pumpWidget(host(PhoneReviewScreen(db: db)));
      await tester.pump();
      await tester.pump();

      // Open tasks are what the hub counts; done ones are history.
      expect(find.text('1 task'), findsOneWidget);
      expect(find.text('2 tasks'), findsNothing);

      await tester.tap(find.text('Tasks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PhoneTasksScreen), findsOneWidget);
      await unmount(tester);
    });
  });

  group('money', () {
    testWidgets('an empty ledger says so instead of showing ¥0.00', (
      tester,
    ) async {
      await tester.pumpWidget(host(PhoneMoneyScreen(db: db)));
      await tester.pump();
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
      expect(find.text('Nothing has moved yet.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an expected section is hidden entirely, not rendered empty', (
      tester,
    ) async {
      await addMoney(tester, label: 'Paid already', minor: 100);
      await tester.pumpWidget(host(PhoneMoneyScreen(db: db)));
      await tester.pump();
      await tester.pump();

      // ⚠ On a phone an empty section is a whole screenful of nothing.
      expect(find.text('COMING IN'), findsNothing);
      expect(find.text('COMING OUT'), findsNothing);

      await addMoney(
        tester,
        label: 'Invoice 12',
        minor: 5000,
        status: 'expected',
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('COMING IN'), findsOneWidget);
      expect(find.text('COMING OUT'), findsNothing);
      await unmount(tester);
    });

    testWidgets('settling an expected row moves it into the balance', (
      tester,
    ) async {
      await addMoney(
        tester,
        label: 'Invoice 12',
        minor: 5000,
        status: 'expected',
      );
      await tester.pumpWidget(host(PhoneMoneyScreen(db: db)));
      await tester.pump();
      await tester.pump();
      expect(find.text('—'), findsOneWidget, reason: 'expected is not cash');

      await io(tester, () => db.settleMoney('__none__'));
      final rows = await io(tester, () => db.watchMoney().first);
      await io(tester, () => db.settleMoney(rows.single.id));
      await tester.pump();
      await tester.pump();

      expect(find.text('—'), findsNothing);
      expect(find.text('COMING IN'), findsNothing);
      await unmount(tester);
    });

    testWidgets('an actual row is tappable — the correction path exists', (
      tester,
    ) async {
      // v2 closed the dead-row defect: an actual row used to have no tap at
      // all, so a mistyped amount was stuck forever on the phone.
      await addMoney(tester, label: 'Paid already', minor: 100);
      await tester.pumpWidget(host(PhoneMoneyScreen(db: db)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Paid already'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Edit money row'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the ledger is a table: months grouped, actuals only',
        (tester) async {
      await addMoney(tester, label: 'Invoice 12', minor: 5000);
      await addMoney(tester, label: 'Coffee', minor: 3800, dir: 'out');
      await addMoney(
        tester,
        label: 'Old invoice',
        minor: 1200,
        date: DateTime(2026, 8, 4),
      );
      // Expected stays in COMING IN / COMING OUT — a ledger records what
      // happened, not projections.
      await addMoney(
        tester,
        label: 'Rent',
        minor: 900000,
        status: 'expected',
      );
      await tester.pumpWidget(host(PhoneMoneyScreen(db: db)));
      await tester.pump();
      await tester.pump();

      // Table grammar: one header row, month group headers, net lines.
      expect(find.text('DATE'), findsOneWidget);
      expect(find.text('IN/OUT'), findsOneWidget);
      expect(find.text('AMOUNT'), findsOneWidget);
      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('Net · CNY'), findsNWidgets(2));

      // Direction is a word in its own column, never a colour.
      expect(find.text('in'), findsNWidgets(2));
      expect(find.text('out'), findsOneWidget);

      // Expected rows appear exactly once — in COMING OUT, not in the
      // ledger.
      expect(find.text('Rent'), findsOneWidget);
      // ⚠ And settling moved rows keep the read: actuals only, so an
      // expected row settled to actual joins its month group.
      await unmount(tester);
    });
  });

  group('projects', () {
    testWidgets('rows are grouped by type, because a jv is not a deal', (
      tester,
    ) async {
      await io(
        tester,
        () => db
            .into(db.engagements)
            .insert(
              EngagementsCompanion.insert(
                name: 'Ralali',
                type: const Value('jv'),
              ),
            ),
      );
      await io(
        tester,
        () => db
            .into(db.engagements)
            .insert(
              EngagementsCompanion.insert(
                name: 'NaraHome ERP',
                type: const Value('deal'),
              ),
            ),
      );

      await tester.pumpWidget(host(PhoneProjectsScreen(db: db)));
      await tester.pump();
      await tester.pump();

      // The group headers are the distinction the table exists for.
      expect(find.text('DEAL'), findsOneWidget);
      expect(find.text('JV'), findsOneWidget);
      // Types with no rows are not rendered at all.
      expect(find.text('CLIENT'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a project with no value shows no amount, never zero', (
      tester,
    ) async {
      await io(
        tester,
        () => db
            .into(db.engagements)
            .insert(
              EngagementsCompanion.insert(
                name: 'Unpriced lead',
                type: const Value('lead'),
              ),
            ),
      );
      await tester.pumpWidget(host(PhoneProjectsScreen(db: db)));
      await tester.pump();
      await tester.pump();

      // ⚠ An empty value means "unknown", not zero. Rendering ¥0.00 would
      // claim the deal is worth nothing.
      expect(find.textContaining('0.00'), findsNothing);
      await unmount(tester);
    });
  });

  group('notes', () {
    testWidgets('the tag filter is hidden until a tag exists', (tester) async {
      await io(
        tester,
        () => db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: const Value('n1'),
                date: DateTime(2026, 9, 11),
              ),
            ),
      );
      await tester.pumpWidget(host(PhoneNotesScreen(db: db)));
      await tester.pump();
      await tester.pump();

      // A filter row offering only "all" is furniture.
      expect(find.text('all'), findsNothing);

      await io(
        tester,
        () => db.updateNote('n1', const NotesCompanion(tag: Value('thesis'))),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('all'), findsOneWidget);
      expect(find.text('thesis'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('a note with an empty body lists as untitled, not blank', (
      tester,
    ) async {
      await io(
        tester,
        () => db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: const Value('n1'),
                date: DateTime(2026, 9, 11),
              ),
            ),
      );
      await tester.pumpWidget(host(PhoneNotesScreen(db: db)));
      await tester.pump();
      await tester.pump();

      expect(find.text('untitled'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the editor autosaves on pause, with no save button', (
      tester,
    ) async {
      await io(
        tester,
        () => db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: const Value('n1'),
                date: DateTime(2026, 9, 11),
              ),
            ),
      );
      final note = (await io(tester, () => db.watchNotes().first)).single;

      await tester.pumpWidget(host(PhoneNoteEditor(db: db, note: note)));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'thesis draft');
      // ⚠ The 600ms debounce is a real Timer under the fake clock; pumping
      // past it is what proves the save fires without any button.
      await tester.pump(const Duration(milliseconds: 700));

      final saved = await io(tester, () => db.watchNotes().first);
      expect(saved.single.body, 'thesis draft');
      await unmount(tester);
    });

    testWidgets('deleting cancels the pending autosave', (tester) async {
      // ⚠ Otherwise the debounce fires after the soft delete and writes the
      // body back onto a deleted row.
      await io(
        tester,
        () => db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: const Value('n1'),
                date: DateTime(2026, 9, 11),
              ),
            ),
      );
      final note = (await io(tester, () => db.watchNotes().first)).single;

      await tester.pumpWidget(host(PhoneNoteEditor(db: db, note: note)));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'about to go');
      // Delete before the debounce has fired.
      await io(tester, () => db.softDeleteRow(db.notes, 'n1'));
      await tester.pump(const Duration(milliseconds: 700));

      final left = await io(tester, () => db.watchNotes().first);
      expect(left, isEmpty, reason: 'the autosave must not resurrect it');
      await unmount(tester);
    });

    testWidgets('the editor is a pushed full page, not a sheet',
        (tester) async {
      await io(
        tester,
        () => db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: const Value('n1'),
                date: DateTime(2026, 9, 11),
              ),
            ),
      );
      await tester.pumpWidget(host(PhoneNotesScreen(db: db)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('untitled'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PhoneNoteEditor), findsOneWidget);
      expect(find.byType(PhoneSheet), findsNothing);
      await unmount(tester);
    });

    testWidgets('Done flushes pending edits and pops', (tester) async {
      await io(
        tester,
        () => db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: const Value('n1'),
                date: DateTime(2026, 9, 11),
              ),
            ),
      );
      await tester.pumpWidget(host(PhoneNotesScreen(db: db)));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('untitled'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField).first, 'flushed line');
      // No debounce wait: Done must save NOW, not on the 600ms timer.
      await tester.tap(find.text('Done'));
      // Flush resolves across an async gap, so the pop starts a frame after
      // the tap — then the transition itself must finish.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      final saved = await io(tester, () => db.watchNotes().first);
      expect(saved.single.body, 'flushed line');
      expect(find.byType(PhoneNoteEditor), findsNothing);
      await unmount(tester);
    });

    testWidgets('delete sits behind the details disclosure and confirms',
        (tester) async {
      await io(
        tester,
        () => db
            .into(db.notes)
            .insert(
              NotesCompanion.insert(
                id: const Value('n1'),
                date: DateTime(2026, 9, 11),
              ),
            ),
      );
      await tester.pumpWidget(host(PhoneNotesScreen(db: db)));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('untitled'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Details'));
      await tester.pump(const Duration(milliseconds: PM.clearMs + 50));
      await tester.tap(find.text('Delete note'));
      // The confirm is a sheet: it springs a frame after the tap and is
      // mid-flight at 60ms — pump the full spring before tapping it, or the
      // tap only WARNS and hits nothing.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      // Confirm exit (~240ms) + page pop transition (~300ms) both finish.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      final left = await io(tester, () => db.watchNotes().first);
      expect(left, isEmpty, reason: 'soft delete behind the house confirm');
      expect(find.byType(PhoneNoteEditor), findsNothing);
      await unmount(tester);
    });
  });
}
