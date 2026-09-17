import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../domain/notifications.dart';
import '../../domain/tasks.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'phone_pickers.dart';
import 'phone_primitives.dart';

/// The full checklist — one push from Today (§6 "Tasks list"). Desktop
/// `TasksScreen` parity in phone grammar: type a line, press Enter, tick it
/// off. No features beyond parity.
///
/// ⚠ The quick-add field is the feature, same as on the Mac. A checklist you
/// have to open a sheet per item is one you stop writing in; every row here
/// started as a line somebody typed at a walking pace.
///
/// ⚠ No pull-to-refresh, no trailing nav action: `watchTasks()` is a live
/// local stream, and a refresh affordance would fake a reload (§3.4). Back is
/// the system gesture only.
class PhoneTasksScreen extends StatefulWidget {
  const PhoneTasksScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhoneTasksScreen> createState() => _PhoneTasksScreenState();
}

class _PhoneTasksScreenState extends State<PhoneTasksScreen> {
  final _quickController = TextEditingController();
  final _quickFocus = FocusNode();
  bool _showDone = false;

  /// Person/project names for the meta line. ⚠ Held, not built inline: a
  /// future built in build() restarts the query on every stream emission and
  /// the names blink. People and projects cannot be created from this screen,
  /// so one load per push is enough.
  late final Future<_LinkNames> _names = _loadNames();

  Future<_LinkNames> _loadNames() async => _LinkNames(
        await widget.db.peopleById(),
        await widget.db.engagementsById(),
      );

