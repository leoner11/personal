import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../domain/notifications.dart';
import '../../domain/today.dart';
import '../../theme/tokens.dart';
import 'occasion_run_screen.dart';
import 'phone_primitives.dart';

/// B1 — what is due. ⚠ This screen is strictly better on a phone than on the
/// Mac: the notification, the contact list and WhatsApp are finally on the
/// same device, so the occasion loop is tap-notification → tap-send.
///
/// ⚠ Its empty state is the NORMAL state. Most days nothing is due, and the
/// screen is quiet because nothing needed doing — not because it failed. Do
/// not fill it with streaks, suggestions or "people you haven't contacted".
/// Engagement is not a goal for a tool with one user.
class PhoneTodayScreen extends StatefulWidget {
  const PhoneTodayScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhoneTodayScreen> createState() => _PhoneTodayScreenState();
}

class _PhoneTodayScreenState extends State<PhoneTodayScreen> {
  /// ⚠ Held in state, never built inline — see the desktop screen's note. A
  /// future created in build() restarts every query on every rebuild.
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
    final t = AppTokens.of(context);
    return PhoneBody(
      title: 'Today',
      child: FutureBuilder<TodayData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const SizedBox.shrink();
          if (d.isEmpty) return const PhoneEmpty('No one needs you today.');

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                PD.screenPad, 0, PD.screenPad, PD.sectionGap),
            children: [
              if (d.runwayWarning != null)
                PhoneSection('Calendar', [
                  PhoneCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.runwayWarning!,
                            style: PT.body.copyWith(color: t.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                            'Nothing schedules past this date. It will look '
                            'exactly like a quiet day.',
                            style:
                                PT.secondary.copyWith(color: t.textSecondary)),
                      ],
                    ),
                  ),
                ]),

              if (d.occasions.isNotEmpty)
                PhoneSection('Occasions', [
                  for (final o in d.occasions)
                    PhoneCard(
                      // One push deep, and it is the point of the app: the
                      // list of people to actually message.
                      onTap: () => _openRun(o),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                PhoneTag(
                                    tone: t.attention, label: fmtIn(o.date)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(o.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: PT.body.copyWith(
                                          color: t.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              const SizedBox(height: 4),
                              Text(
                                  '${taggedLabel(d.taggedCounts[o.tag] ?? 0)} · ${fmtDate(o.date)}',
                                  style: PT.secondary
                                      .copyWith(color: t.textSecondary)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 22, color: t.textMuted),
                      ]),
                    ),
                ]),

              if (d.pings.isNotEmpty)
                PhoneSection('Pings', [
                  for (final p in d.pings)
                    PhoneCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            PhoneTag(
                                tone: t.attention, label: fmtIn(p.pingDate!)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  [p.name, p.company]
                                      .where((e) => e != null && e.isNotEmpty)
                                      .join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PT.body.copyWith(
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          if (p.pingNote != null && p.pingNote!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('"${p.pingNote}"',
                                style: PT.secondary.copyWith(
                                    color: t.textSecondary,
                                    fontStyle: FontStyle.italic)),
                          ],
                          const SizedBox(height: 10),
                          // ⚠ Permanently visible, never hover-revealed. The
                          // Mac hides these until the pointer arrives; ported
                          // literally that would delete them outright here.
                          Row(children: [
                            PhoneBtn('+3 mo', onPressed: () async {
                              final n = DateTime.now();
                              await widget.db.setPing(
                                  p.id, DateTime(n.year, n.month + 3, n.day));
                              _refresh();
                            }),
                            const SizedBox(width: 8),
                            PhoneBtn('Dismiss',
                                variant: PhoneBtnVariant.ghost,
                                onPressed: () async {
                                  await widget.db.setPing(p.id, null);
                                  _refresh();
                                }),
                          ]),
                        ],
                      ),
                    ),
                ]),

              if (d.settle.isNotEmpty)
                PhoneSection('Money', [
                  for (final m in d.settle)
                    PhoneCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            PhoneTag(tone: t.attention, label: 'Expected'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(m.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PT.body.copyWith(
                                      color: t.textPrimary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                              '${m.direction == 'in' ? 'in' : 'out'} · '
                              '${fmtMoney(m.amountMinor, m.currency)} · '
                              'due ${fmtDate(m.date)}',
                              style: PT.secondary
                                  .copyWith(color: t.textSecondary)),
                          const SizedBox(height: 10),
                          PhoneBtn('Confirm', onPressed: () async {
                            await widget.db.settleMoney(m.id);
                            _refresh();
                          }),
                        ],
                      ),
                    ),
                ]),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRun(Occasion o) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OccasionRunScreen(db: widget.db, occasion: o),
    ));
    if (mounted) _refresh();
  }
}
