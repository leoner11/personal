import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
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

        // Balance = sum of actuals, PER CURRENCY. Never converted.
        final balances = <String, int>{};
        final inExpected = <String, int>{};
        final outExpected = <String, int>{};
        for (final m in rows) {
          final sign = m.direction == 'in' ? 1 : -1;
          if (m.status == 'actual') {
            balances[m.currency] =
                (balances[m.currency] ?? 0) + sign * m.amountMinor;
          } else {
            final bucket = m.direction == 'in' ? inExpected : outExpected;
            bucket[m.currency] = (bucket[m.currency] ?? 0) + m.amountMinor;
          }
        }

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
                  if (balances.isEmpty)
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
                        for (final e in balances.entries)
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
                      totals: inExpected,
                      rows: rows
                          .where((m) =>
                              m.status == 'expected' && m.direction == 'in')
                          .toList(),
                      db: db)),
              const SizedBox(width: 12),
              Expanded(
                  child: _ExpectedColumn(
                      title: 'COMING OUT',
                      totals: outExpected,
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
                  Text(fmtMoney(m.amountMinor, m.currency),
                      style: T.mono.copyWith(color: t.textPrimary)),
                  const SizedBox(width: 6),
                  Btn('Confirm',
                      size: BtnSize.sm,
                      variant: BtnVariant.ghost,
                      onPressed: () => db.settleMoney(m.id)),
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
              const SizedBox(height: 10),
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
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn('Save', variant: BtnVariant.primary, onPressed: () async {
                  await widget.db.addMoney(MoneyCompanion.insert(
                    date: DateTime.now(),
                    direction: _dir,
                    amountMinor: toMinor(_amount.text, _cur),
                    currency: Value(_cur),
                    label: _label.text.trim().isEmpty
                        ? 'untitled'
                        : _label.text.trim(),
                    status: Value(_status),
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
