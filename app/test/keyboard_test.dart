import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/phone_primitives.dart';

/// ⚠ Leonard, 24 Sep: "for most pages the keyboard cannot be cancelled". The
/// first fix sat inside the tab shell, so pushed screens and sheets — which
/// sit ABOVE the shell — never got it. These drive the app-wide dismisser the
/// way main.dart mounts it: in MaterialApp's builder, above the Navigator.
void main() {
  Widget app(WidgetTester tester, Widget home) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return MaterialApp(
      theme: buildTheme(Brightness.light),
      builder: (context, child) => PhoneKeyboardDismisser(child: child!),
      home: home,
    );
  }

  bool aFieldHasFocus(WidgetTester tester) => tester
      .widgetList<EditableText>(find.byType(EditableText))
      .any((e) => e.focusNode.hasFocus);

  Widget page({VoidCallback? onButton}) => Scaffold(
        body: ListView(
          children: [
            const TextField(key: Key('field')),
            const SizedBox(height: 40, child: Text('A LABEL')),
            TextButton(onPressed: onButton, child: const Text('A BUTTON')),
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('row $i')),
          ],
        ),
      );

  testWidgets('a pushed screen: tapping away puts it away', (tester) async {
    await tester.pumpWidget(app(tester, const Scaffold()));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => page()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(aFieldHasFocus(tester), isTrue);

    await tester.tap(find.text('A LABEL'));
    await tester.pump();
    expect(aFieldHasFocus(tester), isFalse);
  });

  testWidgets('a sheet: tapping away puts it away', (tester) async {
    await tester.pumpWidget(app(tester, const Scaffold()));
    final ctx = tester.element(find.byType(Scaffold));
    PhoneSheet.show<void>(
        ctx,
        (_) => const PhoneSheet(
              title: 'New task',
              child: TextField(key: Key('field')),
            ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(aFieldHasFocus(tester), isTrue);

    await tester.tap(find.text('New task'));
    await tester.pump();
    expect(aFieldHasFocus(tester), isFalse);
    expect(find.text('New task'), findsOneWidget,
        reason: 'tapping inside the sheet must not close it');
  });

  testWidgets('a button still gets its tap while the keyboard is up',
      (tester) async {
    var pressed = 0;
    await tester.pumpWidget(app(tester, page(onButton: () => pressed++)));
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    await tester.tap(find.text('A BUTTON'));
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets('dragging a list puts it away', (tester) async {
    // ⚠ The field sits OUTSIDE the list. Inside it, scrolling it off screen
    // disposes it and focus goes with it — the test then passed with the drag
    // handling deleted.
    await tester.pumpWidget(app(
      tester,
      Scaffold(
        body: Column(children: [
          const TextField(key: Key('field')),
          Expanded(
            child: ListView(children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 60, child: Text('row $i')),
            ]),
          ),
        ]),
      ),
    ));
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(aFieldHasFocus(tester), isTrue);

    await tester.drag(find.text('row 5'), const Offset(0, -200));
    await tester.pump();
    expect(aFieldHasFocus(tester), isFalse);
  });

  testWidgets('scrolling the text of a note being written keeps it up',
      (tester) async {
    final long = List.generate(80, (i) => 'line $i').join('\n');
    await tester.pumpWidget(app(
      tester,
      Scaffold(
        body: SizedBox(
          height: 300,
          child: TextField(
            key: const Key('note'),
            controller: TextEditingController(text: long),
            maxLines: null,
            expands: true,
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('note')));
    await tester.pump();
    expect(aFieldHasFocus(tester), isTrue);

    await tester.drag(find.byKey(const Key('note')), const Offset(0, -150));
    await tester.pump();
    expect(aFieldHasFocus(tester), isTrue);
  });

  testWidgets('with the keyboard up, a tall sheet stays below the status bar',
      (tester) async {
    // ⚠ Leonard's screenshots, 24 Sep: Add money row, Edit project and Edit
    // task all put their title under the clock and the Dynamic Island once
    // the keyboard came up. iPhone Pro Max: 430x932pt, 62pt status bar, a
    // 336pt keyboard.
    const statusBar = 62.0, keyboard = 336.0, height = 932.0;
    tester.view.physicalSize = const Size(430 * 3, height * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: statusBar * 3);
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(),
    ));
    PhoneSheet.show<void>(
      tester.element(find.byType(Scaffold)),
      (_) => PhoneSheet(
        title: 'Add money row',
        actions: TextButton(onPressed: () {}, child: const Text('Save')),
        child: Column(children: [
          for (var i = 0; i < 12; i++)
            SizedBox(height: 70, child: TextField(key: Key('f$i'))),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Add money row')).dy,
        greaterThanOrEqualTo(statusBar),
        reason: 'the title is under the status bar');
    expect(tester.getBottomLeft(find.text('Save')).dy,
        lessThanOrEqualTo(height - keyboard),
        reason: 'Save is behind the keyboard');
  });
}
