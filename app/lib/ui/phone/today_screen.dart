import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../domain/notifications.dart';
import '../../domain/tasks.dart';
import '../../domain/today.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'money_screen.dart';
import 'calendar_screen.dart';
import 'occasion_run_screen.dart';
import 'person_detail_screen.dart';
import 'phone_primitives.dart';
import 'phone_shell.dart';
import 'tasks_list_screen.dart';

/// B1 — what is due. ⚠ This screen is strictly better on a phone than on the
/// Mac: the notification, the contact list and WhatsApp are finally on the
/// same device, so the occasion loop is tap-notification → tap-send.
///
/// ⚠ Its empty state is the NORMAL state. Most days nothing is due, and the
/// screen is quiet because nothing needed doing — not because it failed. Do
/// not fill it with streaks, suggestions or "people you haven't contacted".
/// Engagement is not a goal for a tool with one user.
///
/// v2 (§6): section order frozen (Calendar → Meetings → Tasks → Occasions →
/// Pings → Money), hide-when-empty, quick-add on the Tasks section, checks
/// and ping clears leave the deck with the 200ms fade + collapse, money taps
/// into the settle sheet, pings push the person behind them, and loading
/// never blanks — last-known structure paints on the first frame (§3.4).
class PhoneTodayScreen extends StatefulWidget {
  const PhoneTodayScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhoneTodayScreen> createState() => _PhoneTodayScreenState();
}

class _PhoneTodayScreenState extends State<PhoneTodayScreen> {
  /// ⚠ Last-known deck, held across loads. A FutureBuilder would blank the
  /// screen between assign and resolve — including on every pull-to-refresh —
  /// and "loading never blanks" is a rule, not a preference (§3.4).
  TodayData? _data;

  /// Rows mid-exit. ⚠ The 200ms collapse is real: the row keeps rendering
  /// (faded, melting) from these snapshots after the write lands and the
  /// deck stops listing it, until the sweep retires them. Without them the
  /// stream refresh would cut the animation mid-beat.
  final _leavingTasks = <String, Task>{};
  final _leavingPings = <String, Person>{};
  final _leavingMoney = <String, MoneyRow>{};

  /// Checked-but-not-yet-collapsing: the 340ms check beat (box spring +
  /// stroke draw) runs BEFORE the row starts to leave. Excluded from the
  /// sweep, which only retires collapsing rows.
  final _checkedTasks = <String>{};

