import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../data/database.dart';
import '../domain/money_fmt.dart';
import '../domain/notifications.dart';
import '../theme/tokens.dart';
import 'widgets/pickers.dart';
import 'widgets/primitives.dart';

/// Add or edit a task.
///
/// ⚠ Everything but the title is optional. Most tasks are a line on a
/// checklist with no date and no link, and the sheet must not make that feel
/// like an incomplete form. The quick-add field on the Tasks screen is the
/// fast path; this is where a date or a person gets attached.
class TaskSheet extends StatefulWidget {
  const TaskSheet({
    super.key,
    required this.db,
    this.existing,
    this.presetPerson,
    this.presetProject,
    this.presetDay,
  });
  final AppDatabase db;
  final Task? existing;
  final Person? presetPerson;
  final Engagement? presetProject;

  /// The day the calendar was showing — see MeetingSheet.presetDay.
  final DateTime? presetDay;

  static Future<bool?> show(BuildContext c, AppDatabase db,
          {Task? existing,
          Person? presetPerson,
          Engagement? presetProject,
          DateTime? presetDay}) =>
      showDialog<bool>(
        context: c,
        builder: (_) => TaskSheet(
            db: db,
            existing: existing,
            presetPerson: presetPerson,
            presetProject: presetProject,
            presetDay: presetDay),
      );

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  late final _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  late DateTime? _due = _dayOf(widget.existing?.dueDate ??
      (widget.existing == null ? widget.presetDay : null));
  late bool _done = widget.existing?.doneAt != null;
  Person? _person;
  String? _personId;
  Engagement? _project;
  String? _engagementId;

  bool get _editing => widget.existing != null;

  static DateTime? _dayOf(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _person = widget.presetPerson;
    _personId = widget.presetPerson?.id ?? widget.existing?.personId;
    _project = widget.presetProject;
    _engagementId = widget.presetProject?.id ?? widget.existing?.engagementId;
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    if (_person == null && (_personId ?? '').isNotEmpty) {
      final m = await widget.db.peopleById();
      if (mounted) setState(() => _person = m[_personId]);
    }
    if (_project == null && (_engagementId ?? '').isNotEmpty) {
      final m = await widget.db.engagementsById();
      if (mounted) setState(() => _project = m[_engagementId]);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
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
          engagementId: Value(_engagementId),
        ),
      );
    } else {
      await widget.db.addTask(TasksCompanion.insert(
        title: title,
        notes: Value(notes.isEmpty ? null : notes),
        dueDate: Value(_due),
        personId: Value(_personId),
        engagementId: Value(_engagementId),
        createdAt: Value(DateTime.now()),
      ));
    }

    // ⚠ Reminders are derived from the database; without this a task dated
    // now has no reminder until the next launch.
    await appNotifierReschedule();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _due = _dayOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'Edit task' : 'New task',
                  style: T.screenTitle.copyWith(color: t.textPrimary)),
              const SizedBox(height: 14),
              Field(
                  label: 'What',
                  controller: _title,
                  autofocus: true,
                  hint: 'Send Pak Arnold the quotation'),
              const SizedBox(height: 12),
              Text('DUE',
                  style:
                      T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              // ⚠ Wrap, not Row — fixed-width chips overflow a narrow dialog.
              Wrap(spacing: 6, runSpacing: 6, children: [
                TagChip(
                    label: 'No date',
                    selected: _due == null,
                    onTap: () => setState(() => _due = null)),
                for (final (label, days) in const [
                  ('Today', 0),
                  ('Tomorrow', 1),
                  ('+1 week', 7),
                ])
                  TagChip(
                      label: label,
                      selected: _due == today.add(Duration(days: days)),
                      onTap: () => setState(
                          () => _due = today.add(Duration(days: days)))),
                Btn(_due == null ? 'Pick a day' : fmtDate(_due!),
                    size: BtnSize.sm, onPressed: _pickDay),
              ]),
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
              Field(label: 'Notes', controller: _notes, maxLines: 3),
              if (_editing) ...[
                const SizedBox(height: 12),
                TagChip(
                    label: _done ? 'Done' : 'Mark done',
                    selected: _done,
                    onTap: () => setState(() => _done = !_done)),
              ],
              if (_due != null && !_done) ...[
                const SizedBox(height: 8),
                Text('Reminder fires at 09:00 on ${fmtDate(_due!)}.',
                    style: T.secondary.copyWith(color: t.textMuted)),
              ],
              const SizedBox(height: 18),
              Row(children: [
                if (_editing)
                  DeleteAction(
                    what: 'this task',
                    size: BtnSize.md,
                    onConfirmed: () async {
                      await widget.db.updateTask(widget.existing!.id,
                          TasksCompanion(deletedAt: Value(DateTime.now())));
                      await appNotifierReschedule();
                      if (context.mounted) Navigator.pop(context, true);
                    },
                  ),
                const Spacer(),
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context, false)),
                const SizedBox(width: 8),
                Btn('Save',
                    variant: BtnVariant.primary,
                    onPressed: _title.text.trim().isEmpty ? null : _save),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
