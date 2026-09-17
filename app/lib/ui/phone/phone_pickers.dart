import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'phone_primitives.dart';

/// Phone counterparts to `widgets/pickers.dart`.
///
/// ⚠ The Mac pickers are dialogs with a text field and a scrolling list at
/// 32pt rows. Ported literally they give a phone 32pt tap targets, which is
/// below the 44pt floor. Everything here is a sheet at phone density.

/// A tappable date row. The Mac's DateField is a text input with a parser;
/// on a phone the house calendar sheet (below) is better than any field, and
/// typing a date on a soft keyboard is a chore nobody should be given.
/// v2: opens the house sheet — the Material showDatePicker died with the
/// migration (§3.3: the least native surface in the app).
class PhoneDateRow extends StatelessWidget {
  const PhoneDateRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.capPast = false,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  /// End the range today and offer only the Today chip — for "when did we
  /// meet", where +1w/+1mo/+3mo are future offsets and nonsense.
  final bool capPast;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final picked = await PhoneDateSheet.show(
              context,
              initial: value,
              capPast: capPast,
            );
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
                    fmtDate(value),
                    style: PT.body.copyWith(color: t.textPrimary),
                  ),
                ),
                AppIcon(Ic.calendar, size: 18, color: t.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The house date picker (§3.3). A sheet calendar on house tokens plus the
/// desktop DateField's quick-offset chips (`today · +1w · +1mo · +3mo`),
/// which exist because most dates in this app are "a few weeks out", not a
/// day hunted through a grid.
///
/// ⚠ Picking a day pops immediately — a date sheet has no Save, because the
/// tap IS the decision. [capPast] (person metWhen) ends the range today and
/// offers only the Today chip: future offsets are nonsense for "when did we
/// meet". The returned DateTime keeps [initial]'s time-of-day, so a meeting
/// at 15:00 stays at 15:00 when its day changes.
class PhoneDateSheet extends StatefulWidget {
  const PhoneDateSheet({
    super.key,
    required this.initial,
    required this.capPast,
  });

  final DateTime initial;
  final bool capPast;

  /// Pops with the picked date, or null on dismiss.
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initial,
    bool capPast = false,
  }) {
    return PhoneSheet.show<DateTime>(
      context,
      (context) => PhoneDateSheet(initial: initial, capPast: capPast),
    );
  }

  @override
  State<PhoneDateSheet> createState() => _PhoneDateSheetState();
}

