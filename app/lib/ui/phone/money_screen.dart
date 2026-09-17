import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/auth.dart';
import '../../domain/config.dart';
import '../../domain/money_fmt.dart';
import '../../domain/money_totals.dart';
import '../../domain/sync.dart';
import '../../domain/sync_account.dart';
import '../widgets/app_icon.dart';
import '../../theme/tokens.dart';
import 'person_detail_screen.dart';
import 'phone_pickers.dart';
import 'phone_primitives.dart';
import 'sync_join_sheet.dart';

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
///
/// v2: every ledger row is tappable — expected rows settle, ACTUAL rows
/// correct (the v1 dead-row defect, §7 fix). Links become visible in the row
/// subtitles, and the tap-through is the `View person` row inside the sheets,
/// never a target inside a 72pt row's subtitle — a target that small breaks
/// the 44pt floor, which has no exceptions.

/// The sync pulse behind pull-to-refresh (§3.4). Shared by this screen and
/// the Review hub so the quiet-line grammar exists in exactly one place.
///
/// ⚠ Sync needs BOTH a configured https server and a signed-in account — the
/// desktop shell enforces the same conjunction. When either is missing the
/// pulse says so instead of spinning at nothing; local queries are never
/// faked into a reload.
Future<String> runSyncPulse(BuildContext context, AppDatabase db) async {
  if (!kSyncEnabled) return 'No server configured';
  final auth = appAuth;
  final token = auth?.token;
  if (auth == null || !auth.signedIn || token == null) {
    return 'Not signed in — local only';
  }
  final engine = SyncEngine(db,
      baseUrl: kSyncBaseUrl, token: token, account: auth.username ?? '');
  var at = await engine.run();

  // ⚠ This device and the account both hold data. Nothing synced; ask here,
  // at the pull the user just made, rather than choosing for them.
  final join = engine.pendingJoin;
  if (join != null) {
    if (!context.mounted) return 'Choose how to sync this device';
    final choice = await PhoneSyncJoinSheet.show(context, join);
    if (choice == null) return 'Not synced — choose how to combine first';
    at = await completeJoin(db, engine, choice,
        backupPath: choice == JoinChoice.useAccount
            ? await replaceBackupPath()
            : null);
  }

  // ⚠ A 401 is not a transient failure to retry forever — the token was
  // revoked or the account changed, and only signing in again fixes it.
  if (engine.unauthorized) {
    await auth.forgetRejectedToken();
    return 'Sign in again';
  }
  if (engine.storageFull) return SyncEngine.storageFullLine;
  return at == null ? 'Sync failed — showing local data' : 'Synced just now';
}

/// D2 — settling an expected row. ⚠ "Confirm" alone is not enough: the amount
/// often differs, and a date that slips repeatedly is itself information.
/// Writing off is a soft delete, never a hard one.
///
/// Exported because the Today money card taps into it — one sheet, both
/// entry points, so the two surfaces cannot drift.
Future<void> showSettleSheet(
  BuildContext context,
  AppDatabase db,
  MoneyRow row,
) {
  return PhoneSheet.show(context, (_) => _SettleSheet(db: db, row: row));
}

/// §7 fix — actual rows were dead ends. The correction sheet is the add sheet
/// in edit mode: every field editable, plus a soft Delete behind the house
/// confirm.
Future<void> showMoneyCorrectionSheet(
  BuildContext context,
  AppDatabase db,
  MoneyRow row,
) {
  return PhoneSheet.show(context, (_) => _MoneySheet(db: db, existing: row));
}

class PhoneMoneyScreen extends StatefulWidget {
  const PhoneMoneyScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhoneMoneyScreen> createState() => _PhoneMoneyScreenState();
}

class _PhoneMoneyScreenState extends State<PhoneMoneyScreen> {
  // Held in state; an inline future re-queries on every stream tick.
  late Future<({Map<String, Person> people, Map<String, Engagement> projects})>
  _lookups = _loadLookups();

