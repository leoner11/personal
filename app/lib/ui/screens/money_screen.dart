import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../domain/money_totals.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
import '../widgets/pickers.dart';
import '../widgets/primitives.dart';

/// ⚠ The stated problem was "I want to know how much money we have." That is
/// solved by seeing ONE NUMBER OFTEN, not by better accounting. Everything
/// here is subordinate to keeping that number visible and true.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<MoneyRow>>(
      stream: db.watchMoney(),
      builder: (context, snap) {
        final rows = snap.data ?? const <MoneyRow>[];

        final totals = MoneyTotals.of(rows);

        return ScreenBody(
          title: 'Money',
          trailing: Btn('Add row',
              variant: BtnVariant.primary,
              onPressed: () => _AddMoneySheet.show(context, db)),
          child: ListView(children: [
            // The one permitted exception to the 20pt type ceiling.
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CASH ON HAND',
                      style: T.micro
                          .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  if (totals.balances.isEmpty)
                    Text('—',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: t.textMuted))
                  else
                    Wrap(
                      spacing: 28,
                      runSpacing: 10,
                      children: [
                        for (final e in totals.balances.entries)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fmtMoney(e.value, e.key),
                                  style: kTabular.copyWith(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: t.textPrimary)),
                              Text(e.key,
                                  style: T.secondary
                                      .copyWith(color: t.textMuted)),
                            ],
                          ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text('sum of actuals · currencies never converted',
                      style: T.secondary.copyWith(color: t.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _ExpectedColumn(
                      title: 'COMING IN',
                      totals: totals.inExpected,
                      rows: rows
                          .where((m) =>
                              m.status == 'expected' && m.direction == 'in')
                          .toList(),
                      db: db)),
              const SizedBox(width: 12),
              Expanded(
                  child: _ExpectedColumn(
                      title: 'COMING OUT',
                      totals: totals.outExpected,
                      rows: rows
                          .where((m) =>
                              m.status == 'expected' && m.direction == 'out')
                          .toList(),
                      db: db)),
            ]),
            const SizedBox(height: 12),
            _Ledger(rows: rows, db: db),
          ]),
        );
      },
    );
  }
}

class _ExpectedColumn extends StatelessWidget {
  const _ExpectedColumn(
      {required this.title,
      required this.totals,
      required this.rows,
      required this.db});
  final String title;
  final Map<String, int> totals;
  final List<MoneyRow> rows;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text('Nothing expected.',
                style: T.body.copyWith(color: t.textMuted))
          else ...[
            for (final m in rows)
              SizedBox(
                height: D.tableRow,
                child: Row(children: [
                  Expanded(
                      child: Text(m.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.body.copyWith(color: t.textPrimary))),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(fmtMoney(m.amountMinor, m.currency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.mono.copyWith(color: t.textPrimary)),
                  ),
                  const SizedBox(width: 6),
                  _SettleActions(db: db, row: m),
                ]),
              ),
            Divider(color: t.line, height: 14),
            for (final e in totals.entries)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total ${e.key}',
                    style: T.secondary.copyWith(color: t.textSecondary)),
                Text(fmtMoney(e.value, e.key),
                    style: T.mono.copyWith(
                        color: t.textPrimary, fontWeight: FontWeight.w600)),
              ]),
          ],
        ],
      ),
    );
  }
}

/// The only true table in the app.
/// D2 — settling an expected row. ⚠ "Confirm" alone is not enough: the amount
/// often differs, and a date that slips repeatedly is itself information
/// (the Prawnwatch pattern). Writing off is a soft delete, never a hard one.
class _SettleActions extends StatelessWidget {
  const _SettleActions({required this.db, required this.row});
  final AppDatabase db;
  final MoneyRow row;

  // Two inline actions only — these sit in a half-width column. Writing off
  // lives in the sheet, which is where a destructive action belongs anyway.
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Btn('Confirm',
            size: BtnSize.sm,
            variant: BtnVariant.ghost,
            onPressed: () => db.settleMoney(row.id)),
        Btn('Edit',
            size: BtnSize.sm,
            variant: BtnVariant.ghost,
            onPressed: () => _SettleSheet.show(context, db, row)),
      ]);
}

class _SettleSheet extends StatefulWidget {
  const _SettleSheet({required this.db, required this.row});
  final AppDatabase db;
  final MoneyRow row;

