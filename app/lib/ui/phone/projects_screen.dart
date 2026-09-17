import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../screens/projects_screen.dart' show kTypes;
import '../widgets/app_icon.dart';
import 'person_detail_screen.dart';
import 'phone_pickers.dart';
import 'phone_primitives.dart';

/// ⚠ Grouped by type, NOT a pipeline. Ralali is a jv, not a deal — that
/// distinction is the entire reason this table exists, and a phone screen that
/// flattened it into one list would quietly throw it away.
///
/// ⚠ WHAT DOES NOT CARRY FROM THE MAC: every row there is wrapped in a
/// MouseRegion and tints on hover. A phone has no hover, so the tint is dead
/// code and the row would look inert. The chevron replaces it — a permanent,
/// visible signal that the row does something.
///
/// v2: the edit sheet gains the `View person` tap-through and the soft
/// Delete. Delete lives in the edit sheet's actions row, not on a swipe: the
/// list is a read surface and deleting a project is rare — §3.2 reserves
/// swipe for frequent actions.
class PhoneProjectsScreen extends StatefulWidget {
  const PhoneProjectsScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhoneProjectsScreen> createState() => _PhoneProjectsScreenState();
}

class _PhoneProjectsScreenState extends State<PhoneProjectsScreen> {
  // Held in state; an inline future re-queries on every stream tick.
  late Future<Map<String, Person>> _people = widget.db.peopleById();

  void _reloadPeople() => setState(() => _people = widget.db.peopleById());

