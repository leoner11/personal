import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/database.dart';
import '../../domain/channel.dart';
import '../../domain/money_fmt.dart';
import '../../domain/recency.dart';
import '../../domain/occasions.dart';
import '../../theme/tokens.dart';
import '../add_person_sheet.dart';
import '../shell.dart';
import 'projects_screen.dart';
import '../widgets/primitives.dart';

/// Grouped by last touch. Detail is header + tags + ping + timeline —
/// the one place this app earns its keep over a notes file.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String? _selectedId;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Map<String, DateTime> _lastTouch = {};

  @override
  void initState() {
    super.initState();
    _refreshTouches();
    _search.addListener(() => setState(() {}));
  }

  Future<void> _refreshTouches() async {
    final m = await widget.db.lastTouchByPerson();
    if (mounted) setState(() => _lastTouch = m);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () async {
          await AddPersonSheet.show(context, widget.db);
          _refreshTouches();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
      },
      child: StreamBuilder<List<Person>>(
        stream: widget.db.watchPeople(),
        builder: (context, snap) {
          final all = snap.data ?? const <Person>[];
          final q = _search.text.trim().toLowerCase();
          final rows = q.isEmpty
              ? all
              : all
                  .where((p) =>
                      p.name.toLowerCase().contains(q) ||
                      (p.company ?? '').toLowerCase().contains(q))
                  .toList();

          final sel = rows.any((p) => p.id == _selectedId)
              ? rows.firstWhere((p) => p.id == _selectedId)
              : null;

          return Row(children: [
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: t.card,
                border: Border(right: BorderSide(color: t.line)),
              ),
              child: Column(children: [
                const SizedBox(height: 38),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: SizedBox(
                    height: D.control,
                    child: TextField(
                      controller: _search,
                      focusNode: _searchFocus,
                      style: T.body.copyWith(color: t.textPrimary),
                      cursorColor: t.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: t.subtle,
                        hintText: 'Search',
                        hintStyle: T.body.copyWith(color: t.textMuted),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(D.radiusControl),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? const EmptyLine('No one yet. ⌘N to add.')
                      : _grouped(rows, t),
                ),
              ]),
            ),
            Expanded(
              child: sel == null
                  ? ScreenBody(
                      title: 'People',
                      trailing: Btn('Add person',
                          variant: BtnVariant.primary,
                          onPressed: () async {
                            await AddPersonSheet.show(context, widget.db);
                            _refreshTouches();
                          }),
                      child: const EmptyLine('Select a person.'),
                    )
                  : _detail(sel, t),
            ),
          ]);
        },
      ),
    );
  }

  /// Recent · 1–3 mo · 3–6 mo · 6 mo+ · Never
  Widget _grouped(List<Person> rows, AppTokens t) {
    final buckets = groupByRecency(rows, _lastTouch);

    return ListView(children: [
      for (final e in buckets.entries)
        if (e.value.isNotEmpty) ...[
          Container(
            height: D.groupHeader,
            color: t.canvas,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text('${e.key} · ${e.value.length}',
                style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
          ),
          for (final p in e.value)
            _ListRow(
              person: p,
              lastTouch: _lastTouch[p.id],
              selected: p.id == _selectedId,
              onTap: () => setState(() => _selectedId = p.id),
            ),
        ],
    ]);
  }

  Widget _detail(Person p, AppTokens t) {
    final isWa = channelFrom(p.preferredChannel) == Channel.wa;
    return ScreenBody(
      title: p.name,
      subtitle: Text(
          [
            p.company,
            if (p.metWhere != null && p.metWhere!.isNotEmpty)
              'met at ${p.metWhere}',
            if (p.metWhen != null) fmtDate(p.metWhen!),
          ].where((e) => e != null && e.isNotEmpty).join(' · '),
          style: T.secondary.copyWith(color: t.textSecondary)),
      trailing: Row(children: [
        if (isWa && (p.waNumber ?? '').isNotEmpty)
          Btn('Message',
              variant: BtnVariant.secondary,
              onPressed: () => openWhatsApp(p.waNumber!, '')),
        if (!isWa && (p.wechatId ?? '').isNotEmpty)
          Btn('Copy ID',
              variant: BtnVariant.secondary,
              onPressed: () => copyWeChatId(p.wechatId!)),
        const SizedBox(width: 6),
        // ⚠ Before this existed the only thing you could do to a person was
        // delete them — and delete is soft, so the workaround minted a new
        // UUID and silently detached every touch, note and money row that
        // pointed at the old one.
        Btn('Edit',
            variant: BtnVariant.secondary,
            onPressed: () => AddPersonSheet.show(context, widget.db, existing: p)),
        const SizedBox(width: 6),
        DeleteAction(
          what: p.name,
          size: BtnSize.md,
          onConfirmed: () async {
            await widget.db.softDelete(p.id);
            if (mounted) setState(() => _selectedId = null);
          },
        ),
      ]),
      child: ListView(children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⚠ Was 'WhatsApp · ${p.waNumber}' unconditionally, which
              // renders the literal text "WhatsApp · null" for anyone without
              // a number. preferredChannel defaults to 'wa' whether or not a
              // number was ever given, so the default is exactly the case that
              // printed null.
              _kv('CHANNEL', _channelLine(p), t),
              const SizedBox(height: 8),
              Text('OCCASIONS',
                  style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              if (p.occasionTags.isEmpty)
                Text('none tagged', style: T.body.copyWith(color: t.textMuted))
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final tag in p.occasionTags)
                    StatusTag(
                        tone: t.neutral,
                        label: OccasionTag.fromId(tag)?.label ?? tag),
                ]),
              if (p.notes != null && p.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _kv('NOTES', p.notes!, t),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PING',
                  style:
                      T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final (label, months) in const [
                  ('1 mo', 1),
                  ('3 mo', 3),
                  ('6 mo', 6),
                  ('12 mo', 12)
                ])
                  Btn(label,
                      size: BtnSize.sm,
                      variant: BtnVariant.secondary,
                      onPressed: () {
                        final n = DateTime.now();
                        widget.db.setPing(
                            p.id, DateTime(n.year, n.month + months, n.day));
                      }),
                if (p.pingDate != null)
                  Btn('Clear',
                      size: BtnSize.sm,
                      variant: BtnVariant.ghost,
                      onPressed: () => widget.db.setPing(p.id, null)),
              ]),
              const SizedBox(height: 6),
              Text(
                  p.pingDate == null
                      ? 'No ping set.'
                      : '${fmtDate(p.pingDate!)} · ${fmtIn(p.pingDate!)}'
                          '${p.pingNote != null && p.pingNote!.isNotEmpty ? ' — "${p.pingNote}"' : ''}',
                  style: T.body.copyWith(
                      color: p.pingDate == null ? t.textMuted : t.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LinkedProjects(db: widget.db, person: p),
        const SizedBox(height: 12),
        _Timeline(db: widget.db, personId: p.id, onLog: _refreshTouches),
      ]),
    );
  }

  static String _channelLine(Person p) {
    final wa = p.waNumber ?? '';
    final wechat = p.wechatId ?? '';
    if (wa.isEmpty && wechat.isEmpty) return 'none — cannot be messaged';
    return channelFrom(p.preferredChannel) == Channel.wa && wa.isNotEmpty
        ? 'WhatsApp · $wa'
        : wechat.isNotEmpty
            ? 'WeChat · $wechat'
            : 'WhatsApp · $wa';
  }

  Widget _kv(String k, String v, AppTokens t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(v, style: T.body.copyWith(color: t.textPrimary)),
        ],
      );
}

