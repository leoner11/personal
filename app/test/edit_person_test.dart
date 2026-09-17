import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/add_person_sheet.dart';
import 'package:personal_crm/ui/phone/edit_person_sheet.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/domain/tag_vocab.dart';

/// The Mac edit sheet. ⚠ Editing a person was impossible in either shell until
/// 12 Sep — the only write was a soft delete — so these pin the behaviour that
/// made the workaround dangerous: delete-and-re-add mints a new UUID and
/// silently detaches every touch, note and money row pointing at the old one.
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

  Widget host(Widget child) =>
      MaterialApp(theme: buildTheme(Brightness.light), home: child);

  Future<Person> seed({String? wa, List<String> tags = const []}) async {
    await db.addPerson(PeopleCompanion.insert(
      name: 'Pak Andi',
      company: const Value('PT Formcase'),
      waNumber: Value(wa),
      metWhen: Value(DateTime(2026, 3, 1)),
      occasionTags: Value(tags),
    ));
    return (await db.watchPeople().first).single;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// ⚠ The sheet is taller than the default 800x600 test surface, so Save
  /// starts off-screen and a bare tap() silently hits nothing — which is how
  /// the first version of these tests "passed" while asserting nothing at all.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Save'), 120, scrollable: find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).last);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
  }

  /// ⚠ Save is async and the tap does not await it. Reading straight after
  /// races the write — which is how the rename test first "passed" while
  /// asserting nothing. Give it a real moment on the real clock.
  Future<List<Person>> peopleAfterSave(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return db.watchPeople().first;
      }))!;

  String textOf(WidgetTester tester, int i) =>
      tester.widget<TextField>(find.byType(TextField).at(i)).controller!.text;

  testWidgets('opens prefilled, and says Edit rather than Add', (tester) async {
    final p = await tester.runAsync(() => seed(wa: '628123456789')) as Person;
    await tester.pumpWidget(host(AddPersonSheet(db: db, existing: p)));
    await tester.pump();

    expect(find.text('Edit person'), findsOneWidget);
    expect(find.text('Add person'), findsNothing);
    expect(textOf(tester, 0), 'Pak Andi');
    expect(textOf(tester, 1), 'PT Formcase');
    await unmount(tester);
  });

  testWidgets('an edit can be saved without a channel, with a warning',
      (tester) async {
    // ⚠ Capture demands a channel; editing does not. Eleven people were
    // entered from a list of names with no numbers, and demanding one to add
    // an occasion tag weeks later would strand every one of them.
    final p = await tester.runAsync(() => seed()) as Person;
    await tester.pumpWidget(host(AddPersonSheet(db: db, existing: p)));
    await tester.pump();

    expect(find.textContaining('cannot be messaged'), findsOneWidget);
    await tapSave(tester);

    final after = await peopleAfterSave(tester);
    expect(after.single.id, p.id, reason: 'the id must survive an edit');
    await unmount(tester);
  });

  testWidgets('creating still requires a channel', (tester) async {
    // The capture rule is unchanged — this is the invariant the looser edit
    // path must not have weakened.
    await tester.pumpWidget(host(AddPersonSheet(db: db)));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Bu Sri');
    await tester.pump();
    await tapSave(tester);

    final rows = await peopleAfterSave(tester);
    expect(rows, isEmpty);
    await unmount(tester);
  });

  testWidgets('a rename writes through and keeps met_when', (tester) async {
    final p = await tester.runAsync(() => seed(wa: '628123456789')) as Person;
    await tester.pumpWidget(host(AddPersonSheet(db: db, existing: p)));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Pak Andri');
    await tester.pump();
    await tapSave(tester);

    final after = await peopleAfterSave(tester);
    expect(after.single.name, 'Pak Andri');
    // ⚠ met_when records when you MET, not when you last edited the row.
    expect(after.single.metWhen, DateTime(2026, 3, 1));
    await unmount(tester);
  });

  testWidgets('an unknown occasion tag does not make a person uneditable',
      (tester) async {
    // A row synced from a newer client can carry a tag this build has never
    // heard of. Crashing there would strand the person entirely.
    final p = await tester.runAsync(
        () => seed(wa: '6281', tags: ['christmas', 'notATagYet'])) as Person;
    await tester.pumpWidget(host(AddPersonSheet(db: db, existing: p)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit person'), findsOneWidget);
    await unmount(tester);
  });

  group('phone edit sheet', () {
    /// ⚠ The REAL test view must be phone-shaped (see tasks_test.dart) — a
    /// MediaQuery-only override leaves pinned sheet buttons off-viewport.
    Widget phoneHost(WidgetTester tester, Person p) {
      tester.view.physicalSize = const Size(1170, 2532); // 390x844 @3x
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      return MaterialApp(
          theme: buildTheme(Brightness.light),
          home: PhoneEditPersonSheet(db: db, person: p));
    }
    Future<String> seedPhone(
        {String? wa, String? metWhere, List<String> tags = const []}) async {
      final id = newId();
      await db.addPerson(PeopleCompanion.insert(
        id: Value(id),
        name: 'Pak Andi',
        company: const Value('PT Formcase'),
        waNumber: wa == null ? const Value.absent() : Value(wa),
        metWhere: metWhere == null ? const Value.absent() : Value(metWhere),
        metWhen: Value(DateTime(2026, 3, 1)),
        occasionTags: Value(tags),
      ));
      return id;
    }

    Future<Person> thePerson() async =>
        (await db.watchPeople().first).single;

    testWidgets('opens prefilled with the met fields and the delete footer',
        (tester) async {
      final id = await tester.runAsync(
          () => seedPhone(wa: '628123456789', metWhere: 'Warung Kopi'))
          as String;
      final p = await tester.runAsync(thePerson);
      expect(p!.id, id);
      await tester.pumpWidget(phoneHost(tester, p));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();

      expect(find.text('Edit person'), findsOneWidget);
      expect(textOf(tester, 0), 'Pak Andi');
      expect(find.text('Warung Kopi'), findsOneWidget);
      // The v2 fix: met where/met when have an edit path at all now.
      expect(find.text('1 Mar'), findsOneWidget);
      expect(find.text('Delete person'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('met when opens the past-capped house sheet and writes',
        (tester) async {
      final id =
          await tester.runAsync(() => seedPhone(wa: '628123456789')) as String;
      final p = await tester.runAsync(thePerson);
      await tester.pumpWidget(phoneHost(tester, p!));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();

      // The met-when row sits below the fold in the sheet's scroll view.
      await tester.dragUntilVisible(find.text('1 Mar'),
          find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).last, const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();
      await tester.tap(find.text('1 Mar'));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();
      expect(find.text('Pick a date'), findsOneWidget);
      // Past-capped: the Today chip exists, the forward offsets do not —
      // +1w is nonsense for "when did we meet".
      expect(find.text('today'), findsOneWidget);
      expect(find.text('+1w'), findsNothing);

      await tester.tap(find.text('today'));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();
      await tapSave(tester);

      final after = await peopleAfterSave(tester);
      final now = DateTime.now();
      final metWhen = after.single.metWhen!;
      expect(metWhen.year, now.year);
      expect(metWhen.month, now.month);
      expect(metWhen.day, now.day);
      // And it is genuinely the meeting date that moved, not the row.
      expect(after.single.id, id);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('saves without a channel and leaves metWhen alone',
        (tester) async {
      final id = await tester.runAsync(() => seedPhone()) as String;
      final p = await tester.runAsync(thePerson);
      await tester.pumpWidget(phoneHost(tester, p!));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();

      expect(find.textContaining('cannot be messaged'), findsOneWidget);
      await tapSave(tester);

      final after = await peopleAfterSave(tester);
      expect(after.single.id, id);
      // Only a pick writes the date — an untouched sheet must not stamp
      // `now` onto a row that has an honest blank.
      expect(after.single.metWhen, DateTime(2026, 3, 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('the delete footer soft-deletes through the confirm',
        (tester) async {
      final id =
          await tester.runAsync(() => seedPhone(wa: '628123456789')) as String;
      final p = await tester.runAsync(thePerson);
      await tester.pumpWidget(phoneHost(tester, p!));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();

      // ⚠ dragUntilVisible, not ensureVisible: the latter awaits a scroll
      // animation that never completes under FakeAsync — the test wedges.
      await tester.dragUntilVisible(find.text('Delete person'),
          find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).last, const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();
      await tester.tap(find.text('Delete person'));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();
      expect(find.text('Delete Pak Andi?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 60)); await tester.pump(const Duration(milliseconds: 500)); await tester.pump();

      // ⚠ Direct drift awaits inside testWidgets deadlock — runAsync, per the
      // file header. This is the trap the header warns about, bitten in-house.
      expect(
          await tester.runAsync(() => db.watchPeople().first), isEmpty);
      final raw = await tester.runAsync(
          () => (db.select(db.people)..where((p) => p.id.equals(id)))
              .getSingleOrNull());
      expect(raw, isNotNull);
      expect(raw!.deletedAt, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
