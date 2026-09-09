import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/channel.dart';
import '../../domain/money_fmt.dart';
import '../../domain/occasions.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
import '../widgets/primitives.dart';

/// B2 — the occasion run screen. The reason the app exists.
class OccasionsScreen extends StatefulWidget {
  const OccasionsScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<OccasionsScreen> createState() => _OccasionsScreenState();
}

class _OccasionsScreenState extends State<OccasionsScreen> {
  Occasion? _selected;
  String _lang = '中文';
  final _sent = <String>{};
  Map<String, int> _value = {};
  Map<String, DateTime> _lastTouch = {};

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    final v = await widget.db.engagementValueByPerson();
    final lt = await widget.db.lastTouchByPerson();
    if (mounted) {
      setState(() {
        _value = v;
        _lastTouch = lt;
      });
    }
  }

  /// ⚠ Highest-value and longest-neglected first, so if you only get through
  /// half the list it was the right half. Requires the counterparty link —
  /// without it every person ranks zero and this degrades to last-touch order.
  List<Person> _ranked(List<Person> rows) {
    final out = [...rows];
    out.sort((a, b) {
      final va = _value[a.id] ?? 0;
      final vb = _value[b.id] ?? 0;
      if (va != vb) return vb.compareTo(va);
      final ta = _lastTouch[a.id];
      final tb = _lastTouch[b.id];
      if (ta == null && tb == null) return a.name.compareTo(b.name);
      if (ta == null) return -1; // never touched sorts first
      if (tb == null) return 1;
      return ta.compareTo(tb); // oldest touch first
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<Occasion>>(
      stream: widget.db.watchOccasions(),
      builder: (context, snap) {
        final all = snap.data ?? const <Occasion>[];
        final upcoming = all
            .where((o) => o.date
                .isAfter(DateTime.now().subtract(const Duration(days: 2))))
            .toList();
        final sel = _selected != null &&
                all.any((o) => o.id == _selected!.id)
            ? all.firstWhere((o) => o.id == _selected!.id)
            : (upcoming.isNotEmpty ? upcoming.first : null);

        return Row(children: [
          // List pane
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
                child: Row(children: [
                  Expanded(
                    child: Text('UPCOMING · ${upcoming.length}',
                        style: T.micro.copyWith(
                            color: t.textMuted, letterSpacing: 0.5)),
                  ),
                  // ⚠ The runway warning tells you to add dates. It has to be
                  // possible to add them. Estimated Lebaran / Idul Adha /
                  // Deepavali dates also need correcting when announced.
                  Btn('Add',
                      size: BtnSize.sm,
                      onPressed: () => OccasionSheet.show(context, widget.db)),
                ]),
              ),
              Expanded(
                child: upcoming.isEmpty
                    ? const EmptyLine('No occasions seeded.')
                    : ListView(children: [
                        for (final o in upcoming)
                          _OccasionRow(
                            occasion: o,
                            selected: sel?.id == o.id,
                            onTap: () => setState(() => _selected = o),
                            onEdit: () => OccasionSheet.show(context, widget.db,
                                existing: o),
                          ),
                      ]),
              ),
            ]),
          ),
          Expanded(
            child: sel == null
                ? _seedPrompt(t)
                : _run(sel, t),
          ),
        ]);
      },
    );
  }

  Widget _seedPrompt(AppTokens t) => ScreenBody(
        title: 'Occasions',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('The occasion calendar is empty.',
                  style: T.body.copyWith(color: t.textMuted)),
              const SizedBox(height: 10),
              Btn('Seed three years',
                  variant: BtnVariant.primary,
                  onPressed: () => _seed()),
            ],
          ),
        ),
      );

  /// ⚠ Three years, not one. Converts a hard annual deadline into a two-year
  /// buffer. Dates are hand-entered because no API can supply them.
  Future<void> _seed() async {
    for (final row in kSeedOccasions) {
      await widget.db.into(widget.db.occasions).insert(OccasionsCompanion.insert(
            name: row.$1,
            date: row.$2,
            tag: row.$3.name,
            country: Value(row.$4),
          ));
    }
  }

  Widget _run(Occasion o, AppTokens t) {
    final tag = OccasionTag.fromId(o.tag);
    final greetings = kGreetings[tag] ?? const {'EN': ''};
    final langs = greetings.keys.toList();
    if (!langs.contains(_lang)) _lang = langs.first;
    final greeting = greetings[_lang] ?? '';

    return StreamBuilder<List<Person>>(
      stream: widget.db.watchByTag(o.tag),
      builder: (context, snap) {
        final people = _ranked(snap.data ?? const <Person>[]);
        final wa = people.where((p) => channelFrom(p.preferredChannel) == Channel.wa).toList();
        final wc = people.where((p) => channelFrom(p.preferredChannel) == Channel.wechat).toList();
        final done = people.where((p) => _sent.contains(p.id)).length;

        return ScreenBody(
          title: o.name,
          subtitle: Row(children: [
            StatusTag(
                tone: o.date.difference(DateTime.now()).inDays <= 14
                    ? t.attention
                    : t.neutral,
                label: fmtIn(o.date)),
            const SizedBox(width: 8),
            Text('${fmtDate(o.date)} · $done/${people.length} done',
                style: T.secondary.copyWith(color: t.textSecondary)),
          ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('GREETING',
                          style: T.micro
                              .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                      const Spacer(),
                      for (final l in langs) ...[
                        TagChip(
                            label: l,
                            selected: _lang == l,
                            onTap: () => setState(() => _lang = l)),
                        const SizedBox(width: 6),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    SelectableText(greeting,
                        style: T.body.copyWith(color: t.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CloseOut(db: widget.db, occasion: o),
              Expanded(
                child: people.isEmpty
                    ? EmptyLine('No one tagged for ${o.name}.')
                    : ListView(children: [
                        if (wa.isNotEmpty) ...[
                          _group('WHATSAPP · ${wa.length}', t),
                          for (final p in wa) _row(p, greeting, o, t),
                        ],
                        if (wc.isNotEmpty) ...[
                          _group(
                              'WECHAT · ${wc.length} — switch once, do all of these',
                              t),
                          for (final p in wc) _row(p, greeting, o, t),
                        ],
                      ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _group(String s, AppTokens t) => Container(
        height: D.groupHeader,
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(s,
            style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
      );

  Widget _row(Person p, String greeting, Occasion o, AppTokens t) {
    final isWa = channelFrom(p.preferredChannel) == Channel.wa;
    final sent = _sent.contains(p.id);
    return Container(
      height: D.listRowTwoLine,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name,
                  style: T.body.copyWith(
                      color: sent ? t.textMuted : t.textPrimary,
                      fontWeight: FontWeight.w600)),
              Text([p.company, isWa ? p.waNumber : p.wechatId]
                      .where((e) => e != null && e.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.secondary.copyWith(color: t.textSecondary)),
            ],
          ),
        ),
        if (sent)
          StatusTag(tone: t.success, label: 'Sent')
        else ...[
          if (isWa)
            Btn('Message',
                size: BtnSize.sm,
                variant: BtnVariant.ghost,
                onPressed: () => _send(p, greeting, o))
          else ...[
            Btn('Copy text',
                size: BtnSize.sm,
                variant: BtnVariant.ghost,
                onPressed: () => copyForWeChat(p.wechatId ?? '', greeting)),
            const SizedBox(width: 4),
            Btn('Copy ID',
                size: BtnSize.sm,
                variant: BtnVariant.ghost,
                onPressed: () => copyWeChatId(p.wechatId ?? '')),
            const SizedBox(width: 4),
            Btn('Mark sent',
                size: BtnSize.sm,
                variant: BtnVariant.ghost,
                onPressed: () => _markSent(p, o)),
          ],
          const SizedBox(width: 4),
          Btn('+ Gift',
              size: BtnSize.sm,
              variant: BtnVariant.ghost,
              onPressed: () => _gift(p, o)),
        ],
      ]),
    );
  }

  Future<void> _send(Person p, String greeting, Occasion o) async {
    await openWhatsApp(p.waNumber ?? '', greeting);
    await _markSent(p, o);
  }

  /// ⚠ The one place a touch is auto-logged rather than typed. The user
  /// already confirmed the action; do not make them enter it twice.
  Future<void> _markSent(Person p, Occasion o) async {
    await widget.db.logTouch(p.id, 'sent ${o.name} wishes');
    if (mounted) setState(() => _sent.add(p.id));
  }

  /// B4 — the one place the relationship half and the money half touch.
  Future<void> _gift(Person p, Occasion o) async {
    final res = await _GiftSheet.show(context, p.name, o.name);
    if (res == null) return;
    await widget.db.addMoney(MoneyCompanion.insert(
      date: o.date,
      direction: 'out',
      amountMinor: res.$1,
      currency: Value(res.$2),
      label: '${o.name} gift — ${p.name}',
      status: const Value('expected'),
      personId: Value(p.id),
      occasionTag: Value(o.tag),
    ));
  }
}

class _OccasionRow extends StatelessWidget {
  const _OccasionRow(
      {required this.occasion,
      required this.selected,
      required this.onTap,
      required this.onEdit});
  final Occasion occasion;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: D.listRowTwoLine,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? t.accentWash : Colors.transparent,
          border: selected
              ? Border(left: BorderSide(color: t.accent, width: 2))
              : null,
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(occasion.name,
                    style: T.body.copyWith(
                        color: t.textPrimary, fontWeight: FontWeight.w600)),
                Text(
                    [
                      fmtDate(occasion.date),
                      fmtIn(occasion.date),
                      if ((occasion.country ?? '').isNotEmpty) occasion.country!,
                    ].join(' · '),
                    style: T.secondary.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          Btn('Edit',
              size: BtnSize.sm, variant: BtnVariant.ghost, onPressed: onEdit),
        ]),
      ),
    );
  }
}

class _GiftSheet extends StatefulWidget {
  const _GiftSheet({required this.person, required this.occasion});
  final String person, occasion;

  static Future<(int, String)?> show(
          BuildContext c, String person, String occasion) =>
      showDialog<(int, String)>(
          context: c,
          builder: (_) => _GiftSheet(person: person, occasion: occasion));

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  final _what = TextEditingController();
  final _amount = TextEditingController();
  String _cur = 'CNY';

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Dialog(
      backgroundColor: t.canvas,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gift for ${widget.person}',
                  style: T.entityName.copyWith(color: t.textPrimary)),
              const SizedBox(height: 14),
              Field(label: 'What', controller: _what, hint: 'mooncake box'),
              const SizedBox(height: 10),
              Field(label: 'Amount', controller: _amount, hint: '400'),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final c in kCurrencies)
                  TagChip(
                      label: c,
                      selected: _cur == c,
                      onTap: () => setState(() => _cur = c)),
              ]),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn('Commit',
                    variant: BtnVariant.primary,
                    onPressed: () => Navigator.pop(
                        context, (toMinor(_amount.text, _cur), _cur))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}


/// B5 — occasion close-out. ⚠ Without this, expected gift rows accumulate
/// forever and the balance silently drifts from reality. This is the single
/// most likely way the money feature rots, and the T+1 notification already
/// promises the screen exists.
class _CloseOut extends StatelessWidget {
  const _CloseOut({required this.db, required this.occasion});
  final AppDatabase db;
  final Occasion occasion;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<MoneyRow>>(
      stream: db.watchMoney(),
      builder: (context, snap) {
        final rows = (snap.data ?? const <MoneyRow>[])
            .where((m) => m.occasionTag == occasion.tag && m.deletedAt == null)
            .toList();
        if (rows.isEmpty) return const SizedBox.shrink();

        final expected = rows.where((m) => m.status == 'expected').toList();
        final totals = <String, int>{};
        for (final m in rows) {
          totals[m.currency] = (totals[m.currency] ?? 0) + m.amountMinor;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('GIFTS COMMITTED',
                        style: T.micro
                            .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                    Text(
                        totals.entries
                            .map((e) => fmtMoney(e.value, e.key))
                            .join(' · '),
                        style: T.body.copyWith(
                            color: t.textPrimary, fontWeight: FontWeight.w600)),
                    Text('across ${rows.length} people',
                        style: T.secondary.copyWith(color: t.textSecondary)),
                    if (expected.isNotEmpty)
                      Btn('Confirm all ${expected.length} as spent',
                          size: BtnSize.sm,
                          variant: BtnVariant.primary, onPressed: () async {
                        for (final m in expected) {
                          await db.settleMoney(m.id);
                        }
                      }),
                  ],
                ),
                if (expected.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text('All confirmed as actual.',
                      style: T.secondary.copyWith(color: t.textMuted)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class OccasionSheet extends StatefulWidget {
  const OccasionSheet({super.key, required this.db, this.existing});
  final AppDatabase db;
  final Occasion? existing;

  static Future<void> show(BuildContext c, AppDatabase db, {Occasion? existing}) =>
      showDialog(
          context: c, builder: (_) => OccasionSheet(db: db, existing: existing));

  @override
  State<OccasionSheet> createState() => _OccasionSheetState();
}

class _OccasionSheetState extends State<OccasionSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _country =
      TextEditingController(text: widget.existing?.country ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late OccasionTag _tag =
      OccasionTag.fromId(widget.existing?.tag ?? '') ?? OccasionTag.newYear;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing == null ? 'Add occasion' : 'Edit occasion',
                  style: T.screenTitle.copyWith(color: t.textPrimary)),
              const SizedBox(height: 4),
              Text(
                  'Lebaran, Idul Adha and Deepavali move on sighting — correct '
                  'the seeded estimate here once it is announced.',
                  style: T.secondary.copyWith(color: t.textMuted)),
              const SizedBox(height: 14),
              Field(label: 'Name', controller: _name, hint: '春节 Chinese New Year'),
              const SizedBox(height: 12),
              DateField(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                  offsets: const [('+1y', 365)]),
              const SizedBox(height: 12),
              Text('TAG',
                  style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final tag in OccasionTag.values)
                  TagChip(
                      label: tag.label,
                      selected: _tag == tag,
                      onTap: () => setState(() => _tag = tag)),
              ]),
              const SizedBox(height: 4),
              Text('Decides who gets prompted — people carrying this tag.',
                  style: T.secondary.copyWith(color: t.textMuted)),
              const SizedBox(height: 12),
              Field(label: 'Country', controller: _country, hint: 'ID/MY'),
              const SizedBox(height: 18),
              Row(children: [
                if (widget.existing != null)
                  DeleteAction(
                    what: 'the occasion "${widget.existing!.name}"',
                    size: BtnSize.md,
                    onConfirmed: () async {
                      await widget.db.softDeleteRow(
                          widget.db.occasions, widget.existing!.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                const Spacer(),
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn('Save', variant: BtnVariant.primary, onPressed: _save),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? _tag.label : _name.text.trim();
    if (widget.existing != null) {
      await (widget.db.update(widget.db.occasions)
            ..where((o) => o.id.equals(widget.existing!.id)))
          .write(OccasionsCompanion(
        name: Value(name),
        date: Value(_date),
        tag: Value(_tag.name),
        country: Value(_country.text.trim()),
        updatedAt: Value(DateTime.now()),
      ));
    } else {
      await widget.db.into(widget.db.occasions).insert(OccasionsCompanion.insert(
            name: name,
            date: _date,
            tag: _tag.name,
            country: Value(_country.text.trim()),
          ));
    }
    if (mounted) Navigator.pop(context);
  }
}
