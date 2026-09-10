import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/capture_screen.dart';
import 'package:personal_crm/ui/phone/phone_shell.dart';

/// ⚠ Two separate drift-under-FakeAsync traps are pinned here, both of which
/// present as "the test file hangs with no output":
///   1. Awaiting a drift query directly inside testWidgets deadlocks — use
///      `tester.runAsync` (see [people]).
///   2. Cancelling a drift query stream schedules a zero-duration FakeTimer,
///      which trips the pending-timer assertion and then WEDGES the runner —
///      unmount the tree inside the test and advance the fake clock (see
///      [unmount]).
///
/// Deliberately no pumpAndSettle against live streams — same rule the desktop
/// layout tests follow. These pin behaviour, not pixels.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme(Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: child,
        ),
      );

  Future<List<Person>> people(WidgetTester tester) async =>
      await tester.runAsync(() => db.watchPeople().first) ?? const [];

  Future<void> fill(WidgetTester tester,
      {required String name, required String number}) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), number);
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();
  }

  /// ⚠ Unmount the tree INSIDE the test, not at teardown.
  ///
  /// Disposing a drift StreamBuilder cancels its query stream, and that cancel
  /// schedules a zero-duration teardown timer (StreamQueryStore.markAsClosed).
  /// If the tree is still mounted when the test body ends, the framework
  /// disposes it during teardown — the timer is created after the last chance
  /// to advance the clock, the pending-timer assertion fires, and then the
  /// runner WEDGES instead of exiting. A whole file then looks like an
  /// infinite hang with no output at all, which is a miserable thing to debug.
  ///
  /// Pumping an empty tree here creates that timer while we can still fire it.
  /// Note the clock must be the FAKE one: `runAsync` with a real delay will
  /// never fire a FakeTimer.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('Capture is the default tab, not Today', (tester) async {
    await tester.pumpWidget(host(PhoneShell(db: db)));
    await tester.pump();

    // ⚠ The app's stated failure mode is that capture stops happening by week
    // three. Landing anywhere else is the regression this guards.
    expect(find.byType(CaptureScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a notification tap can route straight to Today', (tester) async {
    // B1 -> B2 must stay a two-step loop.
    await tester.pumpWidget(host(PhoneShell(db: db, initial: PhoneTab.today)));
    await tester.pump();

    expect(find.text('Today'), findsWidgets);
    await unmount(tester);
  });

  group('capture', () {
    testWidgets('a name alone does not save — a channel is required',
        (tester) async {
      await tester.pumpWidget(host(CaptureScreen(db: db)));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Pak Andi');
      await tester.pump();
      await tapSave(tester);

      // A person with no channel cannot be messaged, which is the entire
      // point of the record.
      expect(await people(tester), isEmpty);
    });

    testWidgets('name plus one channel saves, and nothing else is required',
        (tester) async {
      await tester.pumpWidget(host(CaptureScreen(db: db)));
      await tester.pump();

      await fill(tester, name: 'Pak Andi', number: '628123456789');
      await tapSave(tester);

      final rows = await people(tester);
      expect(rows.length, 1);
      expect(rows.first.name, 'Pak Andi');
      expect(rows.first.waNumber, '628123456789');
      // Both empty would be wrong; WhatsApp wins because it deep-links.
      expect(rows.first.preferredChannel, 'wa');
      // ⚠ Nothing may block the save: no company, no met-where, no notes.
      expect(rows.first.company, isNull);
    });

    testWidgets('the form clears and stays put so a second person can follow',
        (tester) async {
      await tester.pumpWidget(host(CaptureScreen(db: db)));
      await tester.pump();

      await fill(tester, name: 'Pak Andi', number: '628123456789');
      await tapSave(tester);

      // Capture happens in bursts — three people at one mixer. A success
      // screen you have to dismiss costs more than it reassures.
      expect(find.byType(CaptureScreen), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          isEmpty);

      // And the second person actually goes in.
      await fill(tester, name: 'Bu Sri', number: '628999');
      await tapSave(tester);
      expect((await people(tester)).length, 2);
    });

    testWidgets('occasion chips are reachable without opening Add detail',
        (tester) async {
      await tester.pumpWidget(host(CaptureScreen(db: db)));
      await tester.pump();

      // ⚠ Flowchart A1-3: occasion tags cannot be backfilled, so they must not
      // sit behind the disclosure that everything optional lives in.
      expect(find.text('OCCASIONS'), findsOneWidget);
      expect(find.text('Christmas'), findsOneWidget);
      // Company is optional, so it IS behind the disclosure.
      expect(find.text('COMPANY'), findsNothing);
    });

    testWidgets('a tagged occasion is stored on the person', (tester) async {
      await tester.pumpWidget(host(CaptureScreen(db: db)));
      await tester.pump();

      await fill(tester, name: 'Pak Andi', number: '628123456789');
      await tester.tap(find.text('Christmas'));
      await tester.pump();
      await tapSave(tester);

      final rows = await people(tester);
      expect(rows.single.occasionTags, contains('christmas'));
    });
  });
}