  Future<void> _open(WidgetBuilder builder) async {
    await PhoneSheet.show<void>(context, builder);
    if (mounted) _reloadPeople();
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final t = AppTokens.of(context);
    return PhoneScaffold(
      title: 'Projects',
      actions: [
        PhonePressable(
          onTap: () => _open((_) => PhoneProjectSheet(db: db)),
          pressedScale: 0.9,
          child: SizedBox(
            width: PD.tapMin,
            height: PD.tapMin,
            child: Center(child: AppIcon(Ic.add, size: 26, color: t.accent)),
          ),
        ),
      ],
      child: StreamBuilder<List<Engagement>>(
        stream: db.watchEngagements(),
        builder: (context, snap) {
          final rows = snap.data ?? const <Engagement>[];
          return FutureBuilder<Map<String, Person>>(
            future: _people,
            builder: (context, peopleSnap) {
              final byId = peopleSnap.data ?? const <String, Person>{};
              if (rows.isEmpty) return const PhoneEmpty('Nothing here yet.');
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PD.screenPad,
                  0,
                  PD.screenPad,
                  PD.sectionGap,
                ),
                children: [
                  for (final type in kTypes)
                    if (rows.any((e) => e.type == type))
                      PhoneSection(type, [
                        for (final e in rows.where((e) => e.type == type))
                          _ProjectRow(
                            engagement: e,
                            person: byId[e.counterpartyId],
                            onTap: () => _open(
                              (_) => PhoneProjectSheet(db: db, existing: e),
                            ),
                          ),
                      ]),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.engagement,
    required this.person,
    required this.onTap,
  });
  final Engagement engagement;
  final Person? person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final e = engagement;
    // The counterparty is what makes the row mean something. On the second
    // line beside the status, not hidden behind a tap.
    final meta = [
      if (person != null)
        [person!.name, person!.company]
            .where((s) => s != null && s.isNotEmpty)
            .join(' · '),
      if ((e.status ?? '').isNotEmpty) e.status!,
    ].join('  —  ');

    return PhoneRow(
      title: e.name,
      subtitle: meta,
      onTap: onTap,
      chevron: true,
      trailing: e.valueMinor == null
          // ⚠ `unknown`, never 0.00 — an empty value means "we haven't
          // agreed a number", and ¥0.00 would claim the deal is worth
          // nothing. The list must never say that.
          ? Text('unknown', style: PT.secondary.copyWith(color: t.textMuted))
          // ⚠ Plain tabular text, never a status tag. `status` is free text
          // and the design system is explicit that it must not be dressed up
          // as a state machine it is not.
          : Text(
              fmtMoney(e.valueMinor!, e.currency ?? 'CNY'),
              style: PT.mono.copyWith(color: t.textSecondary),
            ),
    );
  }
}

/// Add or edit. Public because the person detail screen has a reason to open
/// it with a counterparty already chosen.
class PhoneProjectSheet extends StatefulWidget {
  const PhoneProjectSheet({
    super.key,
    required this.db,
    this.existing,
    this.presetPerson,
  });
  final AppDatabase db;
  final Engagement? existing;
  final Person? presetPerson;

  @override
  State<PhoneProjectSheet> createState() => _PhoneProjectSheetState();
}

class _PhoneProjectSheetState extends State<PhoneProjectSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _status = TextEditingController(
    text: widget.existing?.status ?? '',
  );
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late final _value = TextEditingController(
    text: widget.existing?.valueMinor == null
        ? ''
        : fmtMoney(
            widget.existing!.valueMinor!,
            widget.existing!.currency ?? 'CNY',
            symbol: false,
          ),
  );
  late String _type = widget.existing?.type ?? 'deal';
  late String _cur = widget.existing?.currency ?? 'CNY';
  String? _personId;
  Person? _person;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _personId = widget.presetPerson?.id ?? widget.existing?.counterpartyId;
    _person = widget.presetPerson;
    if (_person == null && _personId != null && _personId!.isNotEmpty) {
      widget.db.peopleById().then((m) {
        if (mounted) setState(() => _person = m[_personId]);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _status.dispose();
    _notes.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return PhoneSheet(
      title: editing ? 'Edit project' : 'Add project',
      actions: Row(
        children: [
          if (editing) ...[
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
              onPressed: _name.text.trim().isEmpty ? null : _save,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠ The tap-through is this row — one honest 44pt target. Tapping
          // the counterparty inside the row's subtitle would break the floor.
          // The linked project on a money row has no such row because no
          // project detail screen exists to receive it; a person does.
          if (editing && _person != null)
            PhoneRow(
              title: [_person!.name, _person!.company]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(' · '),
              minHeight: PD.listRow,
              chevron: true,
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => PersonDetailScreen(
                    db: widget.db,
                    personId: widget.existing!.counterpartyId!,
                  ),
                ),
              ),
            ),
          PhoneField(
            label: 'Name',
            controller: _name,
            hint: 'NaraHome ERP',
            autofocus: !editing,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.sectionGap),
          _Chips(
            label: 'Type',
            options: kTypes,
            selected: _type,
            onTap: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: PD.sectionGap),
          PhoneLinkRow(
            label: 'Counterparty',
            value: _person == null
                ? null
                : [_person!.name, _person!.company]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(' · '),
            onTap: () async {
              final p = await pickPerson(context, widget.db);
              if (p == null) return;
              setState(() {
                _person = p;
                _personId = p.id;
              });
            },
            onClear: () => setState(() {
              _person = null;
              _personId = null;
            }),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(
            label: 'Status',
            controller: _status,
            hint: 'waiting on their legal',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(
            label: 'Value',
            controller: _value,
            hint: '250000',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: PD.groupGap),
          _Chips(
            label: 'Currency',
            options: kCurrencies,
            selected: _cur,
            onTap: (v) => setState(() => _cur = v),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(
            label: 'Notes',
            controller: _notes,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final v = _value.text.trim();
    // ⚠ An empty value means "unknown", not zero. toMinor would turn it into
    // 0 and the Projects list would start claiming deals are worth nothing.
    final minor = v.isEmpty ? null : toMinor(v, _cur);
    final status = _status.text.trim();
    final notes = _notes.text.trim();

    if (widget.existing == null) {
      await widget.db
          .into(widget.db.engagements)
          .insert(
            EngagementsCompanion.insert(
              name: _name.text.trim(),
              type: Value(_type),
              status: Value(status.isEmpty ? null : status),
              notes: Value(notes.isEmpty ? null : notes),
              valueMinor: Value(minor),
              currency: Value(_cur),
              counterpartyId: Value(_personId),
            ),
          );
    } else {
      await widget.db.updateEngagement(
        widget.existing!.id,
        EngagementsCompanion(
          name: Value(_name.text.trim()),
          type: Value(_type),
          status: Value(status.isEmpty ? null : status),
          notes: Value(notes.isEmpty ? null : notes),
          valueMinor: Value(minor),
          currency: Value(_cur),
          counterpartyId: Value(_personId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  /// Soft delete behind the house confirm — the desktop `DeleteAction`
  /// grammar, which the phone's projects surface never grew until now.
  Future<void> _confirmDelete() async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete "${widget.existing!.name}"?',
      body: 'The row is kept so the other device learns it is gone.',
    );
    if (!ok) return;
    await widget.db.softDeleteRow(widget.db.engagements, widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
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
