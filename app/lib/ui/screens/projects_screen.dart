import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
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
        return ScreenBody(
          title: 'Projects',
          trailing: Btn('Add project',
              variant: BtnVariant.primary,
              onPressed: () => _AddSheet.show(context, db)),
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
                        Container(
                          height: D.listRowTwoLine,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.name,
                                      style: T.body.copyWith(
                                          color: t.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                  // ⚠ Free text renders as plain secondary
                                  // text, never as a status tag — free text
                                  // cannot be reliably mapped to a tone, and a
                                  // wrong tone is worse than none.
                                  Text(e.status ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.secondary
                                          .copyWith(color: t.textSecondary)),
                                ],
                              ),
                            ),
                            if (e.valueMinor != null)
                              Text(
                                  fmtMoney(e.valueMinor!, e.currency ?? 'CNY'),
                                  style: T.mono.copyWith(color: t.textMuted)),
                          ]),
                        ),
                    ],
                ]),
        );
      },
    );
  }
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.db});
  final AppDatabase db;

  static Future<void> show(BuildContext c, AppDatabase db) =>
      showDialog(context: c, builder: (_) => _AddSheet(db: db));

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _name = TextEditingController();
  final _status = TextEditingController();
  final _value = TextEditingController();
  String _type = 'deal';
  String _cur = 'CNY';

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
              Text('Add project',
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
              const SizedBox(height: 10),
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
                Btn('Save', variant: BtnVariant.primary, onPressed: () async {
                  final v = _value.text.trim();
                  await widget.db
                      .into(widget.db.engagements)
                      .insert(EngagementsCompanion.insert(
                        name: _name.text.trim().isEmpty
                            ? 'untitled'
                            : _name.text.trim(),
                        type: Value(_type),
                        status: Value(_status.text.trim()),
                        valueMinor:
                            Value(v.isEmpty ? null : toMinor(v, _cur)),
                        currency: Value(_cur),
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
