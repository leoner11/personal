import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/channel.dart';
import '../../domain/money_fmt.dart';
import '../../domain/occasions.dart';
import '../../domain/tag_vocab.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'phone_primitives.dart';

/// B2 + B3 — the run screen. One push from Today, which is one tap from the
/// notification: the two-step loop the flowchart asks for.
///
/// ⚠ This is the screen the phone justifies. On the Mac, `wa.me` resolves to
/// Safari and the send is a context switch; here the link opens WhatsApp with
/// the greeting already in the box.
///
/// ⚠ NO mid-run dialogs — not before Send, not after. The user already
/// confirmed the action; asking again doubles the cost of every row of the
/// run and the run is long enough already.
class OccasionRunScreen extends StatefulWidget {
  const OccasionRunScreen(
      {super.key, required this.db, required this.occasion});
  final AppDatabase db;
  final Occasion occasion;

  @override
  State<OccasionRunScreen> createState() => _OccasionRunScreenState();
}

class _OccasionRunScreenState extends State<OccasionRunScreen> {
  /// ⚠ A CACHE, NOT THE RECORD (§7 fix). Sent state is DERIVED from the touch
  /// log: a person is sent iff their log holds the auto-entry
  /// `sent {occasion.name} wishes` dated on/after `occasion.date − 14 days`
  /// (the run window; the −14d guard stops last year's same-named occasion
  /// from poisoning this year's run). The v1 in-memory set that lost
  /// checkmarks on leave was a defect — leave, kill the app, come back from
  /// Calendar: muted names, Sent tags and X of Y all restore, and a touch
  /// synced from another device restores too.
  final _sent = <String>{};
  String _lang = '';

  @override
  void initState() {
    super.initState();
    _seedSent();
  }

  Future<void> _seedSent() async {
    final o = widget.occasion;
    final cutoff = o.date.subtract(const Duration(days: 14));
    final line = 'sent ${o.name} wishes';
    final touches = await widget.db.allTouches();
    if (!mounted) return;
    setState(() {
      _sent.addAll(touches
          .where((t) => t.oneLine == line && !t.date.isBefore(cutoff))
          .map((t) => t.personId));
    });
  }

  /// ⚠ The one place a touch is auto-logged rather than typed. The user has
  /// already confirmed the action; do not make them enter it twice — and the
  /// log entry here is what makes sent-state survive at all (§7).
  Future<void> _markSent(Person p) async {
    await widget.db.logTouch(p.id, 'sent ${widget.occasion.name} wishes');
    if (mounted) setState(() => _sent.add(p.id));
  }

  Future<void> _send(Person p, String greeting) async {
    await openWhatsApp(p.waNumber ?? '', greeting);
    await _markSent(p);
  }

