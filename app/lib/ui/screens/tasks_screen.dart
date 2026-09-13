import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../domain/notifications.dart';
import '../../domain/tasks.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
import '../task_sheet.dart';
import '../widgets/app_icon.dart';
import '../widgets/primitives.dart';

/// The checklist. Type a line, press Enter, tick it off.
///
/// ⚠ The quick-add field is the feature. A to-do list that needs a dialog per
/// item is one you stop writing in by the third item, so the fast path takes a
/// title and nothing else; dates and links are attached afterwards, by
/// clicking the row, only when they matter.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _quick = TextEditingController();
  final _quickFocus = FocusNode();
  bool _showDone = false;

  // ⚠ Held in state, not built inline. Three nested StreamBuilders each given
  // a fresh stream on every rebuild resubscribe every time, and the inner two
  // flash empty — names blink out of the meta line on each tick.
  late final _tasks = widget.db.watchTasks();
  late final _people = widget.db.watchPeople();
  late final _projects = widget.db.watchEngagements();

  @override
  void dispose() {
    _quick.dispose();
    _quickFocus.dispose();
    super.dispose();
  }

  Future<void> _quickAdd() async {
    final v = _quick.text.trim();
    if (v.isEmpty) return;
    _quick.clear();
    // Keep the cursor here: a checklist is written several lines at a time.
    _quickFocus.requestFocus();
    // No date, so nothing to schedule — no reschedule needed.
    await widget.db.addTask(
        TasksCompanion.insert(title: v, createdAt: Value(DateTime.now())));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return ScreenBody(
      title: 'Tasks',
      trailing: Btn('New task',
          variant: BtnVariant.primary,
          onPressed: () => TaskSheet.show(context, widget.db)),
      child: StreamBuilder<List<Task>>(
        stream: _tasks,
        builder: (context, snap) => StreamBuilder<List<Person>>(
          stream: _people,
          builder: (context, peopleSnap) => StreamBuilder<List<Engagement>>(
            stream: _projects,
            builder: (context, projectSnap) {
              final now = DateTime.now();
              final people = {
                for (final p in peopleSnap.data ?? const <Person>[]) p.id: p
              };
              final projects = {
                for (final e in projectSnap.data ?? const <Engagement>[])
                  e.id: e
              };
              final all = snap.data ?? const <Task>[];
              final groups = groupTasks(all, now);
              final done = groups[TaskGroup.done]!;

              String meta(Task task) => [
                    if (task.doneAt != null)
                      'done ${fmtDate(task.doneAt!)}'
                    else if (task.dueDate != null)
                      dueLabel(task.dueDate!, now),
                    ?people[task.personId]?.name,
                    ?projects[task.engagementId]?.name,
                  ].join(' · ');

              return ListView(children: [
                _QuickAdd(
                    controller: _quick,
                    focusNode: _quickFocus,
                    onSubmit: _quickAdd),
                const SizedBox(height: 6),
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('Nothing to do. Type above and press Enter.',
                        style: T.body.copyWith(color: t.textMuted)),
                  ),
                for (final g in const [
                  TaskGroup.overdue,
                  TaskGroup.today,
                  TaskGroup.upcoming,
                  TaskGroup.undated,
                ])
                  if (groups[g]!.isNotEmpty) ...[
                    _GroupHeader(
                        '${g.label} · ${groups[g]!.length}'.toUpperCase(),
                        color: g == TaskGroup.overdue
                            ? t.danger.text
                            : t.textMuted),
                    for (final task in groups[g]!)
                      TaskRow(
                          key: ValueKey(task.id),
                          task: task,
                          db: widget.db,
                          meta: meta(task),
                          overdue: g == TaskGroup.overdue),
                  ],
                if (done.isNotEmpty) ...[
                  Row(children: [
                    Expanded(
                        child: _GroupHeader('DONE · ${done.length}',
                            color: t.textMuted)),
                    Btn(_showDone ? 'Hide' : 'Show',
                        size: BtnSize.sm,
                        variant: BtnVariant.ghost,
                        onPressed: () =>
                            setState(() => _showDone = !_showDone)),
                  ]),
                  // ⚠ Collapsed by default. Done items are the record, not
                  // the list — shown open they bury what is still to do.
                  if (_showDone)
                    for (final task in done)
                      TaskRow(
                          key: ValueKey(task.id),
                          task: task,
                          db: widget.db,
                          meta: meta(task)),
                ],
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: D.groupHeader,
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.only(top: 8),
        child: Text(label,
            style: T.micro.copyWith(color: color, letterSpacing: 0.5)),
      );
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd(
      {required this.controller,
      required this.focusNode,
      required this.onSubmit});
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SizedBox(
      height: D.control,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        onSubmitted: (_) => onSubmit(),
        style: T.body.copyWith(color: t.textPrimary),
        cursorColor: t.accent,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: t.subtle,
          hintText: 'Add a task and press Enter',
          hintStyle: T.body.copyWith(color: t.textMuted),
          prefixIcon: Icon(Ic.add.glyph, size: 14, color: t.textMuted),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 28, minHeight: 0),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(D.radiusControl),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// The tick box. Its own widget so the row's tap (open the sheet) and the
/// box's tap (toggle done) stay two separate targets.
class TaskCheck extends StatelessWidget {
  const TaskCheck({super.key, required this.done, required this.onTap});
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: done ? t.accent : t.card,
              border: Border.all(
                  color: done ? t.accent : t.textMuted, width: 1.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: done
                ? Icon(Ic.confirm.glyph, size: 12, color: t.textInverse)
                : null,
          ),
        ),
      ),
    );
  }
}

/// One task: tick box, title, and a meta line. Click the row to edit.
class TaskRow extends StatefulWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.db,
    this.meta = '',
    this.overdue = false,
  });
  final Task task;
  final AppDatabase db;
  final String meta;
  final bool overdue;

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final task = widget.task;
    final done = task.doneAt != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => TaskSheet.show(context, widget.db, existing: task),
        child: Container(
          constraints: const BoxConstraints(minHeight: D.listRowTwoLine),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: _hover ? t.subtle : Colors.transparent,
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          child: Row(children: [
            TaskCheck(
              done: done,
              onTap: () async {
                await widget.db.setTaskDone(task.id, !done);
                // ⚠ A done task must stop its 09:00 reminder.
                await appNotifierReschedule();
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(
                          color: done ? t.textMuted : t.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w500)),
                  if (widget.meta.isNotEmpty)
                    Text(widget.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.secondary.copyWith(
                            color: widget.overdue
                                ? t.danger.text
                                : t.textSecondary)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tasks attached to one person or one project, with an Add that presets the
/// link. ⚠ Without this the link is write-only, the same reason
/// people_screen's _LinkedProjects exists.
class LinkedTasks extends StatelessWidget {
  const LinkedTasks({
    super.key,
    required this.db,
    required this.stream,
    this.presetPerson,
    this.presetProject,
  });
  final AppDatabase db;
  final Stream<List<Task>> stream;
  final Person? presetPerson;
  final Engagement? presetProject;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<Task>>(
      stream: stream,
      builder: (context, snap) {
        final now = DateTime.now();
        final groups = groupTasks(snap.data ?? const <Task>[], now);
        final done = groups.remove(TaskGroup.done)!;
        final overdue = groups[TaskGroup.overdue]!.toSet();
        final open = groups.values.expand((l) => l).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('TASKS',
                  style:
                      T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const Spacer(),
              Btn('Add',
                  size: BtnSize.sm,
                  variant: BtnVariant.ghost,
                  onPressed: () => TaskSheet.show(context, db,
                      presetPerson: presetPerson,
                      presetProject: presetProject)),
            ]),
            const SizedBox(height: 4),
            if (open.isEmpty)
              Text('Nothing open.', style: T.body.copyWith(color: t.textMuted))
            else
              for (final task in open)
                TaskRow(
                    key: ValueKey(task.id),
                    task: task,
                    db: db,
                    meta: task.dueDate == null
                        ? ''
                        : dueLabel(task.dueDate!, now),
                    overdue: overdue.contains(task)),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${done.length} done',
                  style: T.secondary.copyWith(color: t.textMuted)),
            ],
          ],
        );
      },
    );
  }
}