class _ListRow extends StatefulWidget {
  const _ListRow(
      {required this.person,
      required this.lastTouch,
      required this.selected,
      required this.onTap});
  final Person person;
  final DateTime? lastTouch;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final p = widget.person;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: D.listRowTwoLine,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? t.accentWash
                : _hover
                    ? t.subtle
                    : Colors.transparent,
            border: widget.selected
                ? Border(left: BorderSide(color: t.accent, width: 2))
                : null,
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(
                          color: t.textPrimary, fontWeight: FontWeight.w600)),
                  Text(p.company ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.secondary.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
            Text(fmtAgo(widget.lastTouch),
                style: T.secondary.copyWith(color: t.textMuted)),
            if (p.pingDate != null) ...[
              const SizedBox(width: 6),
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: t.attention.dot, shape: BoxShape.circle)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The other half of the counterparty link: what this person is actually
/// involved in. Without this the link is write-only.
class _LinkedProjects extends StatelessWidget {
  const _LinkedProjects({required this.db, required this.person});
  final AppDatabase db;
  final Person person;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<Engagement>>(
      stream: db.watchEngagementsForPerson(person.id),
      builder: (context, snap) {
        final rows = snap.data ?? const <Engagement>[];
        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('PROJECTS',
                    style: T.micro
                        .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                const Spacer(),
                Btn('Link new',
                    size: BtnSize.sm,
                    variant: BtnVariant.ghost,
                    onPressed: () =>
                        ProjectSheet.show(context, db, presetPerson: person)),
              ]),
              const SizedBox(height: 6),
              if (rows.isEmpty)
                Text('Nothing linked.',
                    style: T.body.copyWith(color: t.textMuted))
              else
                for (final e in rows)
                  GestureDetector(
                    onTap: () => ProjectSheet.show(context, db, existing: e),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: SizedBox(
                        height: D.timelineRow,
                        child: Row(children: [
                          SizedBox(
                            width: 52,
                            child: Text(e.type,
                                style: T.secondary
                                    .copyWith(color: t.textMuted)),
                          ),
                          Expanded(
                            child: Text(
                                [e.name, if ((e.status ?? '').isNotEmpty) e.status!]
                                    .join(' — '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.body.copyWith(color: t.textPrimary)),
                          ),
                          if (e.valueMinor != null)
                            Text(fmtMoney(e.valueMinor!, e.currency ?? 'CNY'),
                                style: T.mono.copyWith(color: t.textMuted)),
                        ]),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Type dot colour-codes source. ⚠ The one place status colour is used
/// non-semantically — allowed because the label sits beside it.
class _Timeline extends StatefulWidget {
  const _Timeline(
      {required this.db, required this.personId, required this.onLog});
  final AppDatabase db;
  final String personId;
  final VoidCallback onLog;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  final _line = TextEditingController();

  /// ⚠ ALWAYS OPTIONAL. Nothing in the app is gated on a touch existing —
  /// this is the field most likely to be abandoned, and that is fine.
  Future<void> _log() async {
    final v = _line.text.trim();
    if (v.isEmpty) return;
    await widget.db.logTouch(widget.personId, v);
    _line.clear();
    widget.onLog();
  }

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  /// ⚠ The one place status colour is used non-semantically — allowed here
  /// because the label sits beside the dot. touch = neutral, note = info,
  /// money = success/danger by direction.
  Widget _entries(List<Touch> touches, AppTokens t) => StreamBuilder<List<Note>>(
        stream: widget.db.watchNotesForPerson(widget.personId),
        builder: (context, noteSnap) => StreamBuilder<List<MoneyRow>>(
          stream: widget.db.watchMoneyForPerson(widget.personId),
          builder: (context, moneySnap) => StreamBuilder<List<Meeting>>(
            stream: widget.db.watchMeetingsForPerson(widget.personId),
            builder: (context, meetingSnap) {
            final entries = <TimelineEntry>[
              // ⚠ Meetings appear here whether they are past or future, which
              // is the point of connecting them: "when did I last see him" and
              // "when am I seeing him next" are one question asked in two
              // directions, and this is the one place both are answered.
              for (final m in meetingSnap.data ?? const <Meeting>[])
                TimelineEntry(
                    date: m.startsAt,
                    kind: 'meeting',
                    text: [
                      m.title,
                      fmtClock(m.startsAt),
                      if ((m.location ?? '').isNotEmpty) m.location!,
                    ].join(' · ')),
              for (final x in touches)
                TimelineEntry(date: x.date, kind: 'touch', text: x.oneLine),
              for (final n in noteSnap.data ?? const <Note>[])
                TimelineEntry(
                    date: n.date,
                    kind: 'note',
                    text: n.body.split('\n').first.isEmpty
                        ? 'untitled note'
                        : n.body.split('\n').first),
              for (final m in moneySnap.data ?? const <MoneyRow>[])
                TimelineEntry(
                    date: m.date,
                    kind: 'money',
                    direction: m.direction,
                    text: '${fmtMoney(m.amountMinor, m.currency)} '
                        '${m.direction} · ${m.label}'),
            ]..sort((a, b) => b.date.compareTo(a.date));

            if (entries.isEmpty) {
              return Text('Nothing logged yet.',
                  style: T.body.copyWith(color: t.textMuted));
            }
            return Column(
              children: [
                for (final e in entries)
                  SizedBox(
                    height: D.timelineRow,
                    child: Row(children: [
                      SizedBox(
                        width: 62,
                        child: Text(fmtDate(e.date),
                            textAlign: TextAlign.right,
                            style: T.mono.copyWith(color: t.textMuted)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: switch (e.kind) {
                              'note' => t.info.dot,
                              // ⚠ Same tone the calendar gives a meeting. Two
                              // views of one dataset must not teach different
                              // colour languages.
                              'meeting' => t.success.dot,
                              'money' => e.direction == 'in'
                                  ? t.success.dot
                                  : t.danger.dot,
                              _ => t.neutral.dot,
                            },
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        // 'meeting' is the longest kind and did not fit in 40.
                        width: 52,
                        child: Text(e.kind,
                            style: T.secondary.copyWith(color: t.textMuted)),
                      ),
                      Expanded(
                        child: Text(e.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.body.copyWith(color: t.textPrimary)),
                      ),
                    ]),
                  ),
              ],
            );
          },
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final personId = widget.personId;
    final t = AppTokens.of(context);
    return StreamBuilder<List<Touch>>(
      stream: db.watchTouches(personId),
      builder: (context, snap) {
        final rows = snap.data ?? const <Touch>[];
        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TIMELINE',
                  style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: D.control,
                    child: TextField(
                      controller: _line,
                      onSubmitted: (_) => _log(),
                      style: T.body.copyWith(color: t.textPrimary),
                      cursorColor: t.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: t.subtle,
                        hintText: 'called re: quotation, said next week',
                        hintStyle: T.body.copyWith(color: t.textMuted),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(D.radiusControl),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Btn('Log', size: BtnSize.sm, onPressed: _log),
              ]),
              const SizedBox(height: 8),
              _entries(rows, t),
            ],
          ),
        );
      },
    );
  }
}