  static Future<void> show(BuildContext c, AppDatabase db, MoneyRow row) =>
      showDialog(context: c, builder: (_) => _SettleSheet(db: db, row: row));

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  late final _amount = TextEditingController(
      text: fmtMoney(widget.row.amountMinor, widget.row.currency, symbol: false));
  late DateTime _date = widget.row.date;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.row.label,
                  style: T.entityName.copyWith(color: t.textPrimary)),
              const SizedBox(height: 14),
              Field(label: 'Amount', controller: _amount),
              const SizedBox(height: 12),
              DateField(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d)),
              const SizedBox(height: 6),
              Text(
                  'Push the date to keep it expected. Confirm to make it '
                  'actual at the amount above.',
                  style: T.secondary.copyWith(color: t.textMuted)),
              const SizedBox(height: 18),
              Row(children: [
                DeleteAction(
                  what: 'the expected row "${widget.row.label}"',
                  label: 'Write off',
                  size: BtnSize.md,
                  onConfirmed: () async {
                    await widget.db.updateMoney(
                        widget.row.id,
                        MoneyCompanion(
                            deletedAt: Value(DateTime.now()),
                            updatedAt: Value(DateTime.now())));
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const Spacer(),
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn('Keep expected', onPressed: () async {
                  await widget.db.updateMoney(
                      widget.row.id,
                      MoneyCompanion(
                          amountMinor:
                              Value(toMinor(_amount.text, widget.row.currency)),
                          date: Value(_date),
                          updatedAt: Value(DateTime.now())));
                  if (context.mounted) Navigator.pop(context);
                }),
                const SizedBox(width: 8),
                Btn('Confirm actual', variant: BtnVariant.primary,
                    onPressed: () async {
                  await widget.db.settleMoney(widget.row.id,
                      amountMinor: toMinor(_amount.text, widget.row.currency),
                      date: _date);
                  if (context.mounted) Navigator.pop(context);
                }),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.rows, required this.db});
  final List<MoneyRow> rows;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Container(
          height: D.tableRow,
          decoration: BoxDecoration(
            color: t.subtle,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(D.radiusPanel)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            SizedBox(width: 70, child: _h('DATE', t)),
            SizedBox(width: 40, child: _h('DIR', t)),
            SizedBox(width: 110, child: _h('AMOUNT', t, right: true)),
            const SizedBox(width: 12),
            Expanded(child: _h('LABEL', t)),
            SizedBox(width: 80, child: _h('STATUS', t)),
          ]),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('No money rows yet.',
                style: T.body.copyWith(color: t.textMuted)),
          )
        else
          for (final m in rows)
            Container(
              height: D.tableRow,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                SizedBox(
                    width: 70,
                    child: Text(fmtDate(m.date),
                        style: T.mono.copyWith(color: t.textSecondary))),
                SizedBox(
                    width: 40,
                    child: Text(m.direction,
                        style: T.secondary.copyWith(color: t.textSecondary))),
                SizedBox(
                  width: 110,
                  child: Text(fmtMoney(m.amountMinor, m.currency),
                      textAlign: TextAlign.right,
                      style: T.mono.copyWith(color: t.textPrimary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(m.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.body.copyWith(color: t.textPrimary))),
                SizedBox(
                  width: 80,
                  child: StatusTag(
                      tone: m.status == 'actual' ? t.success : t.info,
                      label: m.status == 'actual' ? 'Actual' : 'Expected'),
                ),
              ]),
            ),
      ]),
    );
  }

  Widget _h(String s, AppTokens t, {bool right = false}) => Text(s,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5));
}

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet({required this.db});
  final AppDatabase db;

  static Future<void> show(BuildContext c, AppDatabase db) =>
      showDialog(context: c, builder: (_) => _AddMoneySheet(db: db));

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  String _cur = 'CNY';
  String _dir = 'in';
  String _status = 'expected';
  Person? _person;
  Engagement? _project;
  /// ⚠ Expected money is future money. Defaulting to today and offering no
  /// way to change it made "coming in / coming out" structurally useless.
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add money row',
                  style: T.screenTitle.copyWith(color: t.textPrimary)),
              const SizedBox(height: 14),
              Field(label: 'Label', controller: _label, hint: 'Powerline M3'),
              const SizedBox(height: 10),
              Field(label: 'Amount', controller: _amount, hint: '25000'),
              const SizedBox(height: 12),
              DateField(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [
                for (final c in kCurrencies)
                  TagChip(
                      label: c,
                      selected: _cur == c,
                      onTap: () => setState(() => _cur = c)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final d in const ['in', 'out'])
                  TagChip(
                      label: d,
                      selected: _dir == d,
                      onTap: () => setState(() => _dir = d)),
                const SizedBox(width: 14),
                for (final s in const ['expected', 'actual'])
                  TagChip(
                      label: s,
                      selected: _status == s,
                      onTap: () => setState(() => _status = s)),
              ]),
              const SizedBox(height: 14),
              Text('LINKS',
                  style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              LinkBar(
                db: widget.db,
                personName: _person?.name,
                projectName: _project?.name,
                onPerson: (p) => setState(() => _person = p),
                onProject: (e) => setState(() => _project = e),
              ),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn('Save', variant: BtnVariant.primary, onPressed: () async {
                  await widget.db.addMoney(MoneyCompanion.insert(
                    date: _date,
                    direction: _dir,
                    amountMinor: toMinor(_amount.text, _cur),
                    currency: Value(_cur),
                    label: _label.text.trim().isEmpty
                        ? 'untitled'
                        : _label.text.trim(),
                    status: Value(_status),
                    personId: Value(_person?.id),
                    engagementId: Value(_project?.id),
                  ));
                  if (context.mounted) Navigator.pop(context);
                }),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
