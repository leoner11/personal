import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
import '../widgets/pickers.dart';
import '../widgets/primitives.dart';

const kTypes = ['deal', 'jv', 'client', 'lead'];

/// ⚠ Grouped by type, NOT a pipeline. Ralali is a jv, not a deal — that
/// distinction is the entire reason this table exists.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<Engagement>>(
      stream: db.watchEngagements(),
      builder: (context, snap) {
        final rows = snap.data ?? const <Engagement>[];
        return FutureBuilder<Map<String, Person>>(
          future: db.peopleById(),
          builder: (context, peopleSnap) {
            final byId = peopleSnap.data ?? const <String, Person>{};
            return ScreenBody(
              title: 'Projects',
              trailing: Btn('Add project',
                  variant: BtnVariant.primary,
                  onPressed: () => ProjectSheet.show(context, db)),
              child: rows.isEmpty
                  ? const EmptyLine('Nothing here yet.')
                  : ListView(children: [
                      for (final type in kTypes)
                        if (rows.any((e) => e.type == type)) ...[
                          Container(
                            height: D.groupHeader,
                            alignment: Alignment.centerLeft,
                            margin: const EdgeInsets.only(top: 8, bottom: 2),
                            child: Text(type.toUpperCase(),
                                style: T.micro.copyWith(
                                    color: t.textMuted, letterSpacing: 0.5)),
                          ),
                          for (final e in rows.where((e) => e.type == type))
                            _Row(
                              engagement: e,
                              person: byId[e.counterpartyId],
                              onTap: () =>
                                  ProjectSheet.show(context, db, existing: e),
                            ),
                        ],
                    ]),
            );
          },
        );
      },
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.engagement, required this.person, required this.onTap});
  final Engagement engagement;
  final Person? person;
  final VoidCallback onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final e = widget.engagement;
    // The counterparty is what makes the row mean something. Shown on the
    // second line beside the status, not hidden behind a tap.
    final meta = [
      if (widget.person != null)
        [widget.person!.name, widget.person!.company]
            .where((s) => s != null && s.isNotEmpty)
            .join(' · '),
      if ((e.status ?? '').isNotEmpty) e.status!,
    ].join('  —  ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: D.listRowTwoLine,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: _hover ? t.subtle : Colors.transparent,
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: T.body.copyWith(
                          color: t.textPrimary, fontWeight: FontWeight.w600)),
                  Text(
                      meta.isEmpty ? 'no counterparty linked' : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // ⚠ Free text renders as plain secondary text, never as
                      // a status tag — free text cannot be reliably mapped to
                      // a tone, and a wrong tone is worse than none.
                      style: T.secondary.copyWith(
                          color: meta.isEmpty ? t.textMuted : t.textSecondary)),
                ],
              ),
            ),
            if (e.valueMinor != null)
              Text(fmtMoney(e.valueMinor!, e.currency ?? 'CNY'),
                  style: T.mono.copyWith(color: t.textMuted)),
          ]),
        ),
      ),
    );
  }
}

class ProjectSheet extends StatefulWidget {
  const ProjectSheet({super.key, required this.db, this.existing, this.presetPerson});
  final AppDatabase db;
  final Engagement? existing;
  final Person? presetPerson;

  static Future<void> show(BuildContext c, AppDatabase db,
          {Engagement? existing, Person? presetPerson}) =>
      showDialog(
          context: c,
          builder: (_) =>
              ProjectSheet(db: db, existing: existing, presetPerson: presetPerson));

  @override
  State<ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<ProjectSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _status =
      TextEditingController(text: widget.existing?.status ?? '');
  late final _value = TextEditingController(
      text: widget.existing?.valueMinor == null
          ? ''
          : fmtMoney(widget.existing!.valueMinor!,
              widget.existing!.currency ?? 'CNY',
              symbol: false));
  late String _type = widget.existing?.type ?? 'deal';
  late String _cur = widget.existing?.currency ?? 'CNY';
  String? _personId;
  Person? _person;

  @override
  void initState() {
    super.initState();
    _personId = widget.presetPerson?.id ?? widget.existing?.counterpartyId;
    _person = widget.presetPerson;
    if (_person == null && _personId != null && _personId!.isNotEmpty) {
      widget.db.peopleById().then((m) {
        if (mounted) setState(() => _person = m[_personId]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final editing = widget.existing != null;
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(editing ? 'Edit project' : 'Add project',
                  style: T.screenTitle.copyWith(color: t.textPrimary)),
              const SizedBox(height: 14),
              Field(label: 'Name', controller: _name, hint: 'NaraHome ERP'),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final ty in kTypes)
                  TagChip(
                      label: ty,
                      selected: _type == ty,
                      onTap: () => setState(() => _type = ty)),
              ]),

              const SizedBox(height: 14),
              Text('COUNTERPARTY',
                  style:
                      T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(
                      _person == null
                          ? 'Not linked'
                          : [_person!.name, _person!.company]
                              .where((s) => s != null && s.isNotEmpty)
                              .join(' · '),
                      style: T.body.copyWith(
                          color:
                              _person == null ? t.textMuted : t.textPrimary)),
                ),
                Btn(_person == null ? 'Link person' : 'Change',
                    size: BtnSize.sm,
                    onPressed: () async {
                      final p = await PersonPicker.show(context, widget.db);
                      if (p == null) return;
                      setState(() {
                        // The picker returns an empty id to mean "clear".
                        _person = p.id.isEmpty ? null : p;
                        _personId = p.id.isEmpty ? null : p.id;
                      });
                    }),
              ]),

              const SizedBox(height: 14),
              Field(
                  label: 'Status',
                  controller: _status,
                  hint: 'quotation sent / went quiet'),
              const SizedBox(height: 10),
              Field(label: 'Value', controller: _value, hint: 'optional'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final c in kCurrencies)
                  TagChip(
                      label: c,
                      selected: _cur == c,
                      onTap: () => setState(() => _cur = c)),
              ]),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn('Save', variant: BtnVariant.primary, onPressed: _save),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final v = _value.text.trim();
    final name = _name.text.trim().isEmpty ? 'untitled' : _name.text.trim();
    final valueMinor = v.isEmpty ? null : toMinor(v, _cur);

    if (widget.existing != null) {
      await widget.db.updateEngagement(
        widget.existing!.id,
        EngagementsCompanion(
          name: Value(name),
          type: Value(_type),
          counterpartyId: Value(_personId),
          status: Value(_status.text.trim()),
          valueMinor: Value(valueMinor),
          currency: Value(_cur),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await widget.db
          .into(widget.db.engagements)
          .insert(EngagementsCompanion.insert(
            name: name,
            type: Value(_type),
            counterpartyId: Value(_personId),
            status: Value(_status.text.trim()),
            valueMinor: Value(valueMinor),
            currency: Value(_cur),
          ));
    }
    if (mounted) Navigator.pop(context);
  }
}
