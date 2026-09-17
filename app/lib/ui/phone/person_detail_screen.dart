import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/channel.dart';
import '../../domain/money_fmt.dart';
import '../../domain/tag_vocab.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'edit_person_sheet.dart';
import 'phone_primitives.dart';

/// One merged timeline row. ⚠ NOT the database's `TimelineEntry` — that class
/// carries no amount or currency, and "money rows append a right-aligned mono
/// amount" (spec §2) needs both. Private, so the shared contract stays put.
class _Entry {
  const _Entry({
    required this.date,
    required this.kind,
    required this.text,
    this.direction,
    this.amountMinor,
    this.currency,
  });
  final DateTime date;

  /// touch | note | money
  final String kind;
  final String text;

  /// 'in' | 'out' for money rows, null otherwise.
  final String? direction;
  final int? amountMinor;
  final String? currency;
}

/// D6 — the person's record, plus log-a-touch. ⚠ Logging a touch is the one
/// write that belongs on the phone specifically: touches happen away from a
/// desk, which is exactly when the Mac is not there (v1 comment, kept).
///
/// v2 changes the chrome, not the job: system back (the literal `Back` button
/// dies), 44pt icon actions, the channel verb pinned to the bottom bar where
/// the thumb already is, and a merged touch/note/money timeline in the
/// desktop's §5 grammar — flat, reverse-chronological, fixed date gutter.
class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({
    super.key,
    required this.db,
    required this.personId,
    this.focusLog = false,
  });
  final AppDatabase db;
  final String personId;

  /// Pushed from the People long-press menu's `Log a touch`: the log field
  /// arrives focused, keyboard up — the verb starts where the finger was.
  final bool focusLog;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  final _touch = TextEditingController();
  final _logFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _touch.addListener(() => setState(() {}));
    if (widget.focusLog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_logFocus);
      });
    }
  }

  @override
  void dispose() {
    _touch.dispose();
    _logFocus.dispose();
    super.dispose();
  }

  /// ⚠ No confirmation. One-line note, one tap — the standing write (v1
  /// rule). The field clears and the keyboard drops; the row itself arrives
  /// on the next stream tick, and the empty field IS the feedback.
  Future<void> _log() async {
    final line = _touch.text.trim();
    if (line.isEmpty) return;
    await widget.db.logTouch(widget.personId, line);
    if (!mounted) return;
    _touch.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.canvas,
      body: StreamBuilder<List<Person>>(
        stream: widget.db.watchPeople(),
        builder: (context, snap) {
          final people = snap.data ?? const <Person>[];
          // Deleted on another device while this screen was open.
          final match = people.where((p) => p.id == widget.personId);
          if (match.isEmpty) return const PhoneEmpty('Gone.');
          final person = match.first;

          // One channel decision, made once and carried by BOTH the nav icon
          // and the pinned bar: WhatsApp when reachable (preferred), copy for
          // WeChat-only — no deep link can target a WeChat chat (⛔
          // channel.dart).
          final waOk = (person.waNumber ?? '').isNotEmpty;
          final wcOk = (person.wechatId ?? '').isNotEmpty;
          final useWa = waOk &&
              (channelFrom(person.preferredChannel) == Channel.wa || !wcOk);
          final useWc = !useWa && wcOk;

          return StreamBuilder<List<Touch>>(
            stream: widget.db.watchTouches(person.id),
            builder: (context, tsnap) {
              final touches = tsnap.data ?? const <Touch>[];
              // Desc-ordered stream, so the newest touch is the first row.
              final last = touches.isEmpty ? null : touches.first.date;
              final company = person.company;
              final hasCompany = company != null && company.isNotEmpty;
              final subtitle =
                  '${hasCompany ? '$company · ' : ''}last touch ${fmtAgo(last)}';

              final kbUp = MediaQuery.viewInsetsOf(context).bottom > 0;

              return Column(
                children: [
                  Expanded(
                    child: PhoneScaffold(
                      title: person.name,
                      subtitle: subtitle,
                      actions: [
                        if (useWa)
                          _navIcon(Ic.message, t,
                              onTap: () => openWhatsApp(person.waNumber!, ''))
                        else if (useWc)
                          _navIcon(Ic.copy, t,
                              onTap: () => copyWeChatId(person.wechatId!)),
                        _navIcon(Ic.pencil, t, onTap: _edit(person)),
                      ],
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(PD.screenPad, 0,
                            PD.screenPad, PD.sectionGap),
                        children: [
                          ..._record(person, t),
                          _logField(t),
                          ..._timelineSection(touches, t),
                        ],
                      ),
                    ),
                  ),
                  // ⚠ The pinned channel bar is the channel verb at thumb
                  // height — the v1 top-of-content button scrolled away before
                  // the decision to ping. While the keyboard is up the slot
                  // yields (the platform accessory bar with `Done` takes
                  // over); no channel means NO BAR — the space is simply
                  // returned, no disabled button furniture (P4).
                  if ((useWa || useWc) && !kbUp)
                    Container(
                      decoration: BoxDecoration(
                        color: t.canvas,
                        border: Border(top: BorderSide(color: t.line)),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                          PD.screenPad, 10, PD.screenPad, 0),
                      child: SafeArea(
                        top: false,
                        child: PhoneBtn(
                          useWa ? 'Message on WhatsApp' : 'Copy WeChat ID',
                          variant: useWa
                              ? PhoneBtnVariant.primary
                              : PhoneBtnVariant.secondary,
                          expand: true,
                          onPressed: useWa
                              ? () => openWhatsApp(person.waNumber!, '')
                              : () => copyWeChatId(person.wechatId!),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// 44pt nav action — icons, not words; the system gesture is back (§3.1).
  Widget _navIcon(Ic icon, AppTokens t, {required VoidCallback onTap}) =>
      PhonePressable(
        onTap: onTap,
        child: SizedBox(
          width: PD.tapMin,
          height: PD.tapMin,
          child: Center(
            child: AppIcon(icon, size: 22, color: t.textSecondary),
          ),
        ),
      );

  VoidCallback _edit(Person person) => () => PhoneSheet.show<bool>(
      context, (_) => PhoneEditPersonSheet(db: widget.db, person: person));

  /// The read-only record: occasions, met where/when, notes. Blocks hide when
  /// empty — an empty section is a whole screenful of nothing.
  List<Widget> _record(Person person, AppTokens t) {
    final blocks = <Widget>[];
    if (person.occasionTags.isNotEmpty) {
      blocks.addAll([
        Text('OCCASIONS',
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<OccasionTagRow>>(
          valueListenable: TagVocab.all,
          builder: (context, _, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in person.occasionTags)
                // Neutral, not tappable — occasions are managed in the edit
                // sheet. A slug with no row in the vocabulary falls back to
                // the raw slug, not a crash.
                PhoneTag(tone: t.neutral, label: TagVocab.labelFor(id)),
            ],
          ),
        ),
        const SizedBox(height: PD.sectionGap),
      ]);
    }
    for (final (label, value) in [
      ('Met where', person.metWhere),
      ('Met when', person.metWhen == null ? null : fmtDate(person.metWhen!)),
      ('Notes', person.notes),
    ]) {
      if (value != null && value.isNotEmpty) {
        blocks.addAll([
          Text(label.toUpperCase(),
              style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: PT.body.copyWith(color: t.textPrimary)),
          const SizedBox(height: PD.groupGap),
        ]);
      }
    }
    if (blocks.isNotEmpty) {
      blocks.add(const SizedBox(height: PD.sectionGap));
    }
    return blocks;
  }

  Widget _logField(AppTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhoneField(
          label: 'Log a touch',
          controller: _touch,
          focusNode: _logFocus,
          hint: 'called about the gudang project',
          // Keyboard accessory `[Done]` (§3.2) drops the keyboard; the
          // submit is the Log button below — a field-level submit would be
          // a second submit for one action.
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 8),
        // Inline secondary expand — works with or without the keyboard up.
        // (Loser: Log in the accessory bar — a second submit for one action.)
        PhoneBtn('Log',
            expand: true,
            onPressed: _touch.text.trim().isEmpty ? null : _log),
        const SizedBox(height: PD.sectionGap),
      ],
    );
  }

  List<Widget> _timelineSection(List<Touch> touches, AppTokens t) {
    return [
      Text('TIMELINE',
          style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      // Notes and money merge in beside the touches; all three streams are
      // local-first, so first frames render with touches alone and the rest
      // lands within a tick — structure never blanks (§3.4).
      StreamBuilder<List<Note>>(
        stream: widget.db.watchNotesForPerson(widget.personId),
        builder: (context, nsnap) => StreamBuilder<List<MoneyRow>>(
          stream: widget.db.watchMoneyForPerson(widget.personId),
          builder: (context, msnap) {
            final notes = nsnap.data ?? const <Note>[];
            final money = msnap.data ?? const <MoneyRow>[];
            final entries = <_Entry>[
              for (final row in touches)
                _Entry(date: row.date, kind: 'touch', text: row.oneLine),
              for (final note in notes)
                _Entry(
                  date: note.date,
                  kind: 'note',
                  // Row-title rule from the desktop: first line, `untitled`
                  // when empty.
                  text: note.body.isEmpty
                      ? 'untitled'
                      : note.body.split('\n').first,
                ),
              for (final row in money)
                _Entry(
                  date: row.date,
                  kind: 'money',
                  text: row.label,
                  direction: row.direction,
                  amountMinor: row.amountMinor,
                  currency: row.currency,
                ),
            ]..sort((a, b) => b.date.compareTo(a.date));

            if (entries.isEmpty) {
              return Text('Nothing logged yet.',
                  style: PT.secondary.copyWith(color: t.textMuted));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries) _entryRow(e, t),
              ],
            );
          },
        ),
      ),
    ];
  }

  /// One flat, informational row. ⚠ NOT tappable: the money source lives
  /// behind Review, and a cross-tab deep link would break "nothing more than
  /// one push from its tab" — the timeline stays quiet (spec §2, loser
  /// named). No hairlines: the dot + gutter structure the column.
  Widget _entryRow(_Entry e, AppTokens t) {
    final tone = switch (e.kind) {
      'note' => t.info,
      'money' => e.direction == 'in' ? t.success : t.danger,
      _ => t.neutral,
    };
    final isMoney = e.kind == 'money';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              fmtDate(e.date),
              textAlign: TextAlign.right,
              // Past years read `8 Sep 2025` and wrap under the year — the
              // gutter is fixed, the date is honest.
              maxLines: 2,
              style: PT.mono.copyWith(
                color: t.textMuted,
                fontFeatures: kTabular.fontFeatures,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration:
                BoxDecoration(color: tone.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isMoney
                ? Row(
                    children: [
                      Expanded(
                        child: Text(e.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PT.secondary
                                .copyWith(color: t.textPrimary)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        // Money is mono, tabular, right-aligned (§8); the
                        // direction already shows as the dot's tone.
                        fmtMoney(e.amountMinor ?? 0, e.currency ?? 'CNY'),
                        style: PT.mono.copyWith(
                          color: t.textPrimary,
                          fontFeatures: kTabular.fontFeatures,
                        ),
                      ),
                    ],
                  )
                : Text(
                    // Notes carry a kind marker — a note can read like a
                    // touch, and the dot alone is too quiet to tell them
                    // apart at a glance.
                    e.kind == 'note' ? '(note) ${e.text}' : e.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PT.secondary.copyWith(color: t.textPrimary),
                  ),
          ),
        ],
      ),
    );
  }
}
