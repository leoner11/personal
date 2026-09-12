import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/agenda.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../meeting_sheet.dart';
import '../shell.dart';
import '../widgets/primitives.dart';

/// The calendar. ⚠ AN AGENDA, NOT A MONTH GRID.
///
/// A month grid spends most of its pixels on empty squares and can show maybe
/// two words per day. This app's days hold a festival, a ping and a 3pm coffee
/// with a location — none of which fit in a grid cell, and all of which are
/// the point. The agenda lists only days that contain something, in order,
/// with room for the detail.
///
/// ⚠ It is a VIEW over five tables plus one it owns. Meetings live here;
/// occasions, pings, touches and money are read from where they already are,
/// so nothing can drift out of agreement with Today.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// Whole days back, so a touch logged this morning is still visible.
  static const _lookBack = Duration(days: 30);
  static const _lookAhead = Duration(days: 120);

  late Future<List<AgendaEntry>> _agenda = _load();

  Future<List<AgendaEntry>> _load() {
    final now = DateTime.now();
    return loadAgenda(widget.db,
        from: now.subtract(_lookBack), to: now.add(_lookAhead));
  }

  void _reload() => setState(() => _agenda = _load());

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ScreenBody(
      title: 'Calendar',
      trailing: Btn('New meeting',
          variant: BtnVariant.primary,
          onPressed: () async {
            await MeetingSheet.show(context, widget.db);
            _reload();
          }),
      child: FutureBuilder<List<AgendaEntry>>(
        future: _agenda,
        builder: (context, snap) {
          final entries = snap.data ?? const <AgendaEntry>[];
          if (snap.connectionState == ConnectionState.done && entries.isEmpty) {
            return const EmptyLine('Nothing dated in this window.');
          }
          final days = byDay(entries);
          final today = DateTime.now();
          final todayKey = DateTime(today.year, today.month, today.day);

          return ListView(children: [
            for (final entry in days.entries)
              _DaySection(
                day: entry.key,
                entries: entry.value,
                isToday: entry.key == todayKey,
                isPast: entry.key.isBefore(todayKey),
                db: widget.db,
                onChanged: _reload,
              ),
            const SizedBox(height: 12),
            Text(
                'Showing ${_lookBack.inDays} days back and '
                '${_lookAhead.inDays} ahead.',
                style: T.secondary.copyWith(color: t.textMuted)),
          ]);
        },
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.entries,
    required this.isToday,
    required this.isPast,
    required this.db,
    required this.onChanged,
  });
  final DateTime day;
  final List<AgendaEntry> entries;
  final bool isToday;
  final bool isPast;
  final AppDatabase db;
  final VoidCallback onChanged;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: D.groupHeader,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.only(top: 10, bottom: 2),
          child: Row(children: [
            Text('${_weekdays[day.weekday - 1]} ${fmtDate(day)}'.toUpperCase(),
                style: T.micro.copyWith(
                    // ⚠ Today is the only day that gets the accent. Colouring
                    // more than one thing on a list of days makes none of them
                    // read as the one you are on.
                    color: isToday ? t.accent : t.textMuted,
                    letterSpacing: 0.5,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
            if (isToday) ...[
              const SizedBox(width: 8),
              Text('TODAY',
                  style: T.micro
                      .copyWith(color: t.accent, letterSpacing: 0.5)),
            ],
          ]),
        ),
        for (final e in entries)
          _EntryRow(entry: e, isPast: isPast, db: db, onChanged: onChanged),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.isPast,
    required this.db,
    required this.onChanged,
  });
  final AgendaEntry entry;
  final bool isPast;
  final AppDatabase db;
  final VoidCallback onChanged;

  /// ⚠ Dot colour by kind, from the five tones the design system defines —
  /// no new colours. Meetings are the thing this screen exists for, so they
  /// take the strongest one.
  Tone _tone(AppTokens t) => switch (entry.kind) {
        'meeting' => t.success,
        'occasion' => t.attention,
        'ping' => t.info,
        'money' => t.danger,
        _ => t.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tone = _tone(t);
    final meeting = entry.meeting;

    return MouseRegion(
      cursor: meeting == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: meeting == null
            ? null
            : () async {
                await MeetingSheet.show(context, db, existing: meeting);
                onChanged();
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: D.listRowTwoLine),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: tone.dot, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 10),
            // Fixed gutter so titles line up whether or not there is a time.
            SizedBox(
              width: 46,
              child: Text(entry.hasTime ? fmtClock(entry.at) : '',
                  style: T.mono.copyWith(color: t.textSecondary)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(
                          // ⚠ Past days are muted, not hidden. "When did I
                          // last see him" is the same question as "when am I
                          // seeing him next", asked backwards.
                          color: isPast ? t.textSecondary : t.textPrimary,
                          fontWeight: FontWeight.w600)),
                  if ((entry.subtitle ?? '').isNotEmpty)
                    Text(entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.secondary.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusTag(tone: tone, label: entry.kind),
          ]),
        ),
      ),
    );
  }
}
