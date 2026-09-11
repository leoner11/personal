import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../domain/money_totals.dart';
import '../../theme/tokens.dart';
import 'phone_pickers.dart';
import 'phone_primitives.dart';

/// ⚠ The stated problem was "I want to know how much money we have." That is
/// solved by seeing ONE NUMBER OFTEN, not by better accounting — and a phone
/// is the device you actually look at often, which is the argument for this
/// screen existing here at all.
///
/// ⚠ WHAT DOES NOT CARRY FROM THE MAC: the ledger there is "the only true
/// table in the app" — five fixed-width columns totalling ~310pt plus gaps.
/// At 390pt minus 40pt of screen padding that overflows, and shrinking the
/// columns produces a table nobody can read. It becomes two-line rows here.
/// Coming in / coming out are stacked for the same reason, never side by side.
class PhoneMoneyScreen extends StatelessWidget {
  const PhoneMoneyScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<MoneyRow>>(
      stream: db.watchMoney(),
      builder: (context, snap) {
        final rows = snap.data ?? const <MoneyRow>[];

        final totals = MoneyTotals.of(rows);

        return PhoneBody(
          title: 'Money',
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                PhoneSheet.show<void>(context, (_) => _MoneySheet(db: db)),
            child: SizedBox(
              width: PD.tapMin,
              height: PD.tapMin,
              child: Icon(Icons.add, size: 26, color: t.accent),
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              PD.screenPad,
              0,
              PD.screenPad,
              PD.sectionGap,
            ),
            children: [
              _CashOnHand(balances: totals.balances),
              const SizedBox(height: PD.sectionGap),
              _Expected(
                title: 'COMING IN',
                totals: totals.inExpected,
                rows: rows
                    .where((m) => m.status == 'expected' && m.direction == 'in')
                    .toList(),
                db: db,
              ),
              _Expected(
                title: 'COMING OUT',
                totals: totals.outExpected,
                rows: rows
                    .where(
                      (m) => m.status == 'expected' && m.direction == 'out',
                    )
                    .toList(),
                db: db,
              ),
              _Ledger(rows: rows, db: db),
            ],
          ),
        );
      },
    );
  }
}

class _CashOnHand extends StatelessWidget {
  const _CashOnHand({required this.balances});
  final Map<String, int> balances;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CASH ON HAND',
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          if (balances.isEmpty)
            Text(
              '—',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: t.textMuted,
              ),
            )
          else
            // ⚠ The one permitted exception to the type ceiling. This is the
            // number the whole screen exists to show.
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                for (final e in balances.entries)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmtMoney(e.value, e.key),
                        style: kTabular.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        e.key,
                        style: PT.secondary.copyWith(color: t.textMuted),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            'sum of actuals · currencies never converted',
            style: PT.secondary.copyWith(color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

/// ⚠ Hidden entirely when empty, never rendered as an empty box — the same
/// rule the Mac follows, and it matters more on a phone where an empty
/// section is a whole screenful of nothing.
class _Expected extends StatelessWidget {
  const _Expected({
    required this.title,
    required this.totals,
    required this.rows,
    required this.db,
  });
  final String title;
  final Map<String, int> totals;
  final List<MoneyRow> rows;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final t = AppTokens.of(context);
    return PhoneSection(title, [
      for (final m in rows)
        PhoneRow(
          title: m.label,
          subtitle: fmtDate(m.date),
          onTap: () => PhoneSheet.show<void>(
            context,
            (_) => _SettleSheet(db: db, row: m),
          ),
          trailing: Text(
            fmtMoney(m.amountMinor, m.currency),
            style: PT.mono.copyWith(color: t.textPrimary),
          ),
          chevron: true,
        ),
      const PhoneDivider(),
      const SizedBox(height: 8),
      for (final e in totals.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total ${e.key}',
                style: PT.secondary.copyWith(color: t.textSecondary),
              ),
              Text(
                fmtMoney(e.value, e.key),
                style: PT.mono.copyWith(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
    ]);
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.rows, required this.db});
  final List<MoneyRow> rows;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (rows.isEmpty) {
      return PhoneSection('LEDGER', [
        Text('No money rows yet.', style: PT.body.copyWith(color: t.textMuted)),
      ]);
    }
    return PhoneSection('LEDGER', [
      for (final m in rows) ...[
        PhoneRow(
          title: m.label,
          // The four columns the Mac gives their own headers become one
          // readable line: when, which way, and whether it really happened.
          subtitle: [
            fmtDate(m.date),
            m.direction == 'in' ? 'in' : 'out',
            m.status == 'actual' ? 'actual' : 'expected',
          ].join(' · '),
          onTap: m.status == 'expected'
              ? () => PhoneSheet.show<void>(
                  context,
                  (_) => _SettleSheet(db: db, row: m),
                )
              : null,
          trailing: Text(
            fmtMoney(m.amountMinor, m.currency),
            style: PT.mono.copyWith(
              color: m.status == 'actual' ? t.textPrimary : t.textSecondary,
            ),
          ),
        ),
        const PhoneDivider(),
      ],
    ]);
  }
}