  /// Set by a pull-to-refresh pulse, shown under the balance card until the
  /// next one. Null means no pulse has run yet — quiet by default (P4).
  String? _syncLine;
  bool _syncBad = false;

  Future<({Map<String, Person> people, Map<String, Engagement> projects})>
  _loadLookups() async => (
    people: await widget.db.peopleById(),
    projects: await widget.db.engagementsById(),
  );

  void _reloadLookups() => setState(() => _lookups = _loadLookups());

  Future<void> _pulse() async {
    final line = await runSyncPulse(context, widget.db);
    if (!mounted) return;
    setState(() {
      _syncLine = line;
      _syncBad =
          line == 'Sync failed — showing local data' ||
          line == 'Sign in again' ||
          line == SyncEngine.storageFullLine;
    });
  }

  Future<void> _open(WidgetBuilder builder) async {
    await PhoneSheet.show<void>(context, builder);
    if (mounted) _reloadLookups();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneScaffold(
      title: 'Money',
      // ⚠ Nothing floats — no FAB ever (§8). The add lives in the nav bar at
      // 44pt, icons not words (§3.1).
      actions: [
        PhonePressable(
          onTap: () => _open((_) => _MoneySheet(db: widget.db)),
          pressedScale: 0.9,
          child: SizedBox(
            width: PD.tapMin,
            height: PD.tapMin,
            child: Center(child: AppIcon(Ic.add, size: 26, color: t.accent)),
          ),
        ),
      ],
      child: RefreshIndicator(
        color: t.accent,
        backgroundColor: t.card,
        onRefresh: _pulse,
        child: StreamBuilder<List<MoneyRow>>(
          stream: widget.db.watchMoney(),
          builder: (context, snap) {
            final rows = snap.data ?? const <MoneyRow>[];
            final totals = MoneyTotals.of(rows);
            return ListView(
              // Short ledgers must still pull — the pulse is the point.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                PD.screenPad,
                0,
                PD.screenPad,
                PD.sectionGap,
              ),
              children: [
                _CashOnHand(balances: totals.balances),
                if (_syncLine != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: Text(
                      _syncLine!,
                      style: PT.micro.copyWith(
                        color: _syncBad ? t.attention.text : t.textMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: PD.sectionGap),
                _Expected(
                  title: 'COMING IN',
                  totals: totals.inExpected,
                  rows: rows
                      .where(
                        (m) => m.status == 'expected' && m.direction == 'in',
                      )
                      .toList(),
                  db: widget.db,
                  lookups: _lookups,
                ),
                _Expected(
                  title: 'COMING OUT',
                  totals: totals.outExpected,
                  rows: rows
                      .where(
                        (m) => m.status == 'expected' && m.direction == 'out',
                      )
                      .toList(),
                  db: widget.db,
                  lookups: _lookups,
                ),
                _Ledger(
                  rows: rows,
                  db: widget.db,
                  lookups: _lookups,
                  onChanged: _reloadLookups,
                ),
              ],
            );
          },
        ),
      ),
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
    required this.lookups,
  });
  final String title;
  final Map<String, int> totals;
  final List<MoneyRow> rows;
  final AppDatabase db;
  final Future<({Map<String, Person> people, Map<String, Engagement> projects})>
  lookups;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final t = AppTokens.of(context);
    return PhoneSection(title, [
      FutureBuilder<
        ({Map<String, Person> people, Map<String, Engagement> projects})
      >(
        future: lookups,
        builder: (context, l) {
          final people = l.data?.people ?? const <String, Person>{};
          return Column(
            children: [
              for (final m in rows)
                PhoneRow(
                  title: m.label,
                  // Links in the subtitle (v2) — visible, never a tap target:
                  // the tap-through lives in the sheet's `View person` row.
                  subtitle: [
                    fmtDate(m.date),
                    'expected',
                    ?people[m.personId]?.name,
                  ].join(' · '),
                  onTap: () => showSettleSheet(context, db, m),
                  trailing: Text(
                    fmtMoney(m.amountMinor, m.currency),
                    style: PT.mono.copyWith(color: t.textSecondary),
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
            ],
          );
        },
      ),
    ]);
  }
}

/// Fixed column geometry for the ledger table. 64 + flex + 48 + 100 fits
/// 390pt minus screen padding, the label column taking the remainder. The
/// direction column is sized for its own header — 'IN/OUT' on one line.
const _kDateCol = 64.0;
const _kDirCol = 48.0;
const _kAmountCol = 100.0;

/// THE LEDGER — a real table (session 2), because the card list read like a
/// pile of rows, not an account. Grammar: fixed columns DATE · LABEL ·
/// IN/OUT · AMOUNT (right-aligned, mono, tabular), hairline rules, month
/// groups with a net line each. ⚠ Only ACTUAL rows: a ledger records what
/// happened — projections live in COMING IN / COMING OUT above, and mixing
/// the two was the other reason the old list did not read as a ledger.
///
/// ⚠ Every row still taps: an actual row opens the correction sheet (the §7
/// fix — a typo'd amount is never permanent on the phone). No per-row
/// chevron: inside a table, chevrons are noise; the press yield and the
/// row's content answer the thumb.
///
/// No colours in rows, no shadows — house law. Direction is a word, not a
/// colour.
class _Ledger extends StatelessWidget {
  const _Ledger({
    required this.rows,
    required this.db,
    required this.lookups,
    required this.onChanged,
  });
  final List<MoneyRow> rows;
  final AppDatabase db;
  final Future<({Map<String, Person> people, Map<String, Engagement> projects})>
  lookups;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (rows.isEmpty) {
      return PhoneSection('LEDGER', [
        Text('Nothing has moved yet.', style: PT.body.copyWith(color: t.textMuted)),
      ]);
    }
    final actuals = rows.where((m) => m.status == 'actual').toList();
    if (actuals.isEmpty) {
      // Expected rows render above; the table stays honest about the fact
      // that nothing has actually moved.
      return PhoneSection('LEDGER', [
        Text('Nothing has moved yet.', style: PT.body.copyWith(color: t.textMuted)),
      ]);
    }
    // watchMoney orders date DESC, so first-seen order is newest month first.
    final months = <DateTime, List<MoneyRow>>{};
    for (final m in actuals) {
      months
          .putIfAbsent(DateTime(m.date.year, m.date.month), () => [])
          .add(m);
    }
    return PhoneSection('LEDGER', [
      FutureBuilder<
        ({Map<String, Person> people, Map<String, Engagement> projects})
      >(
        future: lookups,
        builder: (context, l) {
          final people = l.data?.people ?? const <String, Person>{};
          final projects = l.data?.projects ?? const <String, Engagement>{};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The column header row — once, above every month.
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(children: [
                  _head(t, 'DATE', _kDateCol, false),
                  const Expanded(child: SizedBox()),
                  _head(t, 'IN/OUT', _kDirCol, false),
                  _head(t, 'AMOUNT', _kAmountCol, true),
                ]),
              ),
              for (final e in months.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: PD.groupGap, bottom: 4),
                  child: Text(
                    '${kMonthNames[e.key.month - 1]} ${e.key.year}'
                        .toUpperCase(),
                    style: PT.micro.copyWith(
                        color: t.textMuted, letterSpacing: 0.5),
                  ),
                ),
                for (final (i, m) in e.value.indexed) ...[
                  if (i > 0) Container(height: 1, color: t.line),
                  PhonePressable(
                    onTap: () async {
                      // Actual corrects — the §7 fix, kept through the
                      // redesign.
                      await showMoneyCorrectionSheet(context, db, m);
                      onChanged();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The month header carries month+year, so the
                          // date cell needs only day and month.
                          SizedBox(
                            width: _kDateCol,
                            child: Text(
                                '${m.date.day} ${kMonths[m.date.month - 1]}',
                                style: PT.secondary
                                    .copyWith(color: t.textSecondary)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PT.body.copyWith(
                                        color: t.textPrimary,
                                        fontWeight: FontWeight.w600)),
                                if ((people[m.personId]?.name ??
                                        projects[m.engagementId]?.name) !=
                                    null)
                                  Text(
                                    [
                                      ?people[m.personId]?.name,
                                      ?projects[m.engagementId]?.name,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PT.secondary
                                        .copyWith(color: t.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: _kDirCol,
                            child: Text(
                                m.direction == 'in' ? 'in' : 'out',
                                style: PT.secondary
                                    .copyWith(color: t.textSecondary)),
                          ),
                          // ⚠ Mono, tabular, right-aligned, never
                          // converted (§8.4).
                          SizedBox(
                            width: _kAmountCol,
                            child: Text(
                              fmtMoney(m.amountMinor, m.currency),
                              textAlign: TextAlign.right,
                              style: PT.mono.copyWith(
                                color: t.textPrimary,
                                fontFeatures: kTabular.fontFeatures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                Container(height: 1, color: t.line),
                // The month's net, per currency, right-aligned with the
                // amounts it sums. In minus out — a ledger's running
                // sentence.
                for (final cur in _currenciesIn(e.value))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text('Net · $cur',
                            style: PT.secondary
                                .copyWith(color: t.textSecondary)),
                      ),
                      SizedBox(
                        width: _kAmountCol,
                        child: Text(
                          fmtMoney(_net(e.value, cur), cur),
                          textAlign: TextAlign.right,
                          style: PT.mono.copyWith(
                            color: t.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFeatures: kTabular.fontFeatures,
                          ),
                        ),
                      ),
                    ]),
                  ),
              ],
            ],
          );
        },
      ),
    ]);
  }

  static Widget _head(AppTokens t, String label, double width, bool right) =>
      SizedBox(
        width: width,
        child: Text(label,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
      );

  /// Insertion-ordered distinct currencies — Dart set literals keep order.
  static List<String> _currenciesIn(List<MoneyRow> rows) => {
        for (final m in rows) m.currency,
      }.toList();

  static int _net(List<MoneyRow> rows, String currency) => rows
      .where((m) => m.currency == currency)
      .fold(
          0,
          (sum, m) =>
              sum + (m.direction == 'in' ? m.amountMinor : -m.amountMinor));
}

/// D2 — the settle sheet. Amount prefilled, WHEN via the house date picker,
/// and the three decisions: confirm actual / keep expected / write off.
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
  Person? _person;

  @override
  void initState() {
    super.initState();
    if ((widget.row.personId ?? '').isNotEmpty) {
      widget.db.peopleById().then((m) {
        if (mounted) setState(() => _person = m[widget.row.personId]);
      });
    }
  }

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
          // ⚠ The tap-through is this row — 56pt, chevron, a legal 44pt
          // target. Tapping the name inside the row's subtitle would break
          // the floor, so it never will.
          if (_person != null)
            PhoneRow(
              title: [
                _person!.name,
                _person!.company,
              ].where((s) => s != null && s.isNotEmpty).join(' · '),
              minHeight: PD.listRow,
              chevron: true,
              onTap: () => _viewPerson(context),
            ),
          PhoneField(
            label: 'Amount (${widget.row.currency})',
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
            'Confirm the amount that actually moved, on the day it moved.',
            style: PT.secondary.copyWith(color: t.textMuted),
          ),
        ],
      ),
    );
  }

  /// The sheet stays open underneath, so half-entered state survives the
  /// detour; back returns to Money with the sheet as it was.
  void _viewPerson(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonDetailScreen(
          db: widget.db,
          personId: widget.row.personId!,
        ),
      ),
    );
  }

  /// ⚠ Destructive, so it asks — through the house confirm panel, and it is
  /// a soft delete underneath, which is what makes writing off recoverable
  /// on the Mac if it was a mistake.
  Future<void> _confirmWriteOff(BuildContext context) async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Write off "${widget.row.label}"?',
      body: '"${widget.row.label}" stops counting as expected. The row is '
          'kept so the other device learns it is gone.',
      confirmLabel: 'Write off',
    );
    if (!ok) return;
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