class _PhoneDateSheetState extends State<PhoneDateSheet> {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  DateTime get _today => DateTime.now();
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month, 1);

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday-first grid of the visible month, null-padded to the first week.
  List<DateTime?> get _cells {
    final leading = (_month.weekday + 6) % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    return [
      ...List.filled(leading, null),
      for (var d = 1; d <= days; d++)
        DateTime(_month.year, _month.month, d),
    ];
  }

  bool _enabled(DateTime d) {
    if (!widget.capPast) return true;
    return !_day(d).isAfter(_day(_today));
  }

  void _pop(DateTime d) {
    final i = widget.initial;
    Navigator.pop(
        context, DateTime(d.year, d.month, d.day, i.hour, i.minute));
  }

  void _quick(int days) {
    final t = _day(_today);
    _pop(widget.capPast ? t : t.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final chips = widget.capPast
        ? [const (0, 'today')]
        : const [(0, 'today'), (7, '+1w'), (30, '+1mo'), (90, '+3mo')];
    return PhoneSheet(
      title: 'Pick a date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month nav: 44pt chevrons, the month as the position indicator.
          Row(
            children: [
              SizedBox(
                width: PD.tapMin,
                height: PD.tapMin,
                child: IconButton(
                  onPressed: () => setState(() => _month = DateTime(
                      _month.year, _month.month - 1, 1)),
                  icon: AppIcon(Ic.chevronLeft, size: 20),
                ),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: PT.entityName.copyWith(color: t.textPrimary),
                ),
              ),
              SizedBox(
                width: PD.tapMin,
                height: PD.tapMin,
                child: IconButton(
                  onPressed: () => setState(() => _month = DateTime(
                      _month.year, _month.month + 1, 1)),
                  icon: AppIcon(Ic.chevronRight, size: 20),
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Text(w,
                      textAlign: TextAlign.center,
                      style: PT.micro.copyWith(color: t.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // ⚠ Chunk by 7 with a null tail — a month that starts on Sunday
          // (March 2026) yields 37 cells, and a fractional week count
          // (`length / 7`) indexes straight past the end.
          for (var i = 0; i < _cells.length; i += 7)
            Row(
              children: [
                for (var j = i; j < i + 7; j++)
                  Expanded(
                    child: _cell(
                        j < _cells.length ? _cells[j] : null, t),
                  ),
              ],
            ),
          const SizedBox(height: PD.groupGap),
          Wrap(
            spacing: 8,
            children: [
              for (final (days, label) in chips)
                PhoneChip(
                  label: label,
                  selected: false,
                  onTap: () => _quick(days),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(DateTime? d, AppTokens t) {
    if (d == null) return const SizedBox(height: PD.tapMin);
    final selected = _day(d) == _day(widget.initial);
    final isToday = _day(d) == _day(_today);
    final enabled = _enabled(d);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _pop(d) : null,
      child: Container(
        height: PD.tapMin,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.accentWash : Colors.transparent,
          border: selected ? Border.all(color: t.accent) : null,
          borderRadius: BorderRadius.circular(D.radiusControl),
        ),
        child: Text(
          '${d.day}',
          style: PT.body.copyWith(
            color: !enabled
                ? t.textMuted
                : selected
                    ? t.accent
                    : isToday
                        ? t.accent
                        : t.textPrimary,
            fontWeight: selected || isToday ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// One row of a link: what it is now, and a button to change it.
///
/// ⚠ Always visible, never hover-revealed, and it shows "Not linked" rather
/// than hiding when empty — an invisible link control is a column with no
/// feature, which this project has already had to audit for once.
class PhoneLinkRow extends StatelessWidget {
  const PhoneLinkRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final linked = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  height: PD.control,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(D.radiusControl),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    linked ? value! : 'Not linked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PT.body.copyWith(
                      color: linked ? t.textPrimary : t.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            if (linked) ...[
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: SizedBox(
                  width: PD.tapMin,
                  height: PD.control,
                  child: Icon(Icons.close, size: 20, color: t.textMuted),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Search-and-pick, as a sheet. Returns null when dismissed.
///
/// Generic over the row type so people and projects share one implementation —
/// the Mac has two near-identical picker classes and there is no reason to
/// copy that here.
class PhonePickSheet<R> extends StatefulWidget {
  const PhonePickSheet({
    super.key,
    required this.title,
    required this.items,
    required this.label,
    required this.sublabel,
  });
  final String title;
  final List<R> items;
  final String Function(R) label;
  final String Function(R) sublabel;

  @override
  State<PhonePickSheet<R>> createState() => _PhonePickSheetState<R>();
}

class _PhonePickSheetState<R> extends State<PhonePickSheet<R>> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final rows = q.isEmpty
        ? widget.items
        : widget.items
              .where(
                (r) =>
                    widget.label(r).toLowerCase().contains(q) ||
                    widget.sublabel(r).toLowerCase().contains(q),
              )
              .toList();

    return PhoneSheet(
      title: widget.title,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhoneField(
            label: 'Search',
            controller: _search,
            hint: 'name or company',
          ),
          const SizedBox(height: PD.groupGap),
          Expanded(
            child: rows.isEmpty
                ? const PhoneEmpty('Nothing matches.')
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const PhoneDivider(),
                    itemBuilder: (_, i) => PhoneRow(
                      title: widget.label(rows[i]),
                      subtitle: widget.sublabel(rows[i]),
                      onTap: () => Navigator.pop(context, rows[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Future<Person?> pickPerson(BuildContext context, AppDatabase db) async {
  final people = await db.allPeople();
  if (!context.mounted) return null;
  return PhoneSheet.show<Person>(
    context,
    (_) => PhonePickSheet<Person>(
      title: 'Link a person',
      items: people,
      label: (p) => p.name,
      sublabel: (p) => p.company ?? '',
    ),
  );
}

Future<Engagement?> pickProject(BuildContext context, AppDatabase db) async {
  final projects = await db.watchEngagements().first;
  if (!context.mounted) return null;
  return PhoneSheet.show<Engagement>(
    context,
    (_) => PhonePickSheet<Engagement>(
      title: 'Link a project',
      items: projects,
      label: (e) => e.name,
      sublabel: (e) =>
          [e.type, if ((e.status ?? '').isNotEmpty) e.status!].join(' · '),
    ),
  );
}
