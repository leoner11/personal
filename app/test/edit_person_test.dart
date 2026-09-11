import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/add_person_sheet.dart';

/// The Mac edit sheet. ⚠ Editing a person was impossible in either shell until
/// 12 Sep — the only write was a soft delete — so these pin the behaviour that
/// made the workaround dangerous: delete-and-re-add mints a new UUID and
/// silently detaches every touch, note and money row pointing at the old one.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

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
    await tester.ensureVisible(find.text('Save'));
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
}