/// Add, or — with [existing] — the correction sheet for an actual row. Every
/// field editable, plus Delete (soft) behind the house confirm.
class _MoneySheet extends StatefulWidget {
  const _MoneySheet({required this.db, this.existing});
  final AppDatabase db;
  final MoneyRow? existing;

  @override
  State<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends State<_MoneySheet> {
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  late final _amount = TextEditingController(
    text:
        widget.existing == null
            ? ''
            : fmtMoney(
              widget.existing!.amountMinor,
              widget.existing!.currency,
              symbol: false,
            ),
  );
  late String _cur = widget.existing?.currency ?? 'CNY';
  late String _dir = widget.existing?.direction ?? 'in';
  late String _status = widget.existing?.status ?? 'expected';
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  Person? _person;
  Engagement? _project;

  /// ⚠ Expected money is future money. Defaulting to today and offering no way
  /// to change it made "coming in / coming out" structurally useless.
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _label.addListener(() => setState(() {}));
    _amount.addListener(() => setState(() {}));
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    if ((widget.existing?.personId ?? '').isNotEmpty) {
      final m = await widget.db.peopleById();
      if (mounted) setState(() => _person = m[widget.existing!.personId]);
    }
    if ((widget.existing?.engagementId ?? '').isNotEmpty) {
      final m = await widget.db.engagementsById();
      if (mounted) setState(() => _project = m[widget.existing!.engagementId]);
    }
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
      title: _editing ? 'Edit money row' : 'Add money row',
      actions: Row(
        children: [
          if (_editing) ...[
            Expanded(
              flex: 1,
              child: PhoneBtn(
                'Delete',
                variant: PhoneBtnVariant.danger,
                onPressed: _confirmDelete,
              ),
            ),
            const SizedBox(width: 8),
          ] else
            Expanded(
              flex: 1,
              child: PhoneBtn(
                'Cancel',
                variant: PhoneBtnVariant.ghost,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
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
          if (_editing && _person != null)
            PhoneRow(
              title: [
                _person!.name,
                _person!.company,
              ].where((s) => s != null && s.isNotEmpty).join(' · '),
              minHeight: PD.listRow,
              chevron: true,
              onTap: () => _viewPerson(context),
            ),
          PhoneField(
            label: 'Label',
            controller: _label,
            hint: 'Powerline M3',
            autofocus: !_editing,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(
            label: 'Amount',
            controller: _amount,
            hint: '25000',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
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

  void _viewPerson(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder:
            (_) => PersonDetailScreen(
              db: widget.db,
              personId: widget.existing!.personId!,
            ),
      ),
    );
  }

  Future<void> _save() async {
    final v = MoneyCompanion(
      date: Value(_date),
      direction: Value(_dir),
      amountMinor: Value(toMinor(_amount.text, _cur)),
      currency: Value(_cur),
      label: Value(_label.text.trim()),
      status: Value(_status),
      personId: Value(_person?.id),
      engagementId: Value(_project?.id),
      updatedAt: Value(DateTime.now()),
    );
    if (_editing) {
      await widget.db.updateMoney(widget.existing!.id, v);
    } else {
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
    }
    if (mounted) Navigator.pop(context);
  }

  /// Soft delete, behind the house confirm — the same grammar the desktop's
  /// DeleteAction has always had and v1 money never grew.
  Future<void> _confirmDelete() async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete "${widget.existing!.label}"?',
      body: 'The row is kept so the other device learns it is gone.',
    );
    if (!ok) return;
    await widget.db.softDeleteRow(widget.db.money, widget.existing!.id);
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
