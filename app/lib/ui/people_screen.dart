import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/database.dart';
import '../domain/channel.dart';
import '../domain/occasions.dart';
import '../theme/tokens.dart';
import 'add_person_sheet.dart';
import 'widgets/primitives.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  /// null = everyone. Defaults to 中秋节, the occasion this build exists for.
  OccasionTag? _filter = kMidAutumnTag;
  String _lang = '中文';

  /// Whole calendar days, not elapsed 24h blocks — `inDays` on a raw
  /// difference truncates and reads one day short all afternoon.
  int get _daysToMidAutumn {
    final n = DateTime.now();
    return kMidAutumn2026.difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  String get _greeting =>
      kGreetings[_filter]?[_lang] ?? kGreetings[_filter]?.values.first ?? '';

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final stream = _filter == null
        ? widget.db.watchPeople()
        : widget.db.watchByTag(_filter!.name);

    return Scaffold(
      backgroundColor: t.canvas,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
              AddPersonSheet.show(context, widget.db, presetTag: _filter),
        },
        child: Focus(
          autofocus: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 34, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(t),
                const SizedBox(height: 14),
                _filters(t),
                const SizedBox(height: 12),
                if (_filter != null && kGreetings[_filter] != null) ...[
                  _greetingBox(t),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: StreamBuilder<List<Person>>(
                    stream: stream,
                    builder: (context, snap) {
                      final rows = snap.data ?? const <Person>[];
                      if (rows.isEmpty) {
                        return EmptyLine(_filter == null
                            ? 'No one yet. ⌘N to add the first.'
                            : 'No one tagged for ${_filter!.label} yet.');
                      }
                      return _groupedList(rows, t);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppTokens t) {
    final days = _daysToMidAutumn;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('People', style: T.screenTitle.copyWith(color: t.textPrimary)),
            const SizedBox(height: 2),
            Row(children: [
              StatusTag(
                  tone: days <= 14 ? t.attention : t.neutral,
                  label: days < 0
                      ? '中秋节 passed'
                      : days == 0
                          ? '中秋节 today'
                          : '中秋节 in $days days'),
              const SizedBox(width: 8),
              Text('25 Sep 2026',
                  style: T.secondary.copyWith(color: t.textSecondary)),
            ]),
          ],
        ),
        const Spacer(),
        Btn('Add person',
            variant: BtnVariant.primary,
            icon: Icons.add,
            onPressed: () =>
                AddPersonSheet.show(context, widget.db, presetTag: _filter)),
      ],
    );
  }

  Widget _filters(AppTokens t) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          TagChip(
              label: 'Everyone',
              selected: _filter == null,
              onTap: () => setState(() => _filter = null)),
          for (final tag in OccasionTag.values)
            TagChip(
                label: tag.label,
                selected: _filter == tag,
                onTap: () => setState(() => _filter = tag)),
        ],
      );

  /// Greeting template pinned above the list. Editing one line beats
  /// writing twelve.
  Widget _greetingBox(AppTokens t) {
    final langs = kGreetings[_filter]!.keys.toList();
    if (!langs.contains(_lang)) _lang = langs.first;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('GREETING',
                style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
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
          SelectableText(_greeting,
              style: T.body.copyWith(color: t.textPrimary)),
        ],
      ),
    );
  }

  /// ⚠ Half the list is 4x slower than the other half. WeChat contacts are
  /// grouped so the context-switch into the app happens once, not twelve times.
  Widget _groupedList(List<Person> rows, AppTokens t) {
    final wa = rows.where((p) => channelFrom(p.preferredChannel) == Channel.wa).toList();
    final wc = rows.where((p) => channelFrom(p.preferredChannel) == Channel.wechat).toList();

    return ListView(
      children: [
        if (wa.isNotEmpty) ...[
          _groupHeader('WHATSAPP · ${wa.length}', t),
          for (final p in wa) _PersonRow(person: p, greeting: _greeting, db: widget.db),
        ],
        if (wc.isNotEmpty) ...[
          _groupHeader('WECHAT · ${wc.length} — switch once, do all of these', t),
          for (final p in wc) _PersonRow(person: p, greeting: _greeting, db: widget.db),
        ],
      ],
    );
  }

  Widget _groupHeader(String label, AppTokens t) => Container(
        height: D.groupHeader,
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.only(top: 12, bottom: 2),
        child: Text(label,
            style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
      );
}

/// The list row — the backbone. Two lines, one piece of right-side meta,
/// actions on hover only.
class _PersonRow extends StatefulWidget {
  const _PersonRow(
      {required this.person, required this.greeting, required this.db});
  final Person person;
  final String greeting;
  final AppDatabase db;

  @override
  State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  bool _hover = false;
  String? _flash;

  Future<void> _flashMsg(String m) async {
    setState(() => _flash = m);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _flash = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final p = widget.person;
    final isWa = channelFrom(p.preferredChannel) == Channel.wa;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        height: D.listRowTwoLine,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: _hover ? t.subtle : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: T.body.copyWith(
                          color: t.textPrimary, fontWeight: FontWeight.w600)),
                  Text(
                      [
                        p.company,
                        isWa ? p.waNumber : p.wechatId,
                      ].where((e) => e != null && e.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.secondary.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
            if (_flash != null)
              StatusTag(tone: t.success, label: _flash!)
            else if (_hover) ...[
              if (isWa)
                Btn('Message',
                    size: BtnSize.sm,
                    variant: BtnVariant.ghost,
                    onPressed: () async {
                      final ok = await openWhatsApp(
                          p.waNumber ?? '', widget.greeting);
                      if (!ok) await _flashMsg('failed');
                    })
              else ...[
                Btn('Copy text',
                    size: BtnSize.sm,
                    variant: BtnVariant.ghost,
                    onPressed: () async {
                      await copyForWeChat(p.wechatId ?? '', widget.greeting);
                      await _flashMsg('text copied');
                    }),
                const SizedBox(width: 4),
                Btn('Copy ID',
                    size: BtnSize.sm,
                    variant: BtnVariant.ghost,
                    onPressed: () async {
                      await copyWeChatId(p.wechatId ?? '');
                      await _flashMsg('id copied');
                    }),
                const SizedBox(width: 4),
                Btn('WeChat',
                    size: BtnSize.sm,
                    variant: BtnVariant.ghost,
                    onPressed: openWeChat),
              ],
            ] else
              Text(isWa ? 'WhatsApp' : 'WeChat',
                  style: T.secondary.copyWith(color: t.textMuted)),
          ],
        ),
      ),
    );
  }
}
