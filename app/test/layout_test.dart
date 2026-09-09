import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/widgets/primitives.dart';

/// ⚠ Overflow only appears at the NARROW end, and the controls that overflow
/// are the ones made of fixed-width children that cannot shrink. These render
/// them at the tightest width the app allows and assert nothing overflows.
///
/// Deliberately no database and no pumpAndSettle — this is a layout test, and
/// pumping the whole shell against live streams never settles.
void main() {
  Widget host(Widget child, double width) => MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      );

  // The narrowest the detail pane can get: 960 minimum window
  // - 200 sidebar - 300 list - 40 padding - 24 panel padding.
  const tightest = 396.0;

  testWidgets('DateField fits the tightest detail pane', (tester) async {
    await tester.pumpWidget(host(
      DateField(label: 'Date', value: DateTime(2026, 9, 9), onChanged: (_) {}),
      tightest,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('DateField survives an absurdly narrow pane', (tester) async {
    // It should wrap, not overflow, however cramped it gets.
    await tester.pumpWidget(host(
      DateField(label: 'Date', value: DateTime(2026, 12, 25), onChanged: (_) {}),
      200,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the note header row that overflowed now fits', (tester) async {
    // Field + Delete on one row, DateField beneath — the exact structure that
    // reported "RIGHT OVERFLOWED BY 189 PIXELS".
    await tester.pumpWidget(host(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Field(
                  label: 'Tag',
                  controller: TextEditingController(),
                  hint: 'content / thesis'),
            ),
            const SizedBox(width: 8),
            DeleteAction(
                what: 'this note', size: BtnSize.md, onConfirmed: () async {}),
          ]),
          const SizedBox(height: 12),
          DateField(
              label: 'Date', value: DateTime(2026, 9, 9), onChanged: (_) {}),
        ],
      ),
      tightest,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row of ping buttons wraps rather than overflowing',
      (tester) async {
    await tester.pumpWidget(host(
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (final l in const ['1 mo', '3 mo', '6 mo', '12 mo', 'Clear'])
          Btn(l, size: BtnSize.sm, onPressed: () {}),
      ]),
      tightest,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels ellipsize instead of pushing a row wide',
      (tester) async {
    await tester.pumpWidget(host(
      Row(children: [
        const Expanded(
          child: Text('中秋节 gift — Pak Andi Wijaya of PT Formcase Industries',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        Btn('Confirm', size: BtnSize.sm, onPressed: () {}),
        Btn('Edit', size: BtnSize.sm, onPressed: () {}),
      ]),
      tightest,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
