import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/agenda.dart';
import '../../domain/ics.dart';
import '../../domain/money_fmt.dart';
import '../../domain/notifications.dart';
import '../../domain/tag_vocab.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'occasion_run_screen.dart';
import 'phone_pickers.dart';
import 'occasion_tag_sheets.dart';
import 'phone_primitives.dart';

/// The fourth tab — the glanceable month (Phone Design v2.0 §2, the new tab
/// that absorbs the occasions browse the phone IA never had).
///
/// ⚠ THE GRID ALONE IS NOT ENOUGH, AND THE LIST ALONE IS NOT A CALENDAR —
/// the desktop calendar_screen.dart said it first and it holds at 390pt:
/// grid to see the shape and pick a day, list underneath to read it.
///
/// ⚠ A VIEW OVER SHARED DOMAIN LOGIC. Days come from `loadAgenda`/`byDay`, so
/// the phone cannot drift from the Mac about what a day contains. The grid
/// renders only three kinds — meeting, task, occasion. Pings and money dates
/// are excluded on purpose: the Pings and Money sections on Today already own
/// those verbs (+3 mo / Confirm), and a dot here would advertise a nudge
/// whose action lives elsewhere. No pull-to-refresh: not in §3.4's list, data
/// is local and instant, and faking a reload is banned.
class PhoneCalendarScreen extends StatefulWidget {
  const PhoneCalendarScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhoneCalendarScreen> createState() => _PhoneCalendarScreenState();
}

/// Months are addressed by index against this anchor: page 0 is Jan 2020.
final DateTime _kMonthAnchor = DateTime(2020, 1);
const int _kPageCount = 12 * 100;

/// ⚠ Weeks start Monday. The whole user base is CN/ID/MY, where they do.
const _weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// The dot colour for each kind — desktop `calendar_screen.dart`'s
/// `toneFor()`, verbatim, so the grid, the day list and the Mac cannot teach
/// two colour languages.
///
/// ⚠ No sixth semantic tone exists, and every one of the five is taken, so
/// tasks borrow the accent rather than doubling up on a meaning. In dark mode
/// the accent inverts (#7FC4A3) and the borrow still reads.
Tone toneFor(String kind, AppTokens t) => switch (kind) {
      'meeting' => t.success,
      'task' => Tone(dot: t.accent, wash: t.accentWash, text: t.accent),
      'occasion' => t.attention,
      _ => t.neutral,
    };

class _PhoneCalendarScreenState extends State<PhoneCalendarScreen> {
  late final PageController _controller = PageController(
    initialPage: _pageIndex(DateTime.now()),
  );
  late int _page = _controller.initialPage;

  /// Bumped after a sheet saves or deletes — every mounted month page listens
  /// and re-runs its agenda query, so the dot appears on the next tick.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// The selected day, whatever page it lives on — the plus uses it as the
  /// preset so "New meeting while looking at 20 Oct" books 20 Oct.
  final ValueNotifier<DateTime> _selectedDay = ValueNotifier<DateTime>(
    _dayOf(DateTime.now()),
  );

  static int _pageIndex(DateTime m) =>
      (m.year - _kMonthAnchor.year) * 12 + m.month - _kMonthAnchor.month;

  static DateTime _monthOf(int i) => DateTime(
    _kMonthAnchor.year + i ~/ 12,
    _kMonthAnchor.month + i % 12,
  );

