import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/auto_sync.dart';

/// ⚠ The Mac used to sync only at launch and on a button press. These pin
/// the three automatic triggers, and the rule that runs never overlap.
/// testWidgets is used only for its fake clock — nothing here is drawn.
void main() {
  late StreamController<int> changes;
  late int runs;
  late AutoSync auto;

  AutoSync make({Future<void> Function()? run}) => AutoSync(
        run: run ??
            () async {
              runs++;
            },
        changes: changes.stream,
        settle: const Duration(seconds: 5),
        every: const Duration(minutes: 3),
      );

  setUp(() {
    changes = StreamController<int>();
    runs = 0;
  });

  // ⚠ Disposed at the end of each body, not in tearDown: testWidgets checks
  // for pending timers before tearDown runs, and the tick is periodic.
  tearDown(() => changes.close());

  testWidgets('an edit syncs once things go quiet, not per keystroke',
      (tester) async {
    auto = make();
    for (var i = 1; i <= 4; i++) {
      changes.add(i);
      await tester.pump(const Duration(seconds: 2));
    }
    expect(runs, 0, reason: 'still typing');
    await tester.pump(const Duration(seconds: 5));
    expect(runs, 1);
    auto.dispose();
  });

  testWidgets('the sync clearing its own rows does not schedule another',
      (tester) async {
    auto = make();
    changes.add(0);
    await tester.pump(const Duration(seconds: 10));
    expect(runs, 0);
    auto.dispose();
  });

  testWidgets('it syncs on a timer while open, and on coming back',
      (tester) async {
    auto = make();
    await tester.pump(const Duration(minutes: 3));
    expect(runs, 1);
    await tester.pump(const Duration(minutes: 3));
    expect(runs, 2);
    auto.resumed();
    await tester.pump();
    expect(runs, 3);
    auto.dispose();
  });

  testWidgets('a trigger during a run waits for it, then runs once',
      (tester) async {
    var inFlight = 0;
    var maxInFlight = 0;
    final gate = Completer<void>();
    auto = make(run: () async {
      runs++;
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      if (runs == 1) await gate.future;
      inFlight--;
    });

    unawaited(auto.trigger());
    await tester.pump();
    // Three triggers while the first is uploading.
    auto.resumed();
    auto.resumed();
    unawaited(auto.trigger());
    await tester.pump();
    expect(runs, 1);

    gate.complete();
    await tester.pump();
    expect(runs, 2, reason: 'the edits made mid-run still go up');
    expect(maxInFlight, 1);
    auto.dispose();
  });

  testWidgets('a failing run does not stop later ones', (tester) async {
    auto = make(run: () async {
      runs++;
      throw Exception('offline');
    });
    await auto.trigger();
    await auto.trigger();
    expect(runs, 2);
    auto.dispose();
  });

  test('an edit in the database shows up as rows waiting to sync', () async {
    // The real signal AutoSync listens to on the Mac.
    auto = make();
    auto.dispose();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final seen = <int>[];
    final sub = db.watchDirtyCount().listen(seen.add);
    addTearDown(sub.cancel);
    await db.addPerson(
        PeopleCompanion.insert(id: const Value('p1'), name: 'Pak Andi'));
    await pumpEventQueue();
    expect(seen, isNotEmpty, reason: 'an edit must reach AutoSync');
    expect(seen.last, 1);
  });
}
