import '../data/database.dart';
import 'money_fmt.dart';

/// Where a task sits. Shared domain logic, not layout — Today, the Tasks
/// screen and the phone must agree on what "overdue" means.
enum TaskGroup {
  overdue('Overdue'),
  today('Today'),
  upcoming('Upcoming'),
  undated('No date'),
  done('Done');

  const TaskGroup(this.label);
  final String label;
}

/// ⚠ Compared as calendar DAYS in UTC, not as durations. Local midnights across
/// a DST change are 23 or 25 hours apart, and `inDays` on 23 hours is 0 — the
/// same drift that makes Today's occasion window wobble between 14 and 15.
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

TaskGroup groupOf(Task t, DateTime now) {
  if (t.doneAt != null) return TaskGroup.done;
  final due = t.dueDate;
  if (due == null) return TaskGroup.undated;
  final days = _daysBetween(now, due);
  if (days < 0) return TaskGroup.overdue;
  return days == 0 ? TaskGroup.today : TaskGroup.upcoming;
}

/// Every group present, in display order, each sorted the way it is read.
Map<TaskGroup, List<Task>> groupTasks(Iterable<Task> tasks, DateTime now) {
  final out = {for (final g in TaskGroup.values) g: <Task>[]};
  for (final t in tasks) {
    out[groupOf(t, now)]!.add(t);
  }
  int byCreated(Task a, Task b) => a.createdAt.compareTo(b.createdAt);
  int byDue(Task a, Task b) {
    final d = a.dueDate!.compareTo(b.dueDate!);
    return d != 0 ? d : byCreated(a, b);
  }

  out[TaskGroup.overdue]!.sort(byDue);
  out[TaskGroup.today]!.sort(byCreated);
  out[TaskGroup.upcoming]!.sort(byDue);
  // ⚠ Written order. An undated list is a checklist, and a checklist reads
  // top to bottom in the order it was written down.
  out[TaskGroup.undated]!.sort(byCreated);
  // Most recently ticked first — the one you just did is the one you look for.
  out[TaskGroup.done]!.sort((a, b) => b.doneAt!.compareTo(a.doneAt!));
  return out;
}

/// "3d overdue", "yesterday", "today", "tomorrow", else the date.
String dueLabel(DateTime due, DateTime now) {
  final days = _daysBetween(now, due);
  if (days < -1) return '${-days}d overdue';
  if (days == -1) return 'yesterday';
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  return fmtDate(due);
}
