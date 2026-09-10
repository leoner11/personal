import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../domain/recency.dart';
import '../../theme/tokens.dart';
import 'person_detail_screen.dart';
import 'phone_primitives.dart';

/// Read-mostly. ⚠ Search is pinned at the top and is not optional — it is the
/// only viable way through 200 contacts on a phone, where the Mac gets by with
/// a 300pt list pane you can scan.
class PhonePeopleScreen extends StatefulWidget {
  const PhonePeopleScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhonePeopleScreen> createState() => _PhonePeopleScreenState();
}

class _PhonePeopleScreenState extends State<PhonePeopleScreen> {
  final _search = TextEditingController();
  Map<String, DateTime> _lastTouch = {};

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

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneBody(
      title: 'People',
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    PD.screenPad, 0, PD.screenPad, PD.groupGap),
                child: Container(
                  height: PD.control,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(D.radiusControl),
                  ),
                  child: Row(children: [
                    Icon(Icons.search, size: 20, color: t.textMuted),
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
                        onTap: () => _search.clear(),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.close, size: 20, color: t.textMuted),
                      ),
                  ]),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? PhoneEmpty(all.isEmpty
                        ? 'No one yet. Capture someone.'
                        : 'No match.')
                    : _grouped(rows, t),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _grouped(List<Person> rows, AppTokens t) {
    final buckets = groupByRecency(rows, _lastTouch);
    return ListView(
      padding: const EdgeInsets.only(bottom: PD.sectionGap),
      children: [
        for (final e in buckets.entries)
          if (e.value.isNotEmpty) ...[
            Container(
              height: PD.groupHeader,
              padding: const EdgeInsets.symmetric(horizontal: PD.screenPad),
              alignment: Alignment.centerLeft,
              child: Text('${e.key} · ${e.value.length}',
                  style: PT.micro
                      .copyWith(color: t.textMuted, letterSpacing: 0.6)),
            ),
            for (final p in e.value) _row(p, t),
          ],
      ],
    );
  }

  Widget _row(Person p, AppTokens t) => GestureDetector(
        onTap: () => _open(p),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: PD.listRowTwoLine,
          padding: const EdgeInsets.symmetric(horizontal: PD.screenPad),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.line)),
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
                      style: PT.body.copyWith(
                          color: t.textPrimary, fontWeight: FontWeight.w600)),
                  if (p.company != null && p.company!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(p.company!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PT.secondary.copyWith(color: t.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(fmtAgo(_lastTouch[p.id]),
                style: PT.secondary.copyWith(color: t.textMuted)),
          ]),
        ),
      );

  Future<void> _open(Person p) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PersonDetailScreen(db: widget.db, personId: p.id),
    ));
    // A touch may have been logged while the detail was open.
    if (mounted) await _loadTouches();
  }
}
