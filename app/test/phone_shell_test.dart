import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/main.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/capture_screen.dart';
import 'package:personal_crm/ui/phone/phone_shell.dart';
import 'package:personal_crm/domain/tag_vocab.dart';

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

  /// ⚠ Assert on the IndexedStack index, never on what is findable.
  ///
  /// Every tab stays mounted in an IndexedStack, and the bottom bar renders
  /// the word "Today" whichever tab is showing — so `find.byType(TodayScreen)`
  /// and `find.text('Today')` are both true always. Two tests here used to do
  /// exactly that and could not have failed.
  PhoneTab currentTab(WidgetTester tester) => PhoneTab.values[
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index!];

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
    // ⚠ v2: Today schedules a post-collapse sweep ~280ms after EVERY load
    // (today_screen _sweepSoon — Future.delayed, not a zero-duration drift
    // timer). The v1 10ms drain cannot fire it, so drain one full sweep
    // window, then the drift-cancellation turn.
    await tester.pump(const Duration(milliseconds: PM.clearMs + 120));
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('Capture is the default tab, not Today', (tester) async {
    await tester.pumpWidget(host(PhoneShell(db: db)));
    await tester.pump();

    // ⚠ The app's stated failure mode is that capture stops happening by week
    // three. Landing anywhere else is the regression this guards.
    expect(currentTab(tester), PhoneTab.capture);
    await unmount(tester);
  });

  group('a notification tap routes straight to Today', () {
    // B1 -> B2 must stay a two-step loop. Two different mechanisms reach it,
    // so both are pinned — the warm one had no caller at all until now.

    testWidgets('cold launch — main() passes the tab in', (tester) async {
      await tester.pumpWidget(host(PhoneShell(db: db, initial: PhoneTab.today)));
      await tester.pump();

      expect(currentTab(tester), PhoneTab.today);
      await unmount(tester);
    });

    testWidgets('warm tap — the app is already running on Capture',
        (tester) async {
      await tester.pumpWidget(host(PhoneShell(db: db)));
      await tester.pump();
      expect(currentTab(tester), PhoneTab.capture);

      // What Notifier's onDidReceiveNotificationResponse does. ⚠ Until this
      // was wired, tapping a reminder surfaced the app on whatever tab it was
      // left on — Capture — and the loop the app exists for died at step one.
      notificationTaps.value++;
      await tester.pump();

      expect(currentTab(tester), PhoneTab.today);
      await unmount(tester);
    });

    testWidgets('a second tap still lands, having already been to Today',
        (tester) async {
      // ⚠ Why notificationTaps is a counter and not a flag: a ValueNotifier
      // only fires on a CHANGE, so setting a bool true twice is silent the
      // second time.
      await tester.pumpWidget(host(PhoneShell(db: db)));
      await tester.pump();

      notificationTaps.value++;
      await tester.pump();
      // Wander off to People the way a real user would.
      await tester.tap(find.text('People'));
      await tester.pump();
      expect(currentTab(tester), PhoneTab.people);

      notificationTaps.value++;
      await tester.pump();
      expect(currentTab(tester), PhoneTab.today);
      await unmount(tester);
    });
  });

  testWidgets('leaving the foreground rebuilds the notification schedule',
      (tester) async {
    // ⚠ THE HOLE THIS CLOSES: rescheduleAll() used to have exactly one caller,
    // main(). Capture someone 15 days before a festival, close the app without
    // reopening it, and no alarm was ever set — on a phone, where the whole
    // interaction model is "capture in 10 seconds and close", that is the
    // normal case, not an edge one.
    var passes = 0;
    await tester.pumpWidget(App(db: db, onPause: () async => passes++));
    await tester.pump();
    expect(passes, 0, reason: 'nothing should reschedule while in use');

    // The real transition Android makes on Home: resumed -> inactive ->
    // hidden -> paused. AppLifecycleListener asserts on illegal jumps.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();

    expect(passes, 1);
    await unmount(tester);
  });

  group('the keyboard', () {
    // ⚠ Not primaryFocus.hasFocus: unfocusing moves focus to the enclosing
    // SCOPE, which still reports hasFocus. What matters is whether a text
    // field still holds it, because that is what keeps the keyboard up.
    bool aFieldHasFocus(WidgetTester tester) => tester
        .widgetList<EditableText>(find.byType(EditableText))
        .any((e) => e.focusNode.hasFocus);

    // ⚠ The screens live in an IndexedStack, so focus survives a tab change:
    // a focused Capture field kept the keyboard up over Today and People,
    // and the only way down was finishing a capture.
    testWidgets('switching tabs puts it away', (tester) async {
      await tester.pumpWidget(host(PhoneShell(db: db)));
      await tester.pump();

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(aFieldHasFocus(tester), isTrue);

      // ⚠ .last: every tab's screen stays built in the IndexedStack, so the
      // Today SCREEN also contains the word "Today". The nav bar is last.
      await tester.tap(find.text('Today').last);
      await tester.pump();

      expect(currentTab(tester), PhoneTab.today);
      expect(aFieldHasFocus(tester), isFalse,
          reason: 'the keyboard followed the tab change');

      await unmount(tester);
    });

    testWidgets('tapping away from the fields puts it away', (tester) async {
      await tester.pumpWidget(host(PhoneShell(db: db)));
      await tester.pump();

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(aFieldHasFocus(tester), isTrue);

      await tester.tap(find.text('OCCASIONS'));
      await tester.pump();
      expect(aFieldHasFocus(tester), isFalse);

      await unmount(tester);
    });
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