  /// Fade + collapse of the action row into sent grammar over [PM.clearMs]
  /// (§3.6 "mark sent"). The card itself NEVER disappears — the run needs its
  /// record visible; only the buttons melt away.
  Widget _actions(bool collapse, Widget child) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: collapse ? 0.0 : 1.0),
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

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final o = widget.occasion;
    // ⚠ The occasion's own greeting wins (Phase 3): a Thanksgiving tagged
    // under the New Year audience must not inherit the New Year template.
    // Only the template path has languages to pick from.
    // ⚠ THREE LINKS, MOST SPECIFIC FIRST: this occasion's own greeting, then
    // the tag's default, then the built-in template. The middle link is what
    // makes a user-defined tag usable at all — 'Hanukkah' has no entry in
    // kGreetings and never will, so without it every run for a tag the user
    // invented would open WhatsApp with an empty message box.
    final custom = o.greeting?.trim().isNotEmpty == true
        ? o.greeting!.trim()
        : (TagVocab.bySlug(o.tag)?.greeting?.trim() ?? '');
    final usesTemplate = custom.isEmpty;
    final tag = OccasionTag.fromId(o.tag);
    final greetings = kGreetings[tag] ?? const {'EN': ''};
    // Languages exist only on the template path: a greeting someone typed is
    // one string, so there is nothing to switch between.
    final langs = usesTemplate ? greetings.keys.toList() : const <String>[];
    if (usesTemplate && !langs.contains(_lang)) _lang = langs.first;
    final greeting = usesTemplate ? (greetings[_lang] ?? '') : custom;

    return PhoneScaffold(
      title: o.name,
      // §3.1: header actions are 44pt icon buttons, never text. The v1 `Done`
      // text button dies; the system back gesture pops identically.
      actions: [
        PhonePressable(
          onTap: () => Navigator.of(context).pop(),
          child: SizedBox(
            width: PD.tapMin,
            height: PD.tapMin,
            child: Center(
              child: AppIcon(Ic.confirm, size: 22, color: t.accent),
            ),
          ),
        ),
      ],
      child: StreamBuilder<List<Person>>(
        stream: widget.db.watchByTag(o.tag),
        builder: (context, snap) {
          final people = snap.data ?? const <Person>[];
          final wa = people
              .where((p) => channelFrom(p.preferredChannel) == Channel.wa)
              .toList();
          // ⛔ No deep link can target a WeChat chat. Grouping them together is
          // the whole mitigation: the context switch happens once rather than
          // once per person.
          final wc = people
              .where(
                  (p) => channelFrom(p.preferredChannel) == Channel.wechat)
              .toList();
          final done = people.where((p) => _sent.contains(p.id)).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                PD.screenPad, 0, PD.screenPad, PD.sectionGap),
            children: [
              if (people.isEmpty)
                const PhoneEmpty('No one is tagged for this occasion.')
              else ...[
                // ⚠ A fraction, never a ring or bar (desktop Occasions rule).
                Row(children: [
                  PhoneTag(tone: t.attention, label: fmtIn(o.date)),
                  const SizedBox(width: 8),
                  Text('$done of ${people.length} sent',
                      style:
                          PT.secondary.copyWith(color: t.textSecondary)),
                ]),
                const SizedBox(height: PD.groupGap),
                if (langs.length > 1) ...[
                  Row(children: [
                    for (final l in langs) ...[
                      PhoneChip(
                          label: l,
                          selected: _lang == l,
                          onTap: () => setState(() => _lang = l)),
                      const SizedBox(width: 8),
                    ],
                  ]),
                  const SizedBox(height: PD.groupGap),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.subtle,
                    borderRadius: BorderRadius.circular(D.radiusPanel),
                  ),
                  child: SelectableText(greeting,
                      style: PT.body.copyWith(color: t.textPrimary)),
                ),
                const SizedBox(height: PD.sectionGap),
                if (wa.isNotEmpty)
                  PhoneSection('WhatsApp', [
                    for (final p in wa)
                      _personCard(p, greeting, t, isWa: true),
                  ]),
                if (wc.isNotEmpty)
                  PhoneSection('WeChat — copy, switch, paste', [
                    for (final p in wc)
                      _personCard(p, greeting, t, isWa: false),
                  ]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _personCard(Person p, String greeting, AppTokens t,
      {required bool isWa}) {
    final sent = _sent.contains(p.id);
    return PhoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PT.body.copyWith(
                          color: sent ? t.textMuted : t.textPrimary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                      [p.company, isWa ? p.waNumber : p.wechatId]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          PT.secondary.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
            if (sent) PhoneTag(tone: t.success, label: 'Sent'),
          ]),
          // ⚠ The button row fades and collapses into the sent grammar — it
          // does not vanish in one frame, and it does not linger either.
          _actions(
            sent,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                if (isWa)
                  PhoneBtn('Send',
                      variant: PhoneBtnVariant.primary,
                      expand: true,
                      onPressed: () => _send(p, greeting))
                else
                  Row(children: [
                    Expanded(
                      child: PhoneBtn('Copy text', onPressed: () async {
                        // Both land on the clipboard, in this order: paste
                        // the greeting, then search the id — copy-then-
                        // switch is the only WeChat path there is.
                        await copyForWeChat(p.wechatId ?? '', greeting);
                        await copyWeChatId(p.wechatId ?? '');
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PhoneBtn(
                          'Mark sent', onPressed: () => _markSent(p)),
                    ),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