  final _quickController = TextEditingController();
  final _quickFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _quickController.dispose();
    _quickFocus.dispose();
    super.dispose();
  }

  /// The one load path. Pull-to-refresh awaits it; every write fires it.
  Future<void> _load() async {
    final d = await loadToday(widget.db);
    if (!mounted) return;
    setState(() => _data = d);
    // The Today badge is what Today itself sees — written on EVERY load,
    // not only on visible changes (§3.1: the only badge in the shell).
    phoneTodayCount.value = d.count;
    _sweepSoon();
  }

  /// Retire exit rows the deck no longer lists. Rows still present (write in
  /// flight) stay until a later sweep.
  void _sweepSoon() {
    Future<void>.delayed(const Duration(milliseconds: PM.clearMs + 80), () {
      if (!mounted) return;
      final d = _data;
      if (d == null) return;
      final taskIds = {for (final t in d.tasks) t.id};
      final pingIds = {for (final p in d.pings) p.id};
      final settleIds = {for (final m in d.settle) m.id};
      setState(() {
        _leavingTasks.removeWhere((id, _) => !taskIds.contains(id));
        _leavingPings.removeWhere((id, _) => !pingIds.contains(id));
        _leavingMoney.removeWhere((id, _) => !settleIds.contains(id));
      });
    });
  }

  /// Fade + collapse to nothing over [PM.clearMs] (§3.6: the row fades and
  /// the gap closes). heightFactor needs no measuring — that is why this is
  /// Align, not an AnimatedContainer guessing at heights.
  Widget _collapse(bool leaving, Widget child) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: leaving ? 0.0 : 1.0),
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
        child: child,
      );

  Future<void> _openTasks() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PhoneTasksScreen(db: widget.db),
    ));
    if (mounted) _load();
  }

  /// ⚠ The same sheet the Calendar tab opens. Today used to render meetings
  /// as the one deliberately inert card, on the reasoning that "no detail
  /// surface exists in either shell" — true when that comment was written,
  /// stale since PhoneMeetingSheet landed. A card that carries the only copy
  /// of a time and place you may need to correct, and refuses to open, is the
  /// dead end the comment was trying to avoid.
  Future<void> _openMeeting(Meeting m) async {
    await PhoneSheet.show<bool>(
      context,
      (_) => PhoneMeetingSheet(db: widget.db, existing: m),
    );
    // Reload unconditionally: the sheet edits, deletes AND exports, and only
    // the first two pop with a result.
    if (mounted) _load();
  }

  Future<void> _openRun(Occasion o) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OccasionRunScreen(db: widget.db, occasion: o),
    ));
    if (mounted) _load();
  }

  Future<void> _openPerson(Person p) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PersonDetailScreen(db: widget.db, personId: p.id),
    ));
    if (mounted) _load();
  }

  /// ⚠ The inline `Confirm` is gone (§6 Money): "Confirm alone is not enough
  /// — the amount often differs." The settle sheet owns amount/date/decision.
  Future<void> _settle(MoneyRow m) async {
    final before = _data;
    await showSettleSheet(context, widget.db, m);
    final d = await loadToday(widget.db);
    if (!mounted) return;
    setState(() {
      _data = d;
      // Rows that LEFT the deck get the standard exit — Confirm actual,
      // Write off and Keep-expected-with-a-later-date all depart alike;
      // Keep expected that stayed put does not move.
      if (before != null) {
        final ids = {for (final r in d.settle) r.id};
        for (final r in before.settle) {
          if (!ids.contains(r.id)) _leavingMoney[r.id] = r;
        }
      }
    });
    phoneTodayCount.value = d.count;
    _sweepSoon();
  }

  Future<void> _snoozePing(Person p) async {
    if (_leavingPings.containsKey(p.id)) return;
    // Snoozed three months out — off the deck today, so it exits with the
    // same grammar as a dismissal (§3.6).
    setState(() => _leavingPings[p.id] = p);
    final n = DateTime.now();
    await widget.db.setPing(p.id, DateTime(n.year, n.month + 3, n.day));
    if (mounted) _load();
  }

  Future<void> _dismissPing(Person p) async {
    // ⚠ Single tap, no dialog — a ping is a prompt, not a record; the touch
    // log is the record (§6).
    if (_leavingPings.containsKey(p.id)) return;
    setState(() => _leavingPings[p.id] = p);
    await widget.db.setPing(p.id, null);
    if (mounted) _load();
  }

  /// A dated write landed (quick-add) — reminders are derived from the
  /// database, so the 09:00 notification must be rebuilt now.
  Future<void> _onQuickAdd() async {
    await appNotifierReschedule();
    if (mounted) _load();
  }

  /// Mockup sequencing: the check beat comes FIRST — box springs full, the
  /// stroke draws, the title strikes — and only at ~340ms does the row join
  /// the leaving deck and start to collapse. The write lands during the
  /// fade, so the deck refresh removes an already-invisible row.
  Future<void> _checkTask(Task task) async {
    if (_checkedTasks.contains(task.id) || _leavingTasks.containsKey(task.id)) {
      return;
    }
    // Light on check fire — the one haptic a check earns (§3.4).
    PhoneHaptic.light();
    setState(() => _checkedTasks.add(task.id));
    await Future<void>.delayed(const Duration(milliseconds: 340));
    if (!mounted) return;
    setState(() {
      _checkedTasks.remove(task.id);
      _leavingTasks[task.id] = task;
    });
    // ⚠ Hold the write for the collapse, so the row is still in the data
    // while it fades — the refresh then removes an already-invisible row.
    await Future<void>.delayed(const Duration(milliseconds: PM.clearMs + 20));
    await widget.db.setTaskDone(task.id, true);
    // ⚠ A done task must stop its 09:00 reminder.
    await appNotifierReschedule();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final d = _data;

    return PhoneScaffold(
      title: 'Today',
      child: RefreshIndicator(
        // The one refresh affordance (§3.4): pulses the sync, nothing else.
        color: t.accent,
        backgroundColor: t.card,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              PD.screenPad, 0, PD.screenPad, PD.sectionGap),
          children: [
            // ⚠ PERMANENT RESIDENT, first, not tappable (§6): its action is
            // reading it and going to Calendar. An empty or short calendar is
            // the app's silent failure — nothing fires, and it looks exactly
            // like a quiet day.
            if (d?.runwayWarning != null)
              PhoneSection('Calendar', [
                PhoneCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d!.runwayWarning!,
                          style: PT.body.copyWith(color: t.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                          'Nothing schedules past this date. It will look '
                          'exactly like a quiet day.',
                          style: PT.secondary
                              .copyWith(color: t.textSecondary)),
                    ],
                  ),
                ),
              ]),

            if (d != null && d.meetings.isNotEmpty)
              PhoneSection('Meetings · ${d.meetings.length}', [
                for (final m in d.meetings)
                  PhoneCard(
                    onTap: () => _openMeeting(m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          PhoneTag(
                              tone: t.success,
                              label: _sameDay(m.startsAt)
                                  ? fmtClock(m.startsAt)
                                  : 'tmr ${fmtClock(m.startsAt)}'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(m.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PT.body.copyWith(
                                    color: t.textPrimary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        if ((m.location ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(m.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PT.secondary
                                  .copyWith(color: t.textSecondary)),
                        ],
                      ],
                    ),
                  ),
              ]),

            _tasksSection(t, d),

            if (d != null && d.occasions.isNotEmpty)
              PhoneSection('Occasions · ${d.occasions.length}', [
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
                                '${taggedLabelFor(d.taggedCounts[o.tag] ?? 0)}'
                                ' · ${fmtDate(o.date)}',
                                style: PT.secondary
                                    .copyWith(color: t.textSecondary)),
                          ],
                        ),
                      ),
                      AppIcon(Ic.chevronRight, size: 20, color: t.textMuted),
                    ]),
                  ),
              ]),

            // ⚠ Section-emptied grammar: the header goes WITH its last card
            // — when the deck empties, the whole section fades and collapses
            // with the exiting rows, never a hole (§3.6).
            if (d != null && _pingDeck(d).isNotEmpty)
              _collapse(
                d.pings.isEmpty,
                PhoneSection('Pings · ${d.pings.length}', [
                  for (final p in _pingDeck(d))
                    _collapse(
                      _leavingPings.containsKey(p.id),
                      PhoneCard(
                        onTap: () => _openPerson(p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              PhoneTag(
                                  tone: t.attention,
                                  label: fmtIn(p.pingDate!)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    [p.name, p.company]
                                        .where((e) =>
                                            e != null && e.isNotEmpty)
                                        .join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PT.body.copyWith(
                                        color: t.textPrimary,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            if (p.pingNote != null &&
                                p.pingNote!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('"${p.pingNote}"',
                                  style: PT.secondary.copyWith(
                                      color: t.textSecondary,
                                      fontStyle: FontStyle.italic)),
                            ],
                            const SizedBox(height: 10),
                            // ⚠ Permanently visible, never hover-revealed.
                            // The Mac hides these until the pointer arrives;
                            // ported literally that would delete them here.
                            Row(children: [
                              PhoneBtn('+3 mo',
                                  onPressed: () => _snoozePing(p)),
                              const SizedBox(width: 8),
                              PhoneBtn('Dismiss',
                                  variant: PhoneBtnVariant.ghost,
                                  onPressed: () => _dismissPing(p)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),

            if (d != null && _moneyDeck(d).isNotEmpty)
              _collapse(
                d.settle.isEmpty,
                PhoneSection('Money · ${d.settle.length}', [
                  for (final m in _moneyDeck(d))
                    _collapse(
                      _leavingMoney.containsKey(m.id),
                      PhoneCard(
                        onTap: () => _settle(m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              PhoneTag(
                                  tone: t.attention, label: 'Expected'),
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
                            // ⚠ Money is mono, tabular, and never converted
                            // (§8.4) — the amount is the one mono run of
                            // text on this screen.
                            Text.rich(
                              TextSpan(
                                style: PT.secondary
                                    .copyWith(color: t.textSecondary),
                                children: [
                                  TextSpan(
                                      text:
                                          '${m.direction == 'in' ? 'in' : 'out'} · '),
                                  TextSpan(
                                      text: fmtMoney(
                                          m.amountMinor, m.currency),
                                      style: PT.mono.copyWith(
                                          color: t.textPrimary,
                                          fontFeatures:
                                              kTabular.fontFeatures)),
                                  TextSpan(
                                      text: ' · due ${fmtDate(m.date)}'),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),

            // ⚠ THE NORMAL STATE. The line shows only once every clearable
            // section is empty AND no runway warning sits above — on an
            // only-a-warning day the warning IS the content (§6 states).
            if (_allClear(d)) ...[
              const SizedBox(height: PD.sectionGap),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: PM.clearMs),
                curve: Curves.ease,
                builder: (context, p, child) =>
                    Opacity(opacity: p, child: child),
                child: const PhoneEmpty('No one needs you today.'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _allClear(TodayData? d) {
    if (d == null) return false;
    if (d.runwayWarning != null) return false;
    if (_checkedTasks.isNotEmpty ||
        _leavingTasks.isNotEmpty ||
        _leavingPings.isNotEmpty ||
        _leavingMoney.isNotEmpty) {
      return false;
    }
    return d.meetings.isEmpty &&
        d.tasks.isEmpty &&
        d.occasions.isEmpty &&
        d.pings.isEmpty &&
        d.settle.isEmpty;
  }

  /// Tasks: the 44pt header row pushes the full list; the quick-add row is
  /// input chrome, not a queue resident (§6 states). Present even while the
  /// deck is still loading — structure paints on the first frame (§3.4).
  Widget _tasksSection(AppTokens t, TodayData? d) {
    final deck = d == null ? const <Task>[] : _taskDeck(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhonePressable(
          onTap: _openTasks,
          child: SizedBox(
            height: PD.tapMin,
            child: Row(children: [
              Expanded(
                child: Text('Tasks · ${deck.length}',
                    style: PT.micro
                        .copyWith(color: t.textMuted, letterSpacing: 0.6)),
              ),
              AppIcon(Ic.chevronRight, size: 20, color: t.textMuted),
            ]),
          ),
        ),
        const SizedBox(height: 2),
        // ⚠ Deliberate divergence from the Tasks list: THIS field dates the
        // task today — an undated add would vanish the instant it was typed,
        // which reads as data loss on the surface you typed it on (§6).
        TaskQuickAdd(
          db: widget.db,
          controller: _quickController,
          focusNode: _quickFocus,
          hint: 'Add a task',
          dueDate: _today,
          onAdded: _onQuickAdd,
        ),
        // Row body is not tappable: the deck clears, the Tasks list manages.
        for (final task in deck)
          _collapse(
            _leavingTasks.containsKey(task.id),
            PhoneCard(
              child: Row(children: [
                PhoneTaskCheck(
                    done: _checkedTasks.contains(task.id),
                    onTap: () => _checkTask(task)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // The mockup strikes the title the moment the check
                      // lands — muted with a line-through, not a fade
                      // straight to nothing.
                      style: PT.body.copyWith(
                          color: _checkedTasks.contains(task.id)
                              ? t.textMuted
                              : t.textPrimary,
                          fontWeight: FontWeight.w600,
                          decoration: _checkedTasks.contains(task.id)
                              ? TextDecoration.lineThrough
                              : null)),
                ),
                const SizedBox(width: 8),
                PhoneTag(
                    tone: groupOf(task, DateTime.now()) == TaskGroup.overdue
                        ? t.danger
                        : t.attention,
                    label: dueLabel(task.dueDate!, DateTime.now())),
              ]),
            ),
          ),
        const SizedBox(height: PD.sectionGap),
      ],
    );
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Open rows plus any still mid-exit (rendered from their snapshots).
  List<Task> _taskDeck(TodayData d) {
    final ids = {for (final t in d.tasks) t.id};
    return [
      ...d.tasks,
      ..._leavingTasks.entries
          .where((e) => !ids.contains(e.key))
          .map((e) => e.value),
    ];
  }

  List<Person> _pingDeck(TodayData d) {
    final ids = {for (final p in d.pings) p.id};
    return [
      ...d.pings,
      ..._leavingPings.entries
          .where((e) => !ids.contains(e.key))
          .map((e) => e.value),
    ];
  }

  List<MoneyRow> _moneyDeck(TodayData d) {
    final ids = {for (final m in d.settle) m.id};
    return [
      ...d.settle,
      ..._leavingMoney.entries
          .where((e) => !ids.contains(e.key))
          .map((e) => e.value),
    ];
  }
}

/// Whether a timestamp falls on today's date — the distinction Today is about.
bool _sameDay(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}
