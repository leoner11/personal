import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/notifications.dart' show seedBuiltInTags;
import 'package:personal_crm/domain/tag_vocab.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/calendar_screen.dart' as phone;
import 'package:personal_crm/ui/phone/today_screen.dart';
import 'package:personal_crm/ui/screens/calendar_screen.dart';
import 'package:personal_crm/ui/screens/today_screen.dart';

/// ⚠ Leonard, 24 Sep: tasks "don't automatically sync — we have to refresh a
/// few times", on Today and the calendar. Half of that was sync never running
/// on its own; the other half is here: these screens loaded ONCE and never
/// heard about a row written anywhere else — another tab, or a sync. The
/// write below stands in for both: it does not go through the screen.
void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedBuiltInTags(db);
    await TagVocab.refresh(db);
  });
  tearDown(() async {
    await TagVocab.reset();
    await db.close();
  });

  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> writeElsewhere(WidgetTester tester, String title) async {
    await tester.runAsync(() => db.addTask(TasksCompanion.insert(
          id: Value(title),
          title: title,
          dueDate: Value(today()),
          createdAt: Value(DateTime(2026, 9, 1)),
        )));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: PM.clearMs + 120));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Widget phoneHost(WidgetTester tester, Widget child) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return MaterialApp(theme: buildTheme(Brightness.light), home: child);
  }

  Widget desktopHost(WidgetTester tester, Widget child) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return MaterialApp(
        theme: buildTheme(Brightness.light), home: Scaffold(body: child));
  }

  Future<void> expectItAppears(
      WidgetTester tester, Widget host, String title) async {
    await tester.pumpWidget(host);
    await settle(tester);
    expect(find.text(title), findsNothing);

    await writeElsewhere(tester, title);
    await settle(tester);
    expect(find.text(title), findsWidgets,
        reason: 'the screen never heard about the new row');
    await unmount(tester);
  }

  testWidgets('phone Today shows a task written elsewhere', (tester) async {
    await expectItAppears(
        tester, phoneHost(tester, PhoneTodayScreen(db: db)), 'Buy mooncakes');
  });

  testWidgets('phone Calendar shows a task written elsewhere', (tester) async {
    await expectItAppears(tester,
        phoneHost(tester, phone.PhoneCalendarScreen(db: db)), 'Buy mooncakes');
  });

  testWidgets('Mac Today shows a task written elsewhere', (tester) async {
    await expectItAppears(
        tester,
        desktopHost(
            tester, TodayScreen(db: db, onCount: (_) {}, onGo: (_) {})),
        'Buy mooncakes');
  });

  testWidgets('Mac Calendar shows a task written elsewhere', (tester) async {
    await expectItAppears(
        tester, desktopHost(tester, CalendarScreen(db: db)), 'Buy mooncakes');
  });
}
