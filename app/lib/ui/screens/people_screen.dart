import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/database.dart';
import '../../domain/channel.dart';
import '../../domain/money_fmt.dart';
import '../../domain/occasions.dart';
import '../../theme/tokens.dart';
import '../add_person_sheet.dart';
import '../shell.dart';
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
    final buckets = <String, List<Person>>{
      'RECENT': [],
      '1–3 MO': [],
      '3–6 MO': [],
      '6 MO+': [],
      'NEVER': [],
    };
    for (final p in rows) {
      final lt = _lastTouch[p.id];
      if (lt == null) {
        buckets['NEVER']!.add(p);
      } else {
        final d = DateTime.now().difference(lt).inDays;
        if (d < 30) {
          buckets['RECENT']!.add(p);
        } else if (d < 90) {
          buckets['1–3 MO']!.add(p);
        } else if (d < 180) {
          buckets['3–6 MO']!.add(p);
        } else {
          buckets['6 MO+']!.add(p);
        }
      }
    }

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
          [p.company, p.metWhere].where((e) => e != null && e.isNotEmpty).join(' · '),
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
      ]),
      child: ListView(children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('CHANNEL', isWa ? 'WhatsApp · ${p.waNumber}' : 'WeChat · ${p.wechatId}', t),
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
              Row(children: [
                Text('PING',
                    style: T.micro
                        .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                const Spacer(),
                for (final (label, months) in const [
                  ('1 mo', 1),
                  ('3 mo', 3),
                  ('6 mo', 6),
                  ('12 mo', 12)
                ]) ...[
                  Btn(label,
                      size: BtnSize.sm,
                      variant: BtnVariant.ghost,
                      onPressed: () {
                        final n = DateTime.now();
                        widget.db.setPing(
                            p.id, DateTime(n.year, n.month + months, n.day));
                      }),
                  const SizedBox(width: 2),
                ],
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
        _Timeline(db: widget.db, personId: p.id, onLog: _refreshTouches),
      ]),
    );
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
              if (rows.isEmpty)
                Text('Nothing logged yet.',
                    style: T.body.copyWith(color: t.textMuted))
              else
                for (final r in rows)
                  SizedBox(
                    height: D.timelineRow,
                    child: Row(children: [
                      SizedBox(
                        width: 62,
                        child: Text(fmtDate(r.date),
                            textAlign: TextAlign.right,
                            style: T.mono.copyWith(color: t.textMuted)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              color: t.neutral.dot, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('touch',
                          style: T.secondary.copyWith(color: t.textMuted)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.oneLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.body.copyWith(color: t.textPrimary)),
                      ),
                    ]),
                  ),
            ],
          ),
        );
      },
    );
  }
}
