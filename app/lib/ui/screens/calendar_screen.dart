import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/agenda.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../meeting_sheet.dart';
import '../shell.dart';
import '../widgets/app_icon.dart';
import '../widgets/primitives.dart';

/// The calendar: a month grid, with the selected day's detail beneath it.
///
/// ⚠ THE GRID ALONE IS NOT ENOUGH, AND THE LIST ALONE IS NOT A CALENDAR.
/// A cell fits a number and a few dots — nowhere near "coffee with Pak Arnold,
/// 15:00, their office". But a bare agenda list, which is what this screen was
/// first built as, throws away the thing a calendar is actually for: seeing the
/// shape of a month at a glance, including the empty days. So: grid to see the
/// shape and pick a day, list underneath to read it.
///
/// ⚠ It is a VIEW over five tables plus the one it owns. Meetings live here;
/// occasions, pings, touches and money are read from where they already are,
/// so nothing can drift out of agreement with Today.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = _firstOf(DateTime.now());
  late DateTime _selected = _dayOf(DateTime.now());
  late Future<List<AgendaEntry>> _agenda = _load();

  static DateTime _firstOf(DateTime d) => DateTime(d.year, d.month);
  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// ⚠ Loads the whole visible grid, not just the month. The first and last
  /// rows show days either side of it, and a day rendered without its dots
  /// looks empty rather than out of range.
  Future<List<AgendaEntry>> _load() {
    final start = _month.subtract(Duration(days: _month.weekday - 1 + 7));
    return loadAgenda(widget.db, from: start, to: start.add(const Duration(days: 56)));
  }

  void _reload() => setState(() => _agenda = _load());

  void _go(int months) => setState(() {
        _month = DateTime(_month.year, _month.month + months);
        _agenda = _load();
        // Land on the 1st when moving months, so the detail below always
        // matches the grid above rather than showing a day you cannot see.
        _selected = _month;
      });

  void _today() => setState(() {
        _month = _firstOf(DateTime.now());
        _selected = _dayOf(DateTime.now());
        _agenda = _load();
      });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ScreenBody(
      title: 'Calendar',
      trailing: Btn('New meeting',
          variant: BtnVariant.primary,
          onPressed: () async {
            await MeetingSheet.show(context, widget.db, presetDay: _selected);
            _reload();
          }),
      child: FutureBuilder<List<AgendaEntry>>(
        future: _agenda,
        builder: (context, snap) {
          final days = byDay(snap.data ?? const <AgendaEntry>[]);
          return ListView(children: [
            Row(children: [
              Text('${_monthNames[_month.month - 1]} ${_month.year}',
                  style: T.entityName.copyWith(color: t.textPrimary)),
              const Spacer(),
              Btn('Today', size: BtnSize.sm, onPressed: _today),
              const SizedBox(width: 8),
              _Arrow(icon: Icons.chevron_left, onTap: () => _go(-1)),
              const SizedBox(width: 4),
              _Arrow(icon: Icons.chevron_right, onTap: () => _go(1)),
            ]),
            const SizedBox(height: 12),
            _MonthGrid(
              month: _month,
              selected: _selected,
              days: days,
              onPick: (d) => setState(() => _selected = d),
            ),
            const SizedBox(height: 16),
            _DayDetail(
              day: _selected,
              entries: days[_selected] ?? const [],
              db: widget.db,
              onChanged: _reload,
            ),
          ]);
        },
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: D.control,
          height: D.control,
          decoration: BoxDecoration(
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          child: Icon(icon, size: 16, color: t.textSecondary),
        ),
      ),
    );
  }
}

