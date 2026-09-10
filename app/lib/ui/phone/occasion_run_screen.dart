import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/channel.dart';
import '../../domain/money_fmt.dart';
import '../../domain/occasions.dart';
import '../../theme/tokens.dart';
import 'phone_primitives.dart';

/// B2 + B3 — the run screen. One push from Today, which is one tap from the
/// notification: the two-step loop the flowchart asks for.
///
/// ⚠ This is the screen the phone justifies. On the Mac, `wa.me` resolves to
/// Safari and the send is a context switch; here the link opens WhatsApp with
/// the greeting already in the box.
class OccasionRunScreen extends StatefulWidget {
  const OccasionRunScreen(
      {super.key, required this.db, required this.occasion});
  final AppDatabase db;
  final Occasion occasion;

  @override
  State<OccasionRunScreen> createState() => _OccasionRunScreenState();
}

class _OccasionRunScreenState extends State<OccasionRunScreen> {
  final _sent = <String>{};
  String _lang = '';

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final o = widget.occasion;
    final tag = OccasionTag.fromId(o.tag);
    final greetings = kGreetings[tag] ?? const {'EN': ''};
    final langs = greetings.keys.toList();
    if (!langs.contains(_lang)) _lang = langs.first;
    final greeting = greetings[_lang] ?? '';

    return Scaffold(
      backgroundColor: t.canvas,
      body: StreamBuilder<List<Person>>(
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
              .where((p) => channelFrom(p.preferredChannel) == Channel.wechat)
              .toList();
          final done = people.where((p) => _sent.contains(p.id)).length;

          return PhoneBody(
            title: o.name,
            subtitle: Row(children: [
              PhoneTag(tone: t.attention, label: fmtIn(o.date)),
              const SizedBox(width: 8),
              Text('$done of ${people.length} sent',
                  style: PT.secondary.copyWith(color: t.textSecondary)),
            ]),
            trailing: PhoneBtn('Done',
                variant: PhoneBtnVariant.ghost,
                onPressed: () => Navigator.of(context).pop()),
            child: people.isEmpty
                ? const PhoneEmpty('No one is tagged for this occasion.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        PD.screenPad, 0, PD.screenPad, PD.sectionGap),
                    children: [
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
                          borderRadius:
                              BorderRadius.circular(D.radiusPanel),
                        ),
                        child: SelectableText(greeting,
                            style: PT.body.copyWith(color: t.textPrimary)),
                      ),
                      const SizedBox(height: PD.sectionGap),
                      if (wa.isNotEmpty)
                        PhoneSection('WhatsApp', [
                          for (final p in wa) _row(p, greeting, t, isWa: true),
                        ]),
                      if (wc.isNotEmpty)
                        PhoneSection('WeChat — copy, switch, paste', [
                          for (final p in wc) _row(p, greeting, t, isWa: false),
                        ]),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _row(Person p, String greeting, AppTokens t, {required bool isWa}) {
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
                      style: PT.secondary.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
            if (sent) PhoneTag(tone: t.success, label: 'Sent'),
          ]),
          if (!sent) ...[
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
                    await copyForWeChat(p.wechatId ?? '', greeting);
                    await copyWeChatId(p.wechatId ?? '');
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PhoneBtn('Mark sent', onPressed: () => _markSent(p)),
                ),
              ]),
          ],
        ],
      ),
    );
  }

  Future<void> _send(Person p, String greeting) async {
    await openWhatsApp(p.waNumber ?? '', greeting);
    await _markSent(p);
  }

  /// ⚠ The one place a touch is auto-logged rather than typed. The user has
  /// already confirmed the action; do not make them enter it twice.
  Future<void> _markSent(Person p) async {
    await widget.db.logTouch(p.id, 'sent ${widget.occasion.name} wishes');
    if (mounted) setState(() => _sent.add(p.id));
  }
}
