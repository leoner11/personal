import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../data/database.dart';
import '../domain/ics.dart';
import '../domain/notifications.dart';
import '../domain/money_fmt.dart';
import '../theme/tokens.dart';
import 'widgets/pickers.dart';
import 'widgets/primitives.dart';

/// Add or edit a meeting.
///
/// ⚠ The only row in this app you schedule at a TIME. Everything else is a
/// whole day: occasions are dates, pings are dates, touches record a day that
/// already happened. A meeting is 15:00, and its reminder fires an hour
/// before rather than at the 09:00 the rest of the app uses.
class MeetingSheet extends StatefulWidget {
  const MeetingSheet(
      {super.key, required this.db, this.existing, this.presetPerson});
  final AppDatabase db;
  final Meeting? existing;
  final Person? presetPerson;

  static Future<bool?> show(BuildContext c, AppDatabase db,
          {Meeting? existing, Person? presetPerson}) =>
      showDialog<bool>(
        context: c,
        builder: (_) =>
            MeetingSheet(db: db, existing: existing, presetPerson: presetPerson),
      );

  @override
  State<MeetingSheet> createState() => _MeetingSheetState();
}

class _MeetingSheetState extends State<MeetingSheet> {
  late final _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final _location =
      TextEditingController(text: widget.existing?.location ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  late DateTime _day = _initialDay();
  late TimeOfDay _time = _initialTime();
  late int _duration = widget.existing?.durationMinutes ?? 60;
  Person? _person;
  String? _personId;
  Engagement? _project;
  String? _engagementId;

  bool get _editing => widget.existing != null;

  DateTime _initialDay() {
    final e = widget.existing;
    if (e != null) return DateTime(e.startsAt.year, e.startsAt.month, e.startsAt.day);
    // ⚠ Tomorrow, not today. A meeting you are booking now is almost never in
    // the next few hours, and defaulting to today puts it in the past the
    // moment you pick a morning time.
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day);
  }

  TimeOfDay _initialTime() {
    final e = widget.existing;
    if (e != null) {
      return TimeOfDay(hour: e.startsAt.hour, minute: e.startsAt.minute);
    }
    return const TimeOfDay(hour: 10, minute: 0);
  }

