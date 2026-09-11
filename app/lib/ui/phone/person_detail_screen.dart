import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/channel.dart';
import '../../domain/money_fmt.dart';
import '../../domain/occasions.dart';
import '../../theme/tokens.dart';
import 'edit_person_sheet.dart';
import 'phone_primitives.dart';

/// D6 — the person timeline, plus log-a-touch. ⚠ Logging a touch is the one
/// write on this screen and it belongs on the phone specifically: touches
/// happen away from a desk, which is exactly when the Mac is not there.
class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen(
      {super.key, required this.db, required this.personId});
  final AppDatabase db;
  final String personId;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  final _touch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _touch.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _touch.dispose();
    super.dispose();
  }

  Future<void> _log() async {
    final line = _touch.text.trim();
    if (line.isEmpty) return;
    await widget.db.logTouch(widget.personId, line);
    if (mounted) {
      _touch.clear();
      FocusScope.of(context).unfocus();
    }
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
          final match = people.where((p) => p.id == widget.personId);
          if (match.isEmpty) return const PhoneEmpty('Gone.');
          final p = match.first;
          final isWa = channelFrom(p.preferredChannel) == Channel.wa;

          return PhoneBody(
            title: p.name,
            subtitle: p.company == null || p.company!.isEmpty
                ? null
                : Text(p.company!,
                    style: PT.secondary.copyWith(color: t.textSecondary)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              PhoneBtn('Edit',
                  variant: PhoneBtnVariant.ghost,
                  onPressed: () => PhoneSheet.show<bool>(
                      context, (_) => PhoneEditPersonSheet(db: widget.db, person: p))),
              const SizedBox(width: 4),
              PhoneBtn('Back',
                  variant: PhoneBtnVariant.ghost,
                  onPressed: () => Navigator.of(context).pop()),
            ]),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  PD.screenPad, 0, PD.screenPad, PD.sectionGap),
              children: [
                // The channel action, permanently visible.
                if (isWa && (p.waNumber ?? '').isNotEmpty)
                  PhoneBtn('Message on WhatsApp',
                      variant: PhoneBtnVariant.primary,
                      expand: true,
                      onPressed: () => openWhatsApp(p.waNumber!, ''))
                else if ((p.wechatId ?? '').isNotEmpty)
                  PhoneBtn('Copy WeChat ID',
                      expand: true,
                      onPressed: () => copyWeChatId(p.wechatId!)),
                const SizedBox(height: PD.sectionGap),

                if (p.occasionTags.isNotEmpty) ...[
                  Text('OCCASIONS',
                      style: PT.micro
                          .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in p.occasionTags)
                        PhoneTag(
                            tone: t.neutral,
                            label: OccasionTag.fromId(id)?.label ?? id),
                    ],
                  ),
                  const SizedBox(height: PD.sectionGap),
                ],

                for (final (label, value) in [
                  ('Met where', p.metWhere),
                  ('Met when', p.metWhen == null ? null : fmtDate(p.metWhen!)),
                  ('Notes', p.notes),
                ])
                  if (value != null && value.isNotEmpty) ...[
                    Text(label.toUpperCase(),
                        style: PT.micro
                            .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: PT.body.copyWith(color: t.textPrimary)),
                    const SizedBox(height: PD.groupGap),
                  ],

                const SizedBox(height: 4),
                PhoneField(
                    label: 'Log a touch',
                    controller: _touch,
                    hint: 'called about the gudang project'),
                const SizedBox(height: 8),
                PhoneBtn('Log',
                    expand: true,
                    onPressed: _touch.text.trim().isEmpty ? null : _log),

                const SizedBox(height: PD.sectionGap),
                Text('TIMELINE',
                    style: PT.micro
                        .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                StreamBuilder<List<Touch>>(
                  stream: widget.db.watchTouches(p.id),
                  builder: (context, tsnap) {
                    final rows = tsnap.data ?? const <Touch>[];
                    if (rows.isEmpty) {
                      return Text('Nothing logged yet.',
                          style: PT.secondary.copyWith(color: t.textMuted));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final row in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 74,
                                  child: Text(fmtDate(row.date),
                                      style: PT.secondary
                                          .copyWith(color: t.textMuted)),
                                ),
                                Expanded(
                                  child: Text(row.oneLine,
                                      style: PT.secondary
                                          .copyWith(color: t.textPrimary)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
