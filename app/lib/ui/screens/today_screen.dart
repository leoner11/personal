import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
import '../widgets/primitives.dart';

/// ⚠ Today's empty state is the NORMAL state. Most days nothing is due.
/// Do not add streaks, suggestions, "people you haven't contacted", or any
/// filler to make this screen look busy. Engagement is not a goal for a tool
/// with one user — the notification is the delivery mechanism, not this screen.
class TodayScreen extends StatelessWidget {
  const TodayScreen(
      {super.key, required this.db, required this.onCount, required this.onGo});
  final AppDatabase db;
  final ValueChanged<int> onCount;
  final ValueChanged<Section> onGo;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ScreenBody(
      title: 'Today',
      child: FutureBuilder<_TodayData>(
        future: _load(db),
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const SizedBox.shrink();
          onCount(d.count);

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
                          onPressed: () {
                            final n = DateTime.now();
                            db.setPing(
                                p.id, DateTime(n.year, n.month + 3, n.day));
                          }),
                      const SizedBox(width: 4),
                      Btn('Dismiss',
                          size: BtnSize.sm,
                          variant: BtnVariant.ghost,
                          onPressed: () => db.setPing(p.id, null)),
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
                          onPressed: () => db.settleMoney(m.id)),
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

  static Future<_TodayData> _load(AppDatabase db) async {
    final now = DateTime.now();
    final occ = await db.upcomingOccasions(withinDays: 14);
    final people = await db.watchPeople().first;
    final pings = people
        .where((p) =>
            p.pingDate != null &&
            p.pingDate!.isBefore(now.add(const Duration(days: 1))))
        .toList();
    final moneyRows = await db.watchMoney().first;
    final settle = moneyRows
        .where((m) =>
            m.status == 'expected' &&
            m.date.isBefore(now.add(const Duration(days: 1))))
        .toList();

    final counts = <String, int>{};
    for (final o in occ) {
      counts[o.tag] =
          people.where((p) => p.occasionTags.contains(o.tag)).length;
    }

    final runway = await db.calendarRunway();
    String? warn;
    if (runway == null) {
      warn = 'Occasion calendar is empty — nothing will ever fire.';
    } else if (runway.difference(now).inDays < 365) {
      warn = 'Occasion calendar ends ${fmtDate(runway)} — add more dates.';
    }

    return _TodayData(
      occasions: occ,
      pings: pings,
      settle: settle,
      taggedCounts: counts,
      runwayWarning: warn,
    );
  }
}

class _TodayData {
  _TodayData({
    required this.occasions,
    required this.pings,
    required this.settle,
    required this.taggedCounts,
    required this.runwayWarning,
  });
  final List<Occasion> occasions;
  final List<Person> pings;
  final List<MoneyRow> settle;
  final Map<String, int> taggedCounts;
  final String? runwayWarning;

  int get count =>
      occasions.length + pings.length + settle.length + (runwayWarning == null ? 0 : 1);
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