/// D2 — settling an expected row. ⚠ "Confirm" alone is not enough: the amount
/// often differs, and a date that slips repeatedly is itself information.
/// Writing off is a soft delete, never a hard one.
class _SettleSheet extends StatefulWidget {
  const _SettleSheet({required this.db, required this.row});
  final AppDatabase db;
  final MoneyRow row;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  late final _amount = TextEditingController(
    text: fmtMoney(widget.row.amountMinor, widget.row.currency, symbol: false),
  );
  late DateTime _date = widget.row.date;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _minor => toMinor(_amount.text, widget.row.currency);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneSheet(
      title: widget.row.label,
      actions: Column(
        children: [
          PhoneBtn(
            'Confirm actual',
            variant: PhoneBtnVariant.primary,
            expand: true,
            onPressed: () async {
              await widget.db.settleMoney(
                widget.row.id,
                amountMinor: _minor,
                date: _date,
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PhoneBtn(
                  'Keep expected',
                  onPressed: () async {
                    await widget.db.updateMoney(
                      widget.row.id,
                      MoneyCompanion(
                        amountMinor: Value(_minor),
                        date: Value(_date),
                        updatedAt: Value(DateTime.now()),
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PhoneBtn(
                  'Write off',
                  variant: PhoneBtnVariant.ghost,
                  onPressed: () => _confirmWriteOff(context),
                ),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhoneField(
            label: 'Amount',
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneDateRow(
            label: 'Date',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 8),
          Text(
            'Push the date to keep it expected. Confirm to make it actual '
            'at the amount above.',
            style: PT.secondary.copyWith(color: t.textMuted),
          ),
        ],
      ),
    );
  }

  /// ⚠ Destructive, so it asks — and it is a soft delete underneath, which is
  /// what makes writing off recoverable on the Mac if it was a mistake.
  Future<void> _confirmWriteOff(BuildContext context) async {
    final t = AppTokens.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: t.canvas,
        title: Text(
          'Write off?',
          style: PT.entityName.copyWith(color: t.textPrimary),
        ),
        content: Text(
          '"${widget.row.label}" stops counting as expected.',
          style: PT.body.copyWith(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'Cancel',
              style: PT.body.copyWith(color: t.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              'Write off',
              style: PT.body.copyWith(color: t.danger.text),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.db.updateMoney(
      widget.row.id,
      MoneyCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (context.mounted) Navigator.pop(context);
  }
}

class _MoneySheet extends StatefulWidget {
  const _MoneySheet({required this.db});
  final AppDatabase db;

  @override
  State<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends State<_MoneySheet> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  String _cur = 'CNY';
  String _dir = 'in';
  String _status = 'expected';
  Person? _person;
  Engagement? _project;

  /// ⚠ Expected money is future money. Defaulting to today and offering no way
  /// to change it made "coming in / coming out" structurally useless.
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _label.addListener(() => setState(() {}));
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _valid =>
      _label.text.trim().isNotEmpty && toMinor(_amount.text, _cur) > 0;

  @override
  Widget build(BuildContext context) {
    return PhoneSheet(
      title: 'Add money row',
      actions: Row(
        children: [
          Expanded(
            child: PhoneBtn(
              'Cancel',
              variant: PhoneBtnVariant.ghost,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PhoneBtn(
              'Save',
              variant: PhoneBtnVariant.primary,
              onPressed: _valid ? _save : null,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhoneField(
            label: 'Label',
            controller: _label,
            hint: 'Powerline M3',
            autofocus: true,
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(
            label: 'Amount',
            controller: _amount,
            hint: '25000',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneDateRow(
            label: 'Date',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: PD.sectionGap),
          _ChipGroup(
            label: 'Currency',
            options: kCurrencies,
            selected: _cur,
            onTap: (v) => setState(() => _cur = v),
          ),
          const SizedBox(height: PD.groupGap),
          _ChipGroup(
            label: 'Direction',
            options: const ['in', 'out'],
            selected: _dir,
            onTap: (v) => setState(() => _dir = v),
          ),
          const SizedBox(height: PD.groupGap),
          _ChipGroup(
            label: 'Status',
            options: const ['expected', 'actual'],
            selected: _status,
            onTap: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: PD.sectionGap),
          PhoneLinkRow(
            label: 'Person',
            value: _person?.name,
            onTap: () async {
              final p = await pickPerson(context, widget.db);
              if (p != null) setState(() => _person = p);
            },
            onClear: () => setState(() => _person = null),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneLinkRow(
            label: 'Project',
            value: _project?.name,
            onTap: () async {
              final e = await pickProject(context, widget.db);
              if (e != null) setState(() => _project = e);
            },
            onClear: () => setState(() => _project = null),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    await widget.db.addMoney(
      MoneyCompanion.insert(
        date: _date,
        direction: _dir,
        amountMinor: toMinor(_amount.text, _cur),
        currency: Value(_cur),
        label: _label.text.trim(),
        status: Value(_status),
        personId: Value(_person?.id),
        engagementId: Value(_project?.id),
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}

/// ⚠ Labelled, unlike the Mac's bare chip rows. Three unlabelled chip groups
/// stacked on a phone is a puzzle; on a wide dialog they read as one line.
class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              PhoneChip(
                label: o,
                selected: selected == o,
                onTap: () => onTap(o),
              ),
          ],
        ),
      ],
    );
  }
}
