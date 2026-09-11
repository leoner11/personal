import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import 'phone_primitives.dart';

/// Phone counterparts to `widgets/pickers.dart`.
///
/// ⚠ The Mac pickers are dialogs with a text field and a scrolling list at
/// 32pt rows. Ported literally they give a phone 32pt tap targets, which is
/// below the 44pt floor. Everything here is a sheet at phone density.

/// A tappable date row. The Mac's DateField is a text input with a parser;
/// on a phone the platform picker is better than any field, and typing a
/// date on a soft keyboard is a chore nobody should be given.
class PhoneDateRow extends StatelessWidget {
  const PhoneDateRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              // Money and notes both look backwards and forwards; an expected
              // row is future money and a note is usually past.
              firstDate: DateTime(DateTime.now().year - 5),
              lastDate: DateTime(DateTime.now().year + 5),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            height: PD.control,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(D.radiusControl),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fmtDate(value),
                    style: PT.body.copyWith(color: t.textPrimary),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: t.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One row of a link: what it is now, and a button to change it.
///
/// ⚠ Always visible, never hover-revealed, and it shows "Not linked" rather
/// than hiding when empty — an invisible link control is a column with no
/// feature, which this project has already had to audit for once.
class PhoneLinkRow extends StatelessWidget {
  const PhoneLinkRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final linked = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  height: PD.control,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(D.radiusControl),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    linked ? value! : 'Not linked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PT.body.copyWith(
                      color: linked ? t.textPrimary : t.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            if (linked) ...[
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: SizedBox(
                  width: PD.tapMin,
                  height: PD.control,
                  child: Icon(Icons.close, size: 20, color: t.textMuted),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Search-and-pick, as a sheet. Returns null when dismissed.
///
/// Generic over the row type so people and projects share one implementation —
/// the Mac has two near-identical picker classes and there is no reason to
/// copy that here.
class PhonePickSheet<R> extends StatefulWidget {
  const PhonePickSheet({
    super.key,
    required this.title,
    required this.items,
    required this.label,
    required this.sublabel,
  });
  final String title;
  final List<R> items;
  final String Function(R) label;
  final String Function(R) sublabel;

  @override
  State<PhonePickSheet<R>> createState() => _PhonePickSheetState<R>();
}

class _PhonePickSheetState<R> extends State<PhonePickSheet<R>> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final rows = q.isEmpty
        ? widget.items
        : widget.items
              .where(
                (r) =>
                    widget.label(r).toLowerCase().contains(q) ||
                    widget.sublabel(r).toLowerCase().contains(q),
              )
              .toList();

    return PhoneSheet(
      title: widget.title,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhoneField(
            label: 'Search',
            controller: _search,
            hint: 'name or company',
          ),
          const SizedBox(height: PD.groupGap),
          Expanded(
            child: rows.isEmpty
                ? const PhoneEmpty('Nothing matches.')
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const PhoneDivider(),
                    itemBuilder: (_, i) => PhoneRow(
                      title: widget.label(rows[i]),
                      subtitle: widget.sublabel(rows[i]),
                      onTap: () => Navigator.pop(context, rows[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

Future<Person?> pickPerson(BuildContext context, AppDatabase db) async {
  final people = await db.allPeople();
  if (!context.mounted) return null;
  return PhoneSheet.show<Person>(
    context,
    (_) => PhonePickSheet<Person>(
      title: 'Link a person',
      items: people,
      label: (p) => p.name,
      sublabel: (p) => p.company ?? '',
    ),
  );
}

Future<Engagement?> pickProject(BuildContext context, AppDatabase db) async {
  final projects = await db.watchEngagements().first;
  if (!context.mounted) return null;
  return PhoneSheet.show<Engagement>(
    context,
    (_) => PhonePickSheet<Engagement>(
      title: 'Link a project',
      items: projects,
      label: (e) => e.name,
      sublabel: (e) =>
          [e.type, if ((e.status ?? '').isNotEmpty) e.status!].join(' · '),
    ),
  );
}
