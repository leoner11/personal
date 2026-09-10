import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../domain/today.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
import '../widgets/primitives.dart';

/// ⚠ Today's empty state is the NORMAL state. Most days nothing is due.
/// Do not add streaks, suggestions, "people you haven't contacted", or any
/// filler to make this screen look busy. Engagement is not a goal for a tool
/// with one user — the notification is the delivery mechanism, not this screen.
class TodayScreen extends StatefulWidget {
  const TodayScreen(
      {super.key, required this.db, required this.onCount, required this.onGo});
  final AppDatabase db;
  final ValueChanged<int> onCount;
  final ValueChanged<Section> onGo;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  /// ⚠ Held in state, NEVER created in build. Building the future inline made
  /// every rebuild start a fresh set of queries, and because reporting the
  /// count rebuilds the shell, that rebuilt this screen — an endless loop of
  /// database reads that never settled.
  late Future<TodayData> _future = loadToday(widget.db);

  // ⚠ Block body, not an arrow. `setState(() => _future = ...)` returns the
  // assigned Future from the callback, and Flutter asserts on that:
  // "setState() callback argument returned a Future."
  void _refresh() {
    setState(() {
      _future = loadToday(widget.db);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final onGo = widget.onGo;
    final t = AppTokens.of(context);
    return ScreenBody(
      title: 'Today',
      child: FutureBuilder<TodayData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const SizedBox.shrink();
          widget.onCount(d.count);

          final blocks = <Widget>[];

          // ⚠ The one item allowed to sit on Today indefinitely.
          if (d.runwayWarning != null) {
            blocks.add(_Section('Calendar', [
              Panel(
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.runwayWarning!,
                            style: T.body.copyWith(color: t.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                            'Nothing schedules past this date. It will look '
                            'exactly like a quiet day.',
                            style: T.secondary.copyWith(color: t.textSecondary)),
                      ],
                    ),
                  ),
                  Btn('Occasions',
                      size: BtnSize.sm,
                      variant: BtnVariant.ghost,
                      onPressed: () => onGo(Section.occasions)),
                ]),
              )
            ]));
          }

          if (d.occasions.isNotEmpty) {
            blocks.add(_Section('Occasions', [
              for (final o in d.occasions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              StatusTag(tone: t.attention, label: fmtIn(o.date)),
                              const SizedBox(width: 8),
                              Text(o.name,
                                  style: T.body.copyWith(
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 3),
                            Text(
                                '${d.taggedCounts[o.tag] ?? 0} people tagged · ${fmtDate(o.date)}',
                                style: T.secondary
                                    .copyWith(color: t.textSecondary)),
                          ],
                        ),
                      ),
                      Btn('Open',
                          size: BtnSize.sm,
                          variant: BtnVariant.ghost,
                          onPressed: () => onGo(Section.occasions)),
                    ]),
                  ),
                ),
            ]));
          }

          if (d.pings.isNotEmpty) {
            blocks.add(_Section('Pings', [
              for (final p in d.pings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              StatusTag(
                                  tone: t.attention, label: fmtIn(p.pingDate!)),
                              const SizedBox(width: 8),
                              Text(
                                  [p.name, p.company]
                                      .where((e) => e != null && e.isNotEmpty)
                                      .join(' · '),
                                  style: T.body.copyWith(
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            if (p.pingNote != null && p.pingNote!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text('"${p.pingNote}"',
                                  style: T.secondary.copyWith(
                                      color: t.textSecondary,
                                      fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                      Btn('People',
                          size: BtnSize.sm,
                          variant: BtnVariant.ghost,
                          onPressed: () => onGo(Section.people)),
                      const SizedBox(width: 4),
                      Btn('+3 mo',
                          size: BtnSize.sm,
                          variant: BtnVariant.ghost,
                          onPressed: () async {
                            final n = DateTime.now();
                            await db.setPing(
                                p.id, DateTime(n.year, n.month + 3, n.day));
                            _refresh();
                          }),
                      const SizedBox(width: 4),
                      Btn('Dismiss',
                          size: BtnSize.sm,
                          variant: BtnVariant.ghost,
                          onPressed: () async {
                            await db.setPing(p.id, null);
                            _refresh();
                          }),
                    ]),
                  ),
                ),
            ]));
          }

          if (d.settle.isNotEmpty) {
            blocks.add(_Section('Money', [
              for (final m in d.settle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              StatusTag(tone: t.attention, label: 'Expected'),
                              const SizedBox(width: 8),
                              Text(m.label,
                                  style: T.body.copyWith(
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 3),
                            Text(
                                '${m.direction == 'in' ? 'in' : 'out'} · '
                                '${fmtMoney(m.amountMinor, m.currency)} · '
                                'due ${fmtDate(m.date)}',
                                style: T.secondary
                                    .copyWith(color: t.textSecondary)),
                          ],
                        ),
                      ),
                      Btn('Confirm',
                          size: BtnSize.sm,
                          variant: BtnVariant.ghost,
                          onPressed: () async {
                            await db.settleMoney(m.id);
                            _refresh();
                          }),
                    ]),
                  ),
                ),
            ]));
          }

          if (blocks.isEmpty) {
            return const EmptyLine('No one needs you today.');
          }
          return ListView(children: blocks);
        },
      ),
    );
  }

}

/// Sections with zero items are hidden entirely, never shown empty.
class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(title,
              style: T.sectionLabel.copyWith(color: t.textPrimary)),
        ),
        ...children,
        const SizedBox(height: 10),
      ],
    );
  }
}
