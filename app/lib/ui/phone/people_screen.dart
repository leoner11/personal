import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'capture_screen.dart' show showNewPersonSheet;
import '../../data/database.dart';
import '../../domain/channel.dart';
import '../../domain/money_fmt.dart' show fmtAgo;
import '../../domain/recency.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'edit_person_sheet.dart';
import 'person_detail_screen.dart';
import 'phone_primitives.dart';

/// C1 — the forgotten-person loop. The list exists to make "who has gone
/// quiet" visible in one glance and to put one ping, log or edit one thumb
/// away. Read-mostly: every write here is a shortcut to a verb the detail
/// screen already offers — no new verbs.
///
/// v2: collapsing title, 44pt add entry (the capture contract in a sheet —
/// the Capture tab itself stays untouched, P3), trailing swipe for the
/// channel verb, long-press menu carrying the detail screen's verbs, and
/// search that flattens to A–Z because a query means you already know who
/// you want.
class PhonePeopleScreen extends StatefulWidget {
  const PhonePeopleScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhonePeopleScreen> createState() => _PhonePeopleScreenState();
}

class _PhonePeopleScreenState extends State<PhonePeopleScreen> {
  final _search = TextEditingController();

  /// Person id → last touch. Loads async AFTER the first frame on purpose:
  /// the list renders from the first stream tick and re-buckets when the map
  /// lands — no blank flash while the touch query runs (§3.4).
  Map<String, DateTime> _lastTouch = {};

  /// Rows pending their 200ms fade + collapse after a soft delete (§3.6: the
  /// list never keeps a hole). id → the row as it was, plus the bucket it
  /// came from, so it collapses where it lived.
  final Map<String, _Vanishing> _vanishing = {};

  /// True once the list has scrolled past where the title folds (~26px);
  /// the search field compacts 48 → 44pt with it.
  bool _compact = false;

  @override
  void initState() {
    super.initState();
    _loadTouches();
    _search.addListener(() => setState(() {}));
  }