  DateTime get _startsAt =>
      DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _personId = widget.presetPerson?.id ?? widget.existing?.personId;
    _person = widget.presetPerson;
    _engagementId = widget.existing?.engagementId;
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    if (_person == null && (_personId ?? '').isNotEmpty) {
      final m = await widget.db.peopleById();
      if (mounted) setState(() => _person = m[_personId]);
    }
    if ((_engagementId ?? '').isNotEmpty) {
      final m = await widget.db.engagementsById();
      if (mounted) setState(() => _project = m[_engagementId]);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  MeetingsCompanion _values() => MeetingsCompanion(
        title: Value(_title.text.trim()),
        startsAt: Value(_startsAt),
        durationMinutes: Value(_duration),
        personId: Value(_personId),
        engagementId: Value(_engagementId),
        location:
            Value(_location.text.trim().isEmpty ? null : _location.text.trim()),
        notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
      );

  Future<Meeting?> _save() async {
    if (_title.text.trim().isEmpty) return null;
    // ⚠ Mint the id here rather than reading the row back by title. insert()
    // returns a rowid, not the text key, and "the last meeting with this
    // title" picks the wrong row the moment two meetings share a name.
    final id = _editing ? widget.existing!.id : newId();
    final v = _values();

    if (_editing) {
      await widget.db.updateMeeting(id, v);
    } else {
      await widget.db.addMeeting(MeetingsCompanion.insert(
        id: Value(id),
        title: v.title.value,
        startsAt: v.startsAt.value,
        durationMinutes: v.durationMinutes,
        personId: v.personId,
        engagementId: v.engagementId,
        location: v.location,
        notes: v.notes,
      ));
    }

    // ⚠ Reschedule immediately. Notifications are derived from the database,
    // so without this a meeting booked now has no reminder until the next
    // launch — the exact hole that was closed for occasions on 11 Sep.
    await appNotifierReschedule();

    final all = await widget.db.allMeetings();
    final match = all.where((m) => m.id == id);
    return match.isEmpty ? null : match.first;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'Edit meeting' : 'New meeting',
                  style: T.screenTitle.copyWith(color: t.textPrimary)),
              const SizedBox(height: 14),
              Field(
                  label: 'What',
                  controller: _title,
                  autofocus: true,
                  hint: 'Coffee with Pak Arnold'),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: DateField(
                      label: 'Day',
                      value: _day,
                      onChanged: (d) => setState(() => _day = d)),
                ),
                const SizedBox(width: 12),
                Expanded(child: _TimeField(
                  value: _time,
                  onChanged: (v) => setState(() => _time = v),
                )),
              ]),
              const SizedBox(height: 12),
              Text('LENGTH',
                  style:
                      T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                for (final (label, mins) in const [
                  ('30 min', 30),
                  ('1 hr', 60),
                  ('2 hr', 120),
                  ('Half day', 240),
                ])
                  TagChip(
                      label: label,
                      selected: _duration == mins,
                      onTap: () => setState(() => _duration = mins)),
              ]),
              const SizedBox(height: 12),
              Field(
                  label: 'Where',
                  controller: _location,
                  hint: 'their office / Starbucks Haining'),
              const SizedBox(height: 14),
              Text('LINKS',
                  style:
                      T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              LinkBar(
                db: widget.db,
                personName: _person?.name,
                projectName: _project?.name,
                onPerson: (p) => setState(() {
                  _person = p;
                  _personId = p?.id;
                }),
                onProject: (e) => setState(() {
                  _project = e;
                  _engagementId = e?.id;
                }),
              ),
              const SizedBox(height: 12),
              Field(label: 'Notes', controller: _notes),
              const SizedBox(height: 8),
              Text(
                  'Reminder fires an hour before, at '
                  '${fmtClock(_startsAt.subtract(const Duration(hours: 1)))}.',
                  style: T.secondary.copyWith(color: t.textMuted)),
              const SizedBox(height: 18),
              Row(children: [
                if (_editing)
                  DeleteAction(
                    what: widget.existing!.title,
                    size: BtnSize.md,
                    onConfirmed: () async {
                      await widget.db.updateMeeting(widget.existing!.id,
                          MeetingsCompanion(deletedAt: Value(DateTime.now())));
                      await appNotifierReschedule();
                      if (context.mounted) Navigator.pop(context, true);
                    },
                  ),
                const Spacer(),
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context, false)),
                const SizedBox(width: 8),
                // ⚠ Says "Add to Calendar", not "Sync". It writes a .ics and
                // opens it — a snapshot Calendar.app receives once. Edits here
                // afterwards do not follow it, and the label must not imply
                // they do.
                Btn('Save + add to Calendar',
                    onPressed: _title.text.trim().isEmpty
                        ? null
                        : () async {
                            final m = await _save();
                            if (m != null) {
                              await openInCalendar(m,
                                  personName: _person?.name);
                            }
                            if (context.mounted) Navigator.pop(context, true);
                          }),
                const SizedBox(width: 8),
                Btn('Save',
                    variant: BtnVariant.primary,
                    onPressed: _title.text.trim().isEmpty
                        ? null
                        : () async {
                            await _save();
                            if (context.mounted) Navigator.pop(context, true);
                          }),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// The platform time picker behind a field that matches the design system.
class _TimeField extends StatelessWidget {
  const _TimeField({required this.value, required this.onChanged});
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TIME',
            style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: value,
              // ⚠ 24-hour. This app is used across CN, ID and MY where that is
              // the norm, and it matches fmtClock everywhere else.
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            height: D.control,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(D.radiusControl),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
                '${value.hour.toString().padLeft(2, '0')}:'
                '${value.minute.toString().padLeft(2, '0')}',
                style: T.body.copyWith(color: t.textPrimary)),
          ),
        ),
      ],
    );
  }
}
