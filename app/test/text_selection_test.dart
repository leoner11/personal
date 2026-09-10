import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/shell.dart';

/// ⚠ ScreenBody used to wrap its whole child in DragToMoveArea — a
/// GestureDetector with onPanStart + onDoubleTap. Every text field on every
/// screen sat underneath it, and the ancestor's double-tap recogniser won the
/// gesture arena: double-clicking a word in the notes editor maximised the
/// window instead of selecting the word. Drag-select survived (the innermost
/// drag recogniser wins that one) but is pinned here too, because the next
/// person to reach for a window-drag wrapper will break both at once.
void main() {
  Future<TextEditingController> pumpEditor(WidgetTester tester) async {
    final ctl = TextEditingController(text: 'hello world');
    await tester.pumpWidget(MaterialApp(
      // The desktop gesture set is what the app actually ships.
      theme: buildTheme(Brightness.light)
          .copyWith(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: ScreenBody(
          title: 'Notes',
          child: TextField(controller: ctl, maxLines: null),
        ),
      ),
    ));
    await tester.pump();
    return ctl;
  }

  // A point a few pixels into the first word.
  Offset inFirstWord(WidgetTester tester) =>
      tester.getTopLeft(find.byType(EditableText)) + const Offset(6, 8);

  testWidgets('double-click selects a word in the notes editor',
      (tester) async {
    final ctl = await pumpEditor(tester);
    final p = inFirstWord(tester);

    await tester.tapAt(p);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(p);
    await tester.pumpAndSettle();

    expect(ctl.selection.textInside(ctl.text), 'hello');
  });

  testWidgets('dragging across the notes editor selects text, not the window',
      (tester) async {
    final ctl = await pumpEditor(tester);
    final start = inFirstWord(tester);

    final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(start + const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(ctl.selection.isCollapsed, isFalse);
  });

  testWidgets('the title strip still drags the window', (tester) async {
    await pumpEditor(tester);
    expect(find.byType(DragToMoveArea), findsWidgets);
  });
}