  @override
  void dispose() {
    _quickController.dispose();
    _quickFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhoneScaffold(
      title: 'Tasks',
      child: FutureBuilder<_LinkNames>(
        future: _names,
        builder: (context, names) => StreamBuilder<List<Task>>(
          stream: widget.db.watchTasks(),
          builder: (context, snap) {
            final tasks = snap.data ?? const <Task>[];
            final groups = groupTasks(tasks, DateTime.now());
            final links = names.data;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  PD.screenPad, 0, PD.screenPad, PD.sectionGap),
              children: [
                TaskQuickAdd(
                  db: widget.db,
                  controller: _quickController,
                  focusNode: _quickFocus,
                  hint: 'Add a task and press Enter',
                  autofocus: true,
                ),
                const SizedBox(height: PD.groupGap),
                if (tasks.isEmpty)
                  const PhoneEmpty('Nothing to do. Type above and press Enter.')
                else ...[
                  ..._group(groups[TaskGroup.overdue]!, links,
                      label: TaskGroup.overdue.label, danger: true),
                  ..._group(groups[TaskGroup.today]!, links,
                      label: TaskGroup.today.label),
                  ..._group(groups[TaskGroup.upcoming]!, links,
                      label: TaskGroup.upcoming.label),
                  ..._group(groups[TaskGroup.undated]!, links,
                      label: TaskGroup.undated.label),
                  ..._doneGroup(groups[TaskGroup.done]!, links),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Open groups: hidden entirely when empty — never a hole (§3.6). Headers
  /// carry `· N` counts, the desktop group-header grammar (§6).
  List<Widget> _group(List<Task> tasks, _LinkNames? links,
      {required String label, bool danger = false}) {
    if (tasks.isEmpty) return const [];
    final kids = <Widget>[];
    for (final task in tasks) {
      if (kids.isNotEmpty) kids.add(const PhoneDivider());
      kids.add(_TaskTile(db: widget.db, task: task, links: links));
    }
    return [
      _GroupHeader('$label · ${tasks.length}', danger: danger),
      ...kids,
      const SizedBox(height: PD.groupGap),
    ];
  }

  /// The done group is the record, not the list — collapsed by default;
  /// shown open it buries what is still to do (§6).
  List<Widget> _doneGroup(List<Task> tasks, _LinkNames? links) {
    if (tasks.isEmpty) return const [];
    final kids = <Widget>[];
    if (_showDone) {
      for (final task in tasks) {
        if (kids.isNotEmpty) kids.add(const PhoneDivider());
        kids.add(_TaskTile(db: widget.db, task: task, links: links));
      }
    }
    return [
      _GroupHeader(
        '${TaskGroup.done.label} · ${tasks.length}',
        trailing: Text(_showDone ? 'Hide' : 'Show',
            style: PT.secondary.copyWith(
                color: AppTokens.of(context).textSecondary,
                fontWeight: FontWeight.w600)),
        onTap: () => setState(() => _showDone = !_showDone),
      ),
      ...kids,
    ];
  }
}

class _LinkNames {
  const _LinkNames(this.people, this.projects);
  final Map<String, Person> people;
  final Map<String, Engagement> projects;
}

/// A group label row. Overdue is the one group allowed `danger.text` — it is
/// the only group whose mere existence is bad news (§6 layout).
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label,
      {this.trailing, this.onTap, this.danger = false});
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // ⚠ A header carrying a control (DONE's Show/Hide) is a tap target and
    // grows to the 44pt floor; a plain label keeps the 32pt group rhythm.
    final header = Container(
      height: onTap == null ? PD.groupHeader : PD.tapMin,
      alignment: Alignment.bottomLeft,
      child: Row(children: [
        Text(label.toUpperCase(),
            style: PT.micro.copyWith(
                color: danger == true ? t.danger.text : t.textMuted,
                letterSpacing: 0.6)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ]),
    );
    if (onTap == null) return header;
    return PhonePressable(onTap: onTap, child: header);
  }
}

/// The tick box at phone size (§6): 22pt box, radius 4, accent fill when done,
/// **44pt target** — the desktop 16pt box plus padding tops out at 24pt, below
/// the phone floor. Its own widget so the row's tap (edit sheet) and the box's
/// tap (toggle done) stay two separate targets — the desktop `TaskCheck` rule.
///
/// The box fill answers in the beat; the stroke draws after a 60ms rest.
class PhoneTaskCheck extends StatelessWidget {
  const PhoneTaskCheck({super.key, required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: PD.tapMin,
        height: PD.tapMin,
        child: Center(
          child: AnimatedScale(
            // Mockup parity: the box doesn't just fill — it BLOOMS past rest
            // (scale 1.08) on the pop curve as the accent lands.
            scale: done ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: PM.pop,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: PM.pop,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done ? t.accent : t.card,
                border: Border.all(
                    color: done ? t.accent : t.textMuted, width: 1.2),
                borderRadius: BorderRadius.circular(D.radiusTag),
              ),
              child: done ? _CheckStroke(color: t.textInverse) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The drawn checkmark: 60ms beat of nothing, then one stroke traced by path
/// metric over [PM.drawMs] — the mockup's
/// `stroke-dashoffset .24s ease .06s`.
class _CheckStroke extends StatelessWidget {
  const _CheckStroke({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: const Interval(0.2, 1, curve: Curves.ease),
        builder: (context, t, _) => CustomPaint(
          size: const Size(22, 22),
          painter: _CheckPainter(progress: t, color: color),
        ),
      );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.78, size.height * 0.30);
    final metric = path.computeMetrics().single;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// The quick-add row (§6 shared components): 48pt `subtle`-fill borderless
/// field, `Ic.add` prefix, **keeps focus after Enter** — a checklist is
/// written several lines at a time, and bouncing the keyboard is how you stop
/// one from being written.
///
/// ⚠ The two surfaces pass different [dueDate]s, deliberately: Today dates the
/// task TODAY (an undated add would vanish off the deck the instant it was
/// typed — undated ≠ due — which reads as data loss on the surface you typed
/// it on); this list stays undated (desktop parity).
class TaskQuickAdd extends StatefulWidget {
  const TaskQuickAdd({
    super.key,
    required this.db,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.autofocus = false,
    this.dueDate,
    this.onAdded,
  });

  final AppDatabase db;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool autofocus;
  final DateTime? dueDate;
  final VoidCallback? onAdded;

  @override
  State<TaskQuickAdd> createState() => _TaskQuickAddState();
}

class _TaskQuickAddState extends State<TaskQuickAdd> {
  Future<void> _submit() async {
    final title = widget.controller.text.trim();
    if (title.isEmpty) return;
    await widget.db.addTask(TasksCompanion.insert(
      title: title,
      dueDate: Value(widget.dueDate),
      createdAt: Value(DateTime.now()),
    ));
    widget.controller.clear();
    widget.focusNode.requestFocus();
    // Today re-pulls its deck off this; this list just watches its stream.
    widget.onAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      height: PD.control,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.subtle,
        borderRadius: BorderRadius.circular(D.radiusControl),
      ),
      child: Row(children: [
        AppIcon(Ic.add, size: 18, color: t.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: PT.body.copyWith(color: t.textPrimary),
            cursorColor: t.accent,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: widget.hint,
              hintStyle: PT.body.copyWith(color: t.textMuted),
            ),
          ),
        ),
      ]),
    );
  }
}

/// One row: tick box, title, meta. Tap the row to edit — the box and the body
/// are separate targets.
///
/// ⚠ The 200ms exit (§3.6) is real, not implied by the stream: the write is
/// held back for the collapse, so the row is still in the data while it fades
/// and melts — the stream then removes a row that is already invisible. No
/// cut animation, no ghost frame.
class _TaskTile extends StatefulWidget {
  const _TaskTile({required this.db, required this.task, this.links});
  final AppDatabase db;
  final Task task;
  final _LinkNames? links;

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _checked = false;
  bool _leaving = false;
  bool _busy = false;

  bool get _done => widget.task.doneAt != null;

  /// Mockup sequencing: the check beat comes FIRST — box springs full, the
  /// stroke draws (~300ms), the title strikes — and only at ~340ms does the
  /// row start to collapse. The write lands during the fade, so a done task
  /// never jumps to the DONE group while it is still visibly sitting in its
  /// old one. Reopening has no beat; it writes straight away.
  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    final done = !_done;
    // Light on check AND swipe fire — they are the same verb (§3.4).
    PhoneHaptic.light();
    if (done) {
      setState(() => _checked = true);
      await Future<void>.delayed(const Duration(milliseconds: 340));
      if (mounted) setState(() => _leaving = true);
      await Future<void>.delayed(const Duration(milliseconds: PM.clearMs + 20));
    }
    await widget.db.setTaskDone(widget.task.id, done);
    // ⚠ A done task must stop its 09:00 reminder — reminders are derived
    // from the database, so every done change reschedules.
    await appNotifierReschedule();
    _busy = false;
  }

  Future<void> _openEdit() async {
    await PhoneSheet.show<void>(
      context,
      (context) => _TaskEditSheet(db: widget.db, task: widget.task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final task = widget.task;
    final done = _done;
    // The checked flag carries the visual through the 340ms pre-write hold,
    // when doneAt has not landed yet.
    final checked = _checked || done;
    final now = DateTime.now();
    final group = groupOf(task, now);

    // Meta: dueLabel (or done stamp) · person · project. Overdue meta is the
    // only danger-toned secondary text on this screen — it waited longest.
    final parts = <String>[
      if (done)
        'done ${fmtDate(task.doneAt!)}'
      else if (task.dueDate != null)
        dueLabel(task.dueDate!, now),
      if (widget.links != null && task.personId != null)
        widget.links!.people[task.personId]?.name ?? '',
      if (widget.links != null && task.engagementId != null)
        widget.links!.projects[task.engagementId]?.name ?? '',
    ].where((p) => p.isNotEmpty).toList();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: _leaving ? 0.0 : 1.0),
      duration: const Duration(milliseconds: PM.clearMs),
      curve: Curves.ease,
      builder: (context, p, child) => Opacity(
        opacity: p,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: p,
          child: child,
        ),
      ),
      child: Dismissible(
        key: ValueKey('task-${task.id}'),
        direction: DismissDirection.endToStart,
        // ⚠ One trailing action: complete — and re-open on a done row. It
        // shares the check's exit so both triggers read identically; the
        // dismissal itself is the collapse, not a list splice.
        background: PhoneSwipeBackground(
          label: done ? 'Reopen' : 'Done',
          icon: Ic.confirm,
          color: t.accentWash,
        ),
        confirmDismiss: (_) async {
          await _toggle();
          return false;
        },
        child: PhonePressable(
          onTap: _openEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              PhoneTaskCheck(done: checked, onTap: _toggle),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PT.body.copyWith(
                          color: checked ? t.textMuted : t.textPrimary,
                          fontWeight: FontWeight.w600,
                          decoration:
                              checked ? TextDecoration.lineThrough : null),
                    ),
                    if (parts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        parts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PT.secondary.copyWith(
                            color: !done && group == TaskGroup.overdue
                                ? t.danger.text
                                : t.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The task edit sheet (§6): desktop `TaskSheet` re-expressed at the large
/// detent. DUE chips + house date sheet (the Material `showDatePicker` died),
/// links, notes, a done chip, and Delete behind the house confirm — soft
/// delete, never a hard one.
class _TaskEditSheet extends StatefulWidget {
  const _TaskEditSheet({required this.db, required this.task});
  final AppDatabase db;
  final Task task;

  @override
  State<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<_TaskEditSheet> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _notes = TextEditingController(text: widget.task.notes ?? '');
  late DateTime? _due = _dayOf(widget.task.dueDate);
  late bool _done = widget.task.doneAt != null;
  Person? _person;
  Engagement? _project;

  static DateTime? _dayOf(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _loadLinks();
  }

  /// Resolve link names — the task row carries ids, not names.
  Future<void> _loadLinks() async {
    if (widget.task.personId != null) {
      final m = await widget.db.peopleById();
      if (mounted) setState(() => _person = m[widget.task.personId]);
    }
    if (widget.task.engagementId != null) {
      final m = await widget.db.engagementsById();
      if (mounted) setState(() => _project = m[widget.task.engagementId]);
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
    await widget.db.updateTask(
      widget.task.id,
      TasksCompanion(
        title: Value(title),
        notes: Value(notes.isEmpty ? null : notes),
        dueDate: Value(_due),
        // ⚠ Keep the original stamp when it was already done. Re-saving a
        // task ticked off last week to fix a typo must not claim it was
        // done today.
        doneAt: Value(_done ? (widget.task.doneAt ?? DateTime.now()) : null),
        personId: Value(_person?.id),
        engagementId: Value(_project?.id),
      ),
    );
    // A dated write — reminders are derived, so reschedule.
    await appNotifierReschedule();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final task = widget.task;
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete ${task.title}?',
      body: 'It disappears from every list here. The row is kept so your '
          'other device learns it is gone.',
    );
    if (!ok) return;
    await widget.db.updateTask(
      widget.task.id,
      TasksCompanion(deletedAt: Value(DateTime.now())),
    );
    await appNotifierReschedule();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await PhoneDateSheet.show(
      context,
      initial: _due ?? today,
    );
    if (picked != null) setState(() => _due = _dayOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final presets = <DateTime?>[
      null,
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 7)),
    ];
    final isPreset = presets.contains(_due);

    return PhoneSheet(
      title: 'Edit task',
      expand: true,
      actions: Row(children: [
        Expanded(
          child: PhoneBtn('Delete',
              variant: PhoneBtnVariant.danger, onPressed: _delete),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PhoneBtn(
            'Save',
            variant: PhoneBtnVariant.primary,
            onPressed: _title.text.trim().isEmpty ? null : _save,
          ),
        ),
      ]),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhoneField(
              label: 'What',
              controller: _title,
              hint: 'Send Pak Arnold the quotation',
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: PD.groupGap),
            Text('DUE',
                style: PT.micro
                    .copyWith(color: t.textMuted, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            // ⚠ Wrap, not Row — same trap as the desktop sheet: fixed-width
            // chips overflow a narrow pane.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, label) in const [
                  'No date',
                  'Today',
                  'Tomorrow',
                  '+1 week',
                ].indexed)
                  PhoneChip(
                    label: label,
                    selected: _due == presets[i],
                    onTap: () => setState(() => _due = presets[i]),
                  ),
                PhoneChip(
                  label: isPreset ? 'Pick a day' : fmtDate(_due!),
                  selected: !isPreset,
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
                if (p != null) setState(() => _person = p);
              },
              onClear: () => setState(() => _person = null),
            ),
            const SizedBox(height: PD.groupGap),
            PhoneLinkRow(
              label: 'Project',
              value: _project?.name,
              onTap: () async {
                final e = await pickProject(context, widget.db);
                if (e != null) setState(() => _project = e);
              },
              onClear: () => setState(() => _project = null),
            ),
            const SizedBox(height: PD.groupGap),
            PhoneField(label: 'Notes', controller: _notes),
            const SizedBox(height: PD.groupGap),
            PhoneChip(
              label: _done ? 'Done' : 'Mark done',
              selected: _done,
              onTap: () => setState(() => _done = !_done),
            ),
            if (_due != null && !_done) ...[
              const SizedBox(height: 8),
              Text(
                'Reminder fires at 09:00 on ${fmtDate(_due!)}.',
                style: PT.secondary.copyWith(color: t.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