/// ⚠ Weeks start Monday. The whole user base is CN/ID/MY, where they do.
const _weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// The dot colour for each kind, in one place so the grid, the day list and
/// the person timeline cannot teach three different colour languages.
Tone toneFor(String kind, AppTokens t) => switch (kind) {
      'meeting' => t.success,
      'occasion' => t.attention,
      'ping' => t.info,
      'money' => t.danger,
      _ => t.neutral,
    };

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.days,
    required this.onPick,
  });
  final DateTime month;
  final DateTime selected;
  final Map<DateTime, List<AgendaEntry>> days;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // Monday of the week containing the 1st.
    final start = month.subtract(Duration(days: month.weekday - 1));
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // ⚠ Six rows always, never five. A month that needs six and a month that
    // needs five would otherwise change the height of everything below the
    // grid every time you page, which is the kind of jump that makes a UI
    // feel broken.
    const rows = 6;

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdayLabels)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(w,
                      textAlign: TextAlign.center,
                      style: T.micro
                          .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows; r++)
          // ⚠ No CrossAxisAlignment.stretch here. Inside a ListView the row's
          // height is unbounded, and stretch asks the cells to fill infinity —
          // "BoxConstraints forces an infinite height". The cells set their
          // own height instead.
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _Cell(
                    day: start.add(Duration(days: r * 7 + c)),
                    month: month,
                    selected: selected,
                    today: today,
                    entries: days[start.add(Duration(days: r * 7 + c))] ??
                        const [],
                    onPick: onPick,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.month,
    required this.selected,
    required this.today,
    required this.entries,
    required this.onPick,
  });
  final DateTime day;
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final List<AgendaEntry> entries;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final inMonth = day.month == month.month && day.year == month.year;
    final isToday = day == today;
    final isSelected = day == selected;

    // ⚠ One dot per KIND, not per entry. Four meetings in a day is one green
    // dot, not four — the cell is telling you what sort of day it is, and the
    // list below tells you the rest.
    final kinds = <String>[];
    for (final e in entries) {
      if (!kinds.contains(e.kind)) kinds.add(e.kind);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onPick(day),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 62,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isSelected ? t.accentWash : Colors.transparent,
            border: Border.all(
                color: isSelected ? t.accent : t.line,
                width: isSelected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${day.day}',
                      style: T.secondary.copyWith(
                          // Days outside the month stay visible but recede —
                          // hiding them leaves ragged holes in the grid.
                          color: !inMonth
                              ? t.textMuted
                              : isToday
                                  ? t.accent
                                  : t.textPrimary,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w500)),
                  if (isToday) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 4,
                      height: 4,
                      decoration:
                          BoxDecoration(color: t.accent, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final k in kinds.take(4))
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: toneFor(k, t).dot, shape: BoxShape.circle),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The selected day, in full. This is where the detail a grid cell cannot hold
/// actually lives.
class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.entries,
    required this.db,
    required this.onChanged,
  });
  final DateTime day;
  final List<AgendaEntry> entries;
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
          child: Text(
              '${_weekdays[day.weekday - 1]} ${fmtDate(day)}'.toUpperCase(),
              style:
                  T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        ),
        if (entries.isEmpty)
          // ⚠ Not an error state. Most days are empty, and that is the normal
          // condition of a calendar rather than something to apologise for.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('Nothing on this day.',
                style: T.body.copyWith(color: t.textMuted)),
          )
        else
          for (final e in entries)
            _EntryRow(entry: e, db: db, onChanged: onChanged),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow(
      {required this.entry, required this.db, required this.onChanged});
  final AgendaEntry entry;
  final AppDatabase db;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tone = toneFor(entry.kind, t);
    final meeting = entry.meeting;

    return MouseRegion(
      cursor: meeting == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: meeting == null
            ? null
            : () async {
                await MeetingSheet.show(context, db, existing: meeting);
                onChanged();
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: D.listRowTwoLine),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                          color: t.textPrimary, fontWeight: FontWeight.w600)),
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
            if (meeting != null) ...[
              const SizedBox(width: 6),
              Icon(Ic.calendar.glyph, size: 14, color: t.textMuted),
            ],
          ]),
        ),
      ),
    );
  }
}