  Future<void> _loadTouches() async {
    final m = await widget.db.lastTouchByPerson();
    if (mounted) setState(() => _lastTouch = m);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Push the tab's ONE push. When [openEdit], the edit sheet presents OVER
  /// the pushed detail (push installs its route synchronously; the sheet
  /// lands on top), so a save leaves the user on the refreshed record.
  Future<void> _open(Person p, {bool focusLog = false, bool openEdit = false}) {
    final done = Navigator.of(context)
        .push<void>(MaterialPageRoute(
          builder: (_) => PersonDetailScreen(
              db: widget.db, personId: p.id, focusLog: focusLog),
        ))
        // A touch may have been logged while the detail was open — re-bucket
        // the row when it comes back (v1 behaviour, kept).
        .whenComplete(() {
      if (mounted) _loadTouches();
    });
    if (openEdit) {
      unawaited(done);
      return PhoneSheet.show(
          context, (_) => PhoneEditPersonSheet(db: widget.db, person: p));
    }
    return done;
  }

  Future<void> _delete(Person p, String bucket) async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete ${p.name}?',
      body: 'The row is kept so the other device learns it is gone.',
    );
    // The warning haptic fires inside the confirm — on the destructive
    // confirm only, never on opening it.
    if (!ok) return;
    await widget.db.softDelete(p.id);
    if (!mounted) return;
    setState(() => _vanishing[p.id] = _Vanishing(p, bucket));
    Timer(const Duration(milliseconds: PM.clearMs + 60), () {
      if (mounted) setState(() => _vanishing.remove(p.id));
    });
  }

  void _menu(Person p, String bucket) {
    final wa = (p.waNumber ?? '').isNotEmpty;
    final wc = (p.wechatId ?? '').isNotEmpty;
    unawaited(showPhoneMenu(context, title: p.name, items: [
      // The detail screen's verbs — a menu never invents new ones. WhatsApp
      // first when both exist, matching the preferred-channel default.
      if (wa)
        PhoneMenuItem('Message on WhatsApp', icon: Ic.message,
            onTap: () => unawaited(openWhatsApp(p.waNumber!, ''))),
      if (wc)
        PhoneMenuItem('Copy WeChat ID', icon: Ic.copy,
            onTap: () => copyWeChatId(p.wechatId!)),
      PhoneMenuItem('Log a touch', onTap: () => _open(p, focusLog: true)),
      PhoneMenuItem('Edit', onTap: () => _open(p, openEdit: true)),
      PhoneMenuItem('Delete person', danger: true,
          onTap: () => _delete(p, bucket)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneScaffold(
      title: 'People',
      actions: [
        // The add entry: Capture's contract in a sheet (§7). The capture tab
        // itself stays untouched — adding a person must not cost capture a
        // single tap.
        PhonePressable(
          onTap: () => unawaited(showNewPersonSheet(context, widget.db)),
          child: SizedBox(
            width: PD.tapMin,
            height: PD.tapMin,
            child: Center(
              child: AppIcon(Ic.add, size: 26, color: t.accent),
            ),
          ),
        ),
      ],
      child: StreamBuilder<List<Person>>(
        stream: widget.db.watchPeople(),
        builder: (context, snap) {
          final all = snap.data ?? const <Person>[];
          final q = _search.text.trim().toLowerCase();
          final searching = q.isNotEmpty;
          final List<Person> rows;
          if (searching) {
            rows = all
                .where((p) =>
                    p.name.toLowerCase().contains(q) ||
                    (p.company ?? '').toLowerCase().contains(q))
                .toList();
            // Flat A–Z, name then company: a query means the user already
            // knows who they want; headers would only be noise.
            rows.sort((a, b) {
              final byName =
                  a.name.toLowerCase().compareTo(b.name.toLowerCase());
              if (byName != 0) return byName;
              return (a.company ?? '')
                  .toLowerCase()
                  .compareTo((b.company ?? '').toLowerCase());
            });
          } else {
            rows = all;
          }

          // The scroll listener wraps the whole body — the list is a sibling
          // of the search field, not a descendant of it.
          return NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Column(
              children: [
                _searchField(t),
                Expanded(
                  child: rows.isEmpty && _vanishing.isEmpty
                      ? PhoneEmpty(all.isEmpty ? 'No one yet.' : 'No match.')
                      : searching
                          ? _flat(rows, t)
                          : _grouped(rows, t),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification) return false;
    final compact = n.metrics.pixels > 26;
    if (compact != _compact) setState(() => _compact = compact);
    return false;
  }

  /// Pinned search — never scrolls away; it is the only viable way through
  /// 200 contacts on a phone. Compacts 48 → 44pt as the title folds (the
  /// same threshold), the query surviving the collapse in one controller.
  /// `Ic.dismiss` (clear) exists only when there is something to clear.
  Widget _searchField(AppTokens t) {
    final q = _search.text;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.ease,
      height: _compact ? PD.tapMin : PD.control,
      margin: const EdgeInsets.fromLTRB(
          PD.screenPad, 0, PD.screenPad, PD.groupGap),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(D.radiusControl),
      ),
      child: Row(children: [
        AppIcon(Ic.search, size: 18, color: t.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _search,
            style: PT.body.copyWith(color: t.textPrimary),
            cursorColor: t.accent,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Search',
              hintStyle: PT.body.copyWith(color: t.textMuted),
            ),
          ),
        ),
        if (q.isNotEmpty)
          GestureDetector(
            onTap: _search.clear,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: PD.tapMin,
              height: PD.tapMin,
              child: Center(
                child: AppIcon(Ic.dismiss, size: 18, color: t.textMuted),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _grouped(List<Person> rows, AppTokens t) {
    final buckets = groupByRecency(rows, _lastTouch);
    return ListView(
      padding: const EdgeInsets.only(bottom: PD.sectionGap),
      children: [
        for (final e in buckets.entries)
          if (e.value.isNotEmpty || _bucketHasVanishing(e.key)) ...[
            _header('${e.key} · ${e.value.length}', t),
            for (final p in e.value) _listRow(p, e.key, t),
            // A just-deleted row collapses inside its old group, so the gap
            // closes in place instead of the group jumping (§3.6).
            for (final v in _vanishing.values)
              if (v.bucket == e.key) _VanishingRow(row: v.person, t: t),
          ],
      ],
    );
  }

  bool _bucketHasVanishing(String bucket) =>
      _vanishing.values.any((v) => v.bucket == bucket);

  Widget _flat(List<Person> rows, AppTokens t) {
    return ListView(
      padding: const EdgeInsets.only(bottom: PD.sectionGap),
      children: [
        for (final p in rows) _listRow(p, '', t),
        for (final v in _vanishing.values) _VanishingRow(row: v.person, t: t),
      ],
    );
  }

  Widget _header(String text, AppTokens t) => Container(
        height: PD.groupHeader,
        padding: const EdgeInsets.symmetric(horizontal: PD.screenPad),
        alignment: Alignment.centerLeft,
        child: Text(text,
            style:
                PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.6)),
      );

  Widget _listRow(Person p, String bucket, AppTokens t) {
    final row = Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PD.screenPad),
        child: PhoneRow(
          title: p.name,
          subtitle: p.company,
          minHeight: PD.listRowTwoLine,
          trailing: Text(fmtAgo(_lastTouch[p.id]),
              style: PT.secondary.copyWith(color: t.textMuted)),
          onTap: () => _open(p),
        ),
      ),
    );
    return GestureDetector(
      onLongPress: () => _menu(p, bucket),
      child: _swipeable(p, t, row),
    );
  }

  /// Trailing swipe, ONE action, chosen by channel — Message for
  /// WhatsApp-reachable people, Copy WeChat for the rest, NOTHING for people
  /// with no channel (a swipe that reveals no verb is dead glass). The verb
  /// fires externally; the list does not mutate, so the row snaps back.
  Widget _swipeable(Person p, AppTokens t, Widget row) {
    final wa = (p.waNumber ?? '').isNotEmpty;
    final wc = (p.wechatId ?? '').isNotEmpty;
    if (!wa && !wc) return row;
    final useWa = wa; // WhatsApp first, matching the preferred-channel default
    return Dismissible(
      key: ValueKey('swipe-${p.id}'),
      direction: DismissDirection.endToStart,
      background: PhoneSwipeBackground(
        label: useWa ? 'Message' : 'Copy WeChat',
        icon: useWa ? Ic.message : Ic.copy,
        color: t.accentWash,
      ),
      confirmDismiss: (_) {
        PhoneHaptic.light(); // light impact on swipe fire, never decoration
        if (useWa) {
          unawaited(openWhatsApp(p.waNumber!, ''));
        } else {
          copyWeChatId(p.wechatId!);
        }
        return Future.value(false);
      },
      child: row,
    );
  }
}

/// A row and the bucket it came from, kept alive for the removal animation.
class _Vanishing {
  const _Vanishing(this.person, this.bucket);
  final Person person;
  final String bucket;
}

/// The 200ms fade + collapse a deleted row plays before the list closes the
/// gap (§3.6 — the kept removal animation). Rendered from the last-known
/// [Person], dead to gestures.
class _VanishingRow extends StatelessWidget {
  const _VanishingRow({required this.row, required this.t});
  final Person row;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Mounts at 1 and animates to 0 — the collapse starts the frame the
      // confirm lands, with no extra state machine.
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: PM.clearMs),
      curve: Curves.ease,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Align(
          heightFactor: v,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: Container(
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PD.screenPad),
          child: PhoneRow(
            title: row.name,
            subtitle: row.company,
            minHeight: PD.listRowTwoLine,
          ),
        ),
      ),
    );
  }
}
