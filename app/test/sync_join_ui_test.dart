import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/domain/sync_account.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/sync_join_sheet.dart';
import 'package:personal_crm/ui/sync_join_dialog.dart';

/// The combine-or-replace question on both shells. The engine behaviour is in
/// sync_test.dart; these pin what the person choosing actually sees and that
/// the destructive answer cannot be given in one tap.
void main() {
  const join = JoinNeeded(
    account: 'leonard',
    previousAccount: null,
    here: DataSummary({'people': 1, 'notes': 3}),
    there: DataSummary({'people': 18, 'tasks': 24}),
  );

  /// Opens [open] from a button and records what it returns.
  Future<List<JoinChoice?>> host(WidgetTester tester,
      Future<JoinChoice?> Function(BuildContext) open) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final results = <JoinChoice?>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => results.add(await open(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await beat(tester);
    return results;
  }

  test('the counts read as sentences, and seeds-only reads as nothing', () {
    expect(join.here.describe(), '1 person and 3 notes');
    expect(join.there.describe(), '18 people and 24 tasks');
    expect(const DataSummary({'people': 0}).describe(), 'nothing');
  });

  test('a switch says so, and names the account the data came from', () {
    const switching = JoinNeeded(
      account: 'sri',
      previousAccount: 'leonard',
      here: DataSummary({'people': 2}),
      there: DataSummary({}),
    );
    final q = joinQuestion(switching);
    expect(q.title, 'Switching to sri');
    expect(q.body, contains('last synced with leonard'));
    // Into an empty account, "replace" is really "start fresh" — say that.
    expect(useAccountExplainer(switching), contains('which is empty'));
  });

  group('phone', () {
    testWidgets('Combine answers in one tap', (tester) async {
      final results =
          await host(tester, (c) => PhoneSyncJoinSheet.show(c, join));

      expect(find.text('This device already has data'), findsOneWidget);
      expect(find.textContaining('1 person and 3 notes'), findsOneWidget);
      expect(find.textContaining('18 people and 24 tasks'), findsOneWidget);

      await tester.tap(find.text('Combine both'));
      await beat(tester);
      expect(results, [JoinChoice.combine]);
    });

    testWidgets("Use the account's data needs a second, explicit yes",
        (tester) async {
      final results =
          await host(tester, (c) => PhoneSyncJoinSheet.show(c, join));

      await tester.tap(find.text("Use leonard's data"));
      await beat(tester);
      // ⚠ The confirm names what leaves the device, in numbers.
      expect(find.text("Replace this device's data?"), findsOneWidget);
      expect(find.textContaining('Removes 1 person and 3 notes'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await beat(tester);
      expect(results, isEmpty, reason: 'backing out of the confirm is not an answer');

      await tester.tap(find.text("Use leonard's data"));
      await beat(tester);
      await tester.tap(find.text('Replace'));
      await beat(tester);
      await beat(tester);
      expect(results, [JoinChoice.useAccount]);
    });

    testWidgets('Not now answers nothing', (tester) async {
      final results =
          await host(tester, (c) => PhoneSyncJoinSheet.show(c, join));
      await tester.tap(find.text('Not now'));
      await beat(tester);
      expect(results, [null]);
    });
  });

  group('desktop', () {
    testWidgets('a click outside is not an answer', (tester) async {
      final results = await host(tester, (c) => SyncJoinDialog.show(c, join));
      await tester.tapAt(const Offset(5, 5));
      await beat(tester);
      expect(find.text('This device already has data'), findsOneWidget);
      expect(results, isEmpty);

      await tester.tap(find.text('Not now'));
      await beat(tester);
      expect(results, [null]);
    });

    testWidgets("Use the account's data needs a second, explicit yes",
        (tester) async {
      final results = await host(tester, (c) => SyncJoinDialog.show(c, join));

      await tester.tap(find.text('Choose').last);
      await beat(tester);
      expect(find.text("Replace this device's data?"), findsOneWidget);
      await tester.tap(find.text('Replace'));
      await beat(tester);
      expect(results, [JoinChoice.useAccount]);
    });
  });
}

Future<void> beat(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}