  @override
  void dispose() {
    _controller.dispose();
    _revision.dispose();
    _selectedDay.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final choice = await PhoneSheet.show<String>(
      context,
      (sheetContext) => PhoneSheet(
        title: 'Add to calendar',
        child: Column(
          children: [
            PhoneRow(
              title: 'Meeting',
              leading: AppIcon(Ic.calendar, size: 22),
              minHeight: PD.listRow,
              onTap: () => Navigator.pop(sheetContext, 'meeting'),
            ),
            PhoneRow(
              title: 'Task',
              leading: AppIcon(Ic.tasks, size: 22),
              minHeight: PD.listRow,
              onTap: () => Navigator.pop(sheetContext, 'task'),
            ),
            // The occasions browse this tab absorbs was maintenance, not
            // just reading: Lebaran / Idul Adha / Deepavali move on
            // sighting, and the seeded estimate must be correctable here.
            PhoneRow(
              title: 'Occasion',
              leading: AppIcon(Ic.occasions, size: 22),
              minHeight: PD.listRow,
              onTap: () => Navigator.pop(sheetContext, 'occasion'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final preset = _dayOf(_selectedDay.value);
    final changed = await PhoneSheet.show<bool>(
      context,
      (_) => switch (choice) {
        'meeting' => PhoneMeetingSheet(db: widget.db, presetDay: preset),
        'task' => PhoneTaskSheet(db: widget.db, presetDay: preset),
        _ => PhoneOccasionSheet(db: widget.db, presetDay: preset),
      },
    );
    if (changed == true) _revision.value++;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final month = _monthOf(_page);
    return PhoneScaffold(
      title: 'Calendar',
      // One plus, then a choice (§3.1: two nav-bar slots would both burn on
      // glyphs that don't read as "new meeting / new task" to anyone who
      // hasn't learned them).
      actions: [
        PhonePressable(
          onTap: _add,
          pressedScale: 0.9,
          child: SizedBox(
            width: PD.tapMin,
            height: PD.tapMin,
            child: Center(child: AppIcon(Ic.add, size: 26, color: t.accent)),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The sticky month label IS the swipe position indicator (§3.6:
          // system paging, house type). It updates on page change.
          Center(
            child: Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              style: PT.entityName.copyWith(color: t.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final w in _weekdayLabels)
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: PT.micro.copyWith(
                      color: t.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _kPageCount,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) =>
                  _MonthPage(db: widget.db, month: _monthOf(i), revision: _revision, selectedDay: _selectedDay),
            ),
          ),
        ],
      ),
    );
  }
}

/// One month, grid plus the selected day's detail. Holds its own selection
/// and its own agenda query — paging to a month must not reset the one you
/// left, and it must not keep six months of entries in memory either.
class _MonthPage extends StatefulWidget {
  const _MonthPage({
    required this.db,
    required this.month,
    required this.revision,
    required this.selectedDay,
  });

  final AppDatabase db;
  final DateTime month;
  final ValueNotifier<int> revision;
  final ValueNotifier<DateTime> selectedDay;

  @override
  State<_MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<_MonthPage> {
  late DateTime _selected = _initialSelected();
  late Future<List<AgendaEntry>> _agenda = _load();
  Map<String, Occasion> _occasions = const {};

  DateTime _initialSelected() {
    final today = _dayOf(DateTime.now());
    final first = _dayOf(widget.month);
    // Today gets the selection; any other month lands on the 1st so the
    // detail always matches a day the grid can show.
    if (today.year == first.year && today.month == first.month) return today;
    return first;
  }

  /// ⚠ Loads the whole visible grid, not just the month — the first and last
  /// rows show days either side of it, and a day rendered without its dots
  /// looks empty rather than out of range.
  Future<List<AgendaEntry>> _load() async {
    final start = _dayOf(widget.month).subtract(
      Duration(days: widget.month.weekday - 1),
    );
    final entries = await loadAgenda(
      widget.db,
      from: start,
      to: start.add(const Duration(days: 42)),
    );
    final occasions = await widget.db.allOccasions();
    if (mounted) {
      setState(() {
        _occasions = {
          for (final o in occasions)
            '${o.name}@${_dayOf(o.date).millisecondsSinceEpoch}': o,
        };
      });
    }
    // ⚠ Three kinds only — see the screen's comment. loadAgenda returns all
    // six; the phone grid keeps the ones whose action lives here.
    return entries
        .where(
          (e) => e.kind == 'meeting' || e.kind == 'task' || e.kind == 'occasion',
        )
        .toList();
  }

  void _reload() {
    if (!mounted) return;
    // ⚠ Block body, not an arrow: `() => _agenda = _load()` returns the
    // assigned Future and setState asserts on a non-void callback — every
    // add from the choice sheet tripped it.
    setState(() {
      _agenda = _load();
    });
  }

  @override
  void initState() {
    super.initState();
    widget.revision.addListener(_reload);
  }

  @override
  void dispose() {
    widget.revision.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AgendaEntry>>(
      future: _agenda,
      builder: (context, snap) {
        final days = byDay(snap.data ?? const <AgendaEntry>[]);
        final entries = days[_dayOf(_selected)] ?? const <AgendaEntry>[];
        return Column(
          children: [
            _MonthGrid(
              month: _dayOf(widget.month),
              selected: _selected,
              days: days,
              onPick: (d) {
                setState(() => _selected = d);
                widget.selectedDay.value = d;
              },
            ),
            const PhoneDivider(),
            Expanded(
              child: _DayDetail(
                day: _selected,
                entries: entries,
                occasions: _occasions,
                db: widget.db,
                onChanged: () => widget.revision.value++,
              ),
            ),
          ],
        );
      },
    );
  }
}

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
    // Monday of the week containing the 1st.
    final start = month.subtract(Duration(days: month.weekday - 1));

    // ⚠ Six rows always, never five. A month that needs six and a month that
    // needs five would otherwise change the height of everything below the
    // grid every time you page, which is the kind of jump that makes a UI
    // feel broken.
    const rows = 6;

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _CalendarCell(
                    day: start.add(Duration(days: r * 7 + c)),
                    month: month,
                    selected: selected,
                    entries:
                        days[start.add(Duration(days: r * 7 + c))] ??
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

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.month,
    required this.selected,
    required this.entries,
    required this.onPick,
  });
  final DateTime day;
  final DateTime month;
  final DateTime selected;
  final List<AgendaEntry> entries;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final inMonth = day.month == month.month && day.year == month.year;
    final isToday = day == _dayOf(DateTime.now());
    final isSelected = day == selected;

    // ⚠ One dot per KIND, not per entry. Four meetings in a day is one green
    // dot, not four — the cell tells you what sort of day it is, and the list
    // below tells you the rest. take(4) is the desktop cap, kept as grammar.
    final kinds = <String>[];
    for (final e in entries) {
      if (!kinds.contains(e.kind)) kinds.add(e.kind);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onPick(day),
      child: Container(
        height: 48,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? t.accentWash : Colors.transparent,
          border: Border.all(
            color: isSelected ? t.accent : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(D.radiusControl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${day.day}',
                  style: PT.secondary.copyWith(
                    // Days outside the month stay visible but recede — hiding
                    // them leaves ragged holes in the grid.
                    color: !inMonth
                        ? t.textMuted
                        : isToday || isSelected
                        ? t.accent
                        : t.textPrimary,
                    fontWeight: isToday
                        ? FontWeight.w700
                        : isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
                // The today marker: a 4pt accent dot beside the numeral —
                // desktop exact, and the numeral alone would vanish among
                // w500 neighbours.
                if (isToday) ...[
                  const SizedBox(width: 3),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 3,
              runSpacing: 2,
              children: [
                for (final k in kinds.take(4))
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: toneFor(k, t).dot,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected day, in full — where the detail a cell cannot hold lives.
/// ⚠ An empty day renders NOTHING: no header, no filler line. Most days are
/// empty and that is the calendar's normal condition, not something to
/// apologise for. The tinted cell still shows, so the tap registers.
class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.entries,
    required this.occasions,
    required this.db,
    required this.onChanged,
  });
  final DateTime day;
  final List<AgendaEntry> entries;
  final Map<String, Occasion> occasions;
  final AppDatabase db;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final t = AppTokens.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PD.screenPad,
        6,
        PD.screenPad,
        PD.sectionGap,
      ),
      children: [
        Container(
          height: PD.groupHeader,
          alignment: Alignment.centerLeft,
          child: Text(
            '${_weekdayShort[day.weekday - 1]} ${fmtDate(day)}'.toUpperCase(),
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
          ),
        ),
        for (final e in entries)
          _DayRow(
            entry: e,
            db: db,
            occasions: occasions,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.entry,
    required this.db,
    required this.occasions,
    required this.onChanged,
  });
  final AgendaEntry entry;
  final AppDatabase db;
  final Map<String, Occasion> occasions;
  final VoidCallback onChanged;

  bool get _isOccasion => entry.kind == 'occasion';

  /// Occasion entries carry no row object (loadAgenda rebuilds them from the
  /// people table every time), so the run screen's occasion is matched back
  /// by name and day — both are stable, and the run screen re-derives its
  /// recipients itself.
  Occasion? get _occasion =>
      occasions['${entry.title}@${entry.day.millisecondsSinceEpoch}'];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tone = toneFor(entry.kind, t);
    final done = entry.task?.doneAt != null;

    return GestureDetector(
      // ⚠ Tap stays the run screen (§3.1: the B3 loop); long-press is the
      // maintenance surface — correct a drifted date or remove a row.
      onLongPress: (_isOccasion && _occasion != null)
          ? () => _occasionMenu(context)
          : null,
      child: PhonePressable(
        onTap: entry.meeting != null
            ? () async {
                final changed = await PhoneSheet.show<bool>(
                  context,
                  (_) => PhoneMeetingSheet(db: db, existing: entry.meeting),
                );
                if (changed == true) onChanged();
              }
            : entry.task != null
            ? () async {
                final changed = await PhoneSheet.show<bool>(
                  context,
                  (_) => PhoneTaskSheet(db: db, existing: entry.task),
                );
                if (changed == true) onChanged();
              }
            : (_isOccasion && _occasion != null)
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      OccasionRunScreen(db: db, occasion: _occasion!),
                ),
              )
            : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: PD.listRow),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tone.dot,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Fixed gutter so titles line up whether or not there is a
              // time. ⚠ Meetings are the only kind with a clock; rendering
              // one against a festival would invent precision the data
              // lacks.
              SizedBox(
                width: 52,
                child: Text(
                  entry.hasTime ? fmtClock(entry.at) : '',
                  style: PT.mono.copyWith(color: t.textSecondary),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PT.body.copyWith(
                        color: done ? t.textMuted : t.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((entry.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PT.secondary.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // The tag is what decodes the dots — house rule, colour never
              // alone.
              PhoneTag(tone: tone, label: entry.kind),
              if (_isOccasion) ...[
                const SizedBox(width: 6),
                AppIcon(Ic.chevronRight, size: 20, color: t.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The long-press maintenance menu for an occasion row. The verbs are the
  /// Mac sheet's verbs: edit (correct the date the announcement fixed) and
  /// delete (soft, behind the house confirm).
  Future<void> _occasionMenu(BuildContext context) async {
    final occasion = _occasion;
    if (occasion == null) return;
    await showPhoneMenu(
      context,
      title: occasion.name,
      items: [
        PhoneMenuItem(
          'Edit',
          icon: Ic.pencil,
          onTap: () => _editOccasion(context, occasion),
        ),
        PhoneMenuItem(
          'Delete',
          icon: Ic.dismiss,
          danger: true,
          onTap: () => _deleteOccasion(context, occasion),
        ),
      ],
    );
  }

  Future<void> _editOccasion(BuildContext context, Occasion occasion) async {
    final changed = await PhoneSheet.show<bool>(
      context,
      (_) => PhoneOccasionSheet(db: db, existing: occasion),
    );
    if (changed == true) onChanged();
  }

  Future<void> _deleteOccasion(
      BuildContext context, Occasion occasion) async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete "${occasion.name}"?',
      body: 'The occasion is kept so the other device learns it is gone.',
    );
    if (!ok) return;
    await db.softDeleteRow(db.occasions, occasion.id);
    onChanged();
  }
}

/// Add or edit a meeting — desktop `MeetingSheet`'s field set re-expressed at
/// phone density (§3.3: a sheet, never a push).
///
/// ⚠ The only row in this app you schedule at a TIME. Everything else is a
/// whole day; a meeting is 15:00, and its reminder fires an hour before.
class PhoneMeetingSheet extends StatefulWidget {
  const PhoneMeetingSheet({super.key, required this.db, this.existing, this.presetDay});
  final AppDatabase db;
  final Meeting? existing;

  /// The day the calendar was showing. ⚠ Without it, tapping 20 October and
  /// pressing New meeting hands you tomorrow — and the mistake is easy to
  /// miss because the field looks filled in.
  final DateTime? presetDay;

  @override
  State<PhoneMeetingSheet> createState() => _PhoneMeetingSheetState();
}

class _PhoneMeetingSheetState extends State<PhoneMeetingSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _location = TextEditingController(
    text: widget.existing?.location ?? '',
  );
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  late DateTime _day = _initialDay();
  late TimeOfDay _time = _initialTime();
  late int _duration = widget.existing?.durationMinutes ?? 60;
  Person? _person;
  String? _personId;

  bool get _editing => widget.existing != null;

  DateTime _initialDay() {
    final e = widget.existing;
    if (e != null) return _dayOf(e.startsAt);
    final preset = widget.presetDay;
    if (preset != null) return _dayOf(preset);
    // ⚠ Tomorrow, not today. A meeting you are booking now is almost never
    // in the next few hours, and defaulting to today puts it in the past the
    // moment you pick a morning time.
    final t = DateTime.now().add(const Duration(days: 1));
    return _dayOf(t);
  }

  TimeOfDay _initialTime() {
    final e = widget.existing;
    if (e != null) return TimeOfDay(hour: e.startsAt.hour, minute: e.startsAt.minute);
    return const TimeOfDay(hour: 10, minute: 0);
  }

  DateTime get _startsAt =>
      DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  /// The id this sheet owns once anything has been written. See [_persist].
  String? _savedId;
  bool _written = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _personId = widget.existing?.personId;
    if ((_personId ?? '').isNotEmpty) {
      widget.db.peopleById().then((m) {
        if (mounted) setState(() => _person = m[_personId]);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneSheet(
      title: _editing ? 'Edit meeting' : 'New meeting',
      expand: true,
      actions: Row(
        children: [
          if (_editing)
            Expanded(
              flex: 1,
              child: PhoneBtn(
                'Delete',
                variant: PhoneBtnVariant.danger,
                onPressed: _confirmDelete,
              ),
            )
          else
            Expanded(
              flex: 1,
              child: PhoneBtn(
                'Cancel',
                variant: PhoneBtnVariant.ghost,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: PhoneBtn(
              'Save',
              variant: PhoneBtnVariant.primary,
              onPressed: _title.text.trim().isEmpty ? null : _save,
            ),
          ),
        ],
      ),
      child: ListView(
        children: [
          PhoneField(
            label: 'What',
            controller: _title,
            hint: 'Coffee with Pak Arnold',
            autofocus: !_editing,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.groupGap),
          PhoneDateRow(
            label: 'Day',
            value: _day,
            onChanged: (d) => setState(() => _day = _dayOf(d)),
          ),
          const SizedBox(height: PD.groupGap),
          _TimeRow(
            value: _time,
            onChanged: (v) => setState(() => _time = v),
          ),
          const SizedBox(height: PD.sectionGap),
          Text(
            'LENGTH',
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, mins) in const [
                ('30 min', 30),
                ('1 hr', 60),
                ('2 hr', 120),
                ('Half day', 240),
              ])
                PhoneChip(
                  label: label,
                  selected: _duration == mins,
                  onTap: () => setState(() => _duration = mins),
                ),
            ],
          ),
          const SizedBox(height: PD.sectionGap),
          PhoneField(
            label: 'Where',
            controller: _location,
            hint: 'their office / Starbucks Haining',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.groupGap),
          PhoneLinkRow(
            label: 'Person',
            value: _person?.name,
            onTap: () async {
              final p = await pickPerson(context, widget.db);
              if (p == null) return;
              setState(() {
                _person = p;
                _personId = p.id;
              });
            },
            onClear: () => setState(() {
              _person = null;
              _personId = null;
            }),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(
            label: 'Notes',
            controller: _notes,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: PD.groupGap),
          Text(
            'Reminder fires an hour before, at '
            '${fmtClock(_startsAt.subtract(const Duration(hours: 1)))}.',
            style: PT.secondary.copyWith(color: t.textMuted),
          ),
          const SizedBox(height: PD.sectionGap),
          // ⚠ A ROW IN THE BODY, not a third button in the actions bar. Three
          // buttons across a phone sheet leaves none of them tappable at 44pt,
          // and this is not the primary action — Save is.
          //
          // ⚠ Says "Add to calendar", not "Sync". It hands the system a .ics
          // snapshot, once. Edits made here afterwards do not follow it, and
          // the label must not imply they do.
          PhoneRow(
            title: 'Add to calendar',
            subtitle: _written || _editing
                ? 'A copy, taken now — later edits here will not follow it.'
                : 'Saves first, then hands it to your calendar app.',
            leading: AppIcon(Ic.calendar, size: 22, color: t.textSecondary),
            chevron: true,
            onTap: _title.text.trim().isEmpty ? null : _addToCalendar,
          ),
        ],
      ),
    );
  }

  /// Writes the meeting and hands it back.
  ///
  /// ⚠ IDEMPOTENT, unlike the desktop's equivalent. There the dialog always
  /// pops straight after saving, so minting an id per call is safe. Here
  /// 'Add to calendar' saves and then STAYS OPEN — a second call that minted
  /// another id would leave two meetings behind, one of them invisible to the
  /// sheet that made it. The id is minted once and reused.
  Future<Meeting?> _persist() async {
    final title = _title.text.trim();
    if (title.isEmpty) return null;
    final location = _location.text.trim();
    final notes = _notes.text.trim();

    final id = _savedId ??= widget.existing?.id ?? newId();
    final wasWritten = _editing || _written;

    if (wasWritten) {
      await widget.db.updateMeeting(
        id,
        MeetingsCompanion(
          title: Value(title),
          startsAt: Value(_startsAt),
          durationMinutes: Value(_duration),
          personId: Value(_personId),
          location: Value(location.isEmpty ? null : location),
          notes: Value(notes.isEmpty ? null : notes),
        ),
      );
    } else {
      // ⚠ Mint the id here rather than reading the row back by title — see
      // the desktop MeetingSheet; insert() returns a rowid, not the key.
      await widget.db.addMeeting(
        MeetingsCompanion.insert(
          id: Value(id),
          title: title,
          startsAt: _startsAt,
          durationMinutes: Value(_duration),
          personId: Value(_personId),
          location: Value(location.isEmpty ? null : location),
          notes: Value(notes.isEmpty ? null : notes),
        ),
      );
      _written = true;
    }

    // ⚠ Reschedule immediately. Notifications are derived from the database,
    // so without this a meeting booked now has no reminder until the next
    // launch.
    await appNotifierReschedule();

    final all = await widget.db.allMeetings();
    final match = all.where((m) => m.id == id);
    return match.isEmpty ? null : match.first;
  }

  Future<void> _save() async {
    if (await _persist() == null) return;
    if (mounted) Navigator.pop(context, true);
  }

  /// Saves, then hands the .ics to the system calendar.
  ///
  /// ⚠ SAVES FIRST, ALWAYS. Exporting an unsaved sheet would put an event in
  /// the phone's calendar that this app has no record of — and the reminder,
  /// which is derived from the database, would never fire for it.
  ///
  /// ⚠ DOES NOT POP. The share sheet is a system surface the user can cancel,
  /// and popping underneath it would make a cancel look like a save that
  /// silently closed. They stay here and decide.
  Future<void> _addToCalendar() async {
    final m = await _persist();
    if (m == null || !mounted) return;
    setState(() {});
    await openInCalendar(m, personName: _person?.name);
  }

  Future<void> _confirmDelete() async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete "${widget.existing!.title}"?',
      body: 'The meeting is kept so the other device learns it is gone.',
    );
    if (!ok) return;
    await widget.db.updateMeeting(
      widget.existing!.id,
      MeetingsCompanion(deletedAt: Value(DateTime.now())),
    );
    // ⚠ A deleted meeting must stop its reminder too.
    await appNotifierReschedule();
    if (mounted) Navigator.pop(context, true);
  }
}

/// The platform time picker behind a field that matches the design system.
/// ⚠ showTimePicker is NOT in the banned set (§ ship checklist names the date
/// picker and AlertDialog); a house time sheet would be a new surface for a
/// verb used in exactly one place.
class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.value, required this.onChanged});
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIME',
          style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: value);
            if (picked != null) onChanged(picked);
          },
          child: Container(
            height: PD.control,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(D.radiusControl),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.format(context),
                    style: PT.body.copyWith(color: t.textPrimary),
                  ),
                ),
                AppIcon(Ic.snooze, size: 18, color: t.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Add or edit a task — desktop `TaskSheet`'s field set at phone density.
/// ⚠ Everything but the title is optional; most tasks are a line on a
/// checklist, and the sheet must not make that feel like an incomplete form.
class PhoneTaskSheet extends StatefulWidget {
  const PhoneTaskSheet({super.key, required this.db, this.existing, this.presetDay});
  final AppDatabase db;
  final Task? existing;
  final DateTime? presetDay;

  @override
  State<PhoneTaskSheet> createState() => _PhoneTaskSheetState();
}

class _PhoneTaskSheetState extends State<PhoneTaskSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  late DateTime? _due = _normalizeDue();

  /// Existing wins; a new task inherits the tapped day when there is one.
  /// Null stays null — "No date" is a real answer, not a missing one.
  DateTime? _normalizeDue() {
    final raw = widget.existing?.dueDate ??
        (widget.existing == null ? widget.presetDay : null);
    return raw == null ? null : _dayOf(raw);
  }
  late bool _done = widget.existing?.doneAt != null;
  Person? _person;
  String? _personId;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _personId = widget.existing?.personId;
    if ((_personId ?? '').isNotEmpty) {
      widget.db.peopleById().then((m) {
        if (mounted) setState(() => _person = m[_personId]);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await PhoneDateSheet.show(
      context,
      initial: _due ?? DateTime.now(),
    );
    if (picked != null) setState(() => _due = _dayOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final today = _dayOf(DateTime.now());
    return PhoneSheet(
      title: _editing ? 'Edit task' : 'New task',
      expand: true,
      actions: Row(
        children: [
          if (_editing)
            Expanded(
              flex: 1,
              child: PhoneBtn(
                'Delete',
                variant: PhoneBtnVariant.danger,
                onPressed: _confirmDelete,
              ),
            )
          else
            Expanded(
              flex: 1,
              child: PhoneBtn(
                'Cancel',
                variant: PhoneBtnVariant.ghost,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: PhoneBtn(
              'Save',
              variant: PhoneBtnVariant.primary,
              onPressed: _title.text.trim().isEmpty ? null : _save,
            ),
          ),
        ],
      ),
      child: ListView(
        children: [
          PhoneField(
            label: 'What',
            controller: _title,
            hint: 'Send Pak Arnold the quotation',
            autofocus: !_editing,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.sectionGap),
          Text(
            'DUE',
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PhoneChip(
                label: 'No date',
                selected: _due == null,
                onTap: () => setState(() => _due = null),
              ),
              for (final (label, days) in const [
                ('Today', 0),
                ('Tomorrow', 1),
                ('+1 week', 7),
              ])
                PhoneChip(
                  label: label,
                  selected: _due == today.add(Duration(days: days)),
                  onTap: () =>
                      setState(() => _due = today.add(Duration(days: days))),
                ),
              PhoneChip(
                label: _due == null ? 'Pick a day' : fmtDate(_due!),
                selected: false,
                onTap: _pickDay,
              ),
            ],
          ),
          const SizedBox(height: PD.groupGap),
          PhoneLinkRow(
            label: 'Person',
            value: _person?.name,
            onTap: () async {
              final p = await pickPerson(context, widget.db);
              if (p == null) return;
              setState(() {
                _person = p;
                _personId = p.id;
              });
            },
            onClear: () => setState(() {
              _person = null;
              _personId = null;
            }),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(
            label: 'Notes',
            controller: _notes,
            textInputAction: TextInputAction.done,
          ),
          if (_editing) ...[
            const SizedBox(height: PD.groupGap),
            // The done verb on the calendar is an edit, not the queue's check
            // — Today owns the one-tap tick (§3.6's draw stays there).
            Wrap(
              children: [
                PhoneChip(
                  label: _done ? 'Done' : 'Mark done',
                  selected: _done,
                  onTap: () => setState(() => _done = !_done),
                ),
              ],
            ),
          ],
          if (_due != null && !_done) ...[
            const SizedBox(height: 8),
            Text(
              'Reminder fires at 09:00 on ${fmtDate(_due!)}.',
              style: PT.secondary.copyWith(color: t.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final notes = _notes.text.trim();
    final e = widget.existing;

    if (e != null) {
      await widget.db.updateTask(
        e.id,
        TasksCompanion(
          title: Value(title),
          notes: Value(notes.isEmpty ? null : notes),
          dueDate: Value(_due),
          // ⚠ Keep the original stamp when it was already done. Re-saving a
          // task ticked off last week to fix a typo must not claim it was
          // done today.
          doneAt: Value(_done ? (e.doneAt ?? DateTime.now()) : null),
          personId: Value(_personId),
        ),
      );
    } else {
      await widget.db.addTask(
        TasksCompanion.insert(
          title: title,
          notes: Value(notes.isEmpty ? null : notes),
          dueDate: Value(_due),
          personId: Value(_personId),
          createdAt: Value(DateTime.now()),
        ),
      );
    }

    // ⚠ Reminders are derived from the database; without this a task dated
    // now has no reminder until the next launch.
    await appNotifierReschedule();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _confirmDelete() async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete "${widget.existing!.title}"?',
      body: 'The task is kept so the other device learns it is gone.',
    );
    if (!ok) return;
    await widget.db.updateTask(
      widget.existing!.id,
      TasksCompanion(deletedAt: Value(DateTime.now())),
    );
    await appNotifierReschedule();
    if (mounted) Navigator.pop(context, true);
  }
}

/// Add (and edit) an occasion — the desktop `OccasionSheet`'s contract at
/// phone density, reached from the calendar's one-plus choice sheet.
///
/// ⚠ WHY THIS EXISTS ON THE PHONE: Lebaran, Idul Adha and Deepavali move on
/// moon sighting, and the three-year seed is deliberately an ESTIMATE that
/// drifts ±1–2 days. "Correct it when the real announcement lands" is the
/// annual maintenance this app accepts — and until now the phone had no path
/// to do it at all. The tag decides who gets prompted; the name is optional
/// and falls back to the tag's label, exactly as the Mac saves.
class PhoneOccasionSheet extends StatefulWidget {
  const PhoneOccasionSheet({super.key, required this.db, this.existing, this.presetDay});
  final AppDatabase db;
  final Occasion? existing;

  /// The day the calendar was showing, inherited like the meeting and task
  /// sheets so adding from a chosen day starts where the thumb is.
  final DateTime? presetDay;

  @override
  State<PhoneOccasionSheet> createState() => _PhoneOccasionSheetState();
}

class _PhoneOccasionSheetState extends State<PhoneOccasionSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _country = TextEditingController(
    text: widget.existing?.country ?? '',
  );
  late final _greeting = TextEditingController(
    text: widget.existing?.greeting ?? '',
  );
  late DateTime _date = _initialDay();
  /// A slug from the vocabulary. See [TagVocab.defaultSlug] for why the
  /// default is newYear-if-present rather than a hardcoded newYear.
  late String _tag = widget.existing?.tag ?? TagVocab.defaultSlug;

  bool get _editing => widget.existing != null;

  DateTime _initialDay() {
    final e = widget.existing;
    if (e != null) return _dayOf(e.date);
    final preset = widget.presetDay;
    if (preset != null) return _dayOf(preset);
    return _dayOf(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _greeting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneSheet(
      title: _editing ? 'Edit occasion' : 'New occasion',
      expand: true,
      actions: Row(
        children: [
          if (_editing)
            Expanded(
              flex: 1,
              child: PhoneBtn(
                'Delete',
                variant: PhoneBtnVariant.danger,
                onPressed: _confirmDelete,
              ),
            )
          else
            Expanded(
              flex: 1,
              child: PhoneBtn(
                'Cancel',
                variant: PhoneBtnVariant.ghost,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            // ⚠ Name is optional — an empty one saves as the tag's label
            // (the desktop sheet's rule), so Save never disables here.
            child: PhoneBtn(
              'Save',
              variant: PhoneBtnVariant.primary,
              onPressed: _save,
            ),
          ),
        ],
      ),
      child: ListView(
        children: [
          PhoneField(
            label: 'Name',
            controller: _name,
            hint: TagVocab.labelFor(_tag),
            autofocus: !_editing,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.groupGap),
          PhoneDateRow(
            label: 'Date',
            value: _date,
            onChanged: (d) => setState(() => _date = _dayOf(d)),
          ),
          const SizedBox(height: PD.sectionGap),
          Text(
            'TAG',
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<List<OccasionTagRow>>(
            valueListenable: TagVocab.all,
            builder: (context, _, _) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in TagVocab.live)
                  PhoneChip(
                    label: tag.label,
                    selected: _tag == tag.slug,
                    onTap: () => setState(() => _tag = tag.slug),
                  ),
                NewTagChip(
                    db: widget.db,
                    onCreated: (slug) => setState(() => _tag = slug)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Decides who gets prompted — people carrying this tag.',
            style: PT.secondary.copyWith(color: t.textMuted),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(
            label: 'Country',
            controller: _country,
            hint: 'ID/MY',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.groupGap),
          // Phase 3: the greeting lives on the occasion. Empty = the tag's
          // standard template still applies on the run screen.
          PhoneField(
            label: 'Greeting',
            controller: _greeting,
            hint: 'Happy Thanksgiving! — empty uses the tag template',
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    // The desktop sheet's rule verbatim: an unnamed occasion IS its tag.
    final name = _name.text.trim().isEmpty
        ? TagVocab.labelFor(_tag)
        : _name.text.trim();
    final country = _country.text.trim();
    final greeting = _greeting.text.trim();
    if (_editing) {
      await (widget.db.update(widget.db.occasions)
            ..where((o) => o.id.equals(widget.existing!.id)))
          .write(OccasionsCompanion(
        name: Value(name),
        date: Value(_date),
        tag: Value(_tag),
        country: Value(country.isEmpty ? null : country),
        greeting: Value(greeting.isEmpty ? null : greeting),
        updatedAt: Value(DateTime.now()),
      ));
    } else {
      await widget.db.into(widget.db.occasions).insert(
            OccasionsCompanion.insert(
              name: name,
              date: _date,
              tag: _tag,
              country: Value(country.isEmpty ? null : country),
              greeting: Value(greeting.isEmpty ? null : greeting),
            ),
          );
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _confirmDelete() async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete "${widget.existing!.name}"?',
      body: 'The occasion is kept so the other device learns it is gone.',
    );
    if (!ok) return;
    await widget.db.softDeleteRow(widget.db.occasions, widget.existing!.id);
    if (mounted) Navigator.pop(context, true);
  }
}
